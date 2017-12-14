# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

require 'MrMurano/Solution'

module MrMurano
  # …/serviceconfig
  class ServiceConfig < SolutionBase
    def initialize(api_id=nil)
      super
      @uriparts << :serviceconfig
      @scid = nil
    end

    def list(call=nil, data=nil, &block)
      ret = get(call, data, &block)
      return [] unless ret.is_a?(Hash) && !ret.key?(:error)
      return [] unless ret.key?(:items)
      ret[:items]
      # MAYBE/2017-08-17:
      #   sort_by_name(ret[:items])
    end

    def search(svc_name)
      #path = nil
      path = '?select=id,service,script_key'
      # 2017-07-02: This is what yeti-ui queries on:
      #path = '?select=service,id,solution_id,script_key,alias'
      super(svc_name, path)
    end

    def fetch(id)
      get('/' + id.to_s)
    end

    def scid_for_name(name)
      name = name.to_s unless name.is_a? String
      scr = list.select { |i| i[:service] == name }.first
      return nil if scr.nil?
      scr[:id]
    end

    def scid
      return @scid unless @scid.nil?
      @scid = scid_for_name(@service_name)
    end

    def create(pid, name=nil, &block)
      name = pid if name.to_s.empty?
      raise 'Missing name/script_key?' if name.to_s.empty?
      # See pegasus_registry PostServiceConfig for the POST properties.
      #   pegasus_registry/api/swagger/paths/serviceconfig.yaml
      #   pegasus_registry/api/swagger/definitions/serviceconfig.yaml
      post(
        '/',
        {
          solution_id: @api_id,
          service: pid,
          # 2017-06-26: "name" seems to work, but "script_key" is what web UI uses.
          #   See yeti-ui/bridge/src/js/api/services.js::linkApplicationService
          #name: name,
          script_key: name,
        },
        &block
      )
    end

    def remove(id)
      return unless remove_item_allowed(id)
      delete("/#{id}")
    end

    def info(id=scid)
      get("/#{id}/info")
    end

    def logs(id=scid)
      get("/#{id}/logs")
    end

    def call(opid, meth=:get, data=nil, id=scid, &block)
      raise "Service '#{@service_name}' not enabled for this Solution" if id.nil?
      call = "/#{id}/call/#{opid}"
      debug "Will call: #{call}"
      case meth
      when :get
        get(call, data, &block)
      when :post
        data = {} if data.nil?
        post(call, data, &block)
      when :put
        data = {} if data.nil?
        put(call, data, &block)
      when :delete
        delete(call, &block)
      else
        raise "Unknown method: #{meth}"
      end
    end
  end

  ## This is only used for debugging and deciphering APIs.
  #
  # There was once a plan for using this to automagically map commands into
  # services by reading their schema.  That plan had too much magic and was too
  # fragile for real use.
  #
  # A much better UI/UX happens with human intervention.
  # :nocov:
  class Services < SolutionBase
    def initialize(api_id=nil)
      @solntype = 'application.id'
      super
      @uriparts << :service
    end

    def api_id_for_name(name)
      name = name.to_s unless name.is_a? String
      scr = list.select { |i| i[:alias] == name }.first
      scr[:id]
    end

    def api_id
      return @api_id unless @api_id.nil?
      @api_id = api_id_for_name(@service_name)
    end

    def list
      ret = get
      return [] unless ret.is_a?(Hash) && !ret.key?(:error)
      return [] unless ret.key?(:items)
      ret[:items]
      # MAYBE/2017-08-17:
      #   sort_by_name(ret[:items])
    end

    def schema(id=api_id)
      # TODO: cache schema in user dir?
      get("/#{id}/schema")
    end

    ## Get list of call operations from a schema
    def callable(id=api_id, all=false)
      scm = schema(id)
      calls = []
      scm[:paths].each do |path, methods|
        methods.each do |method, params|
          next unless params.is_a?(Hash)
          call = [method]
          call << path.to_s if all
          call << params[:operationId]
          call << (params['x-internal-use'.to_sym] || false) if all
          calls << call
        end
      end
      calls
    end

    def all_events
      sevs = list
      ret = []
      sevs.each do |srv|
        scm = schema(srv[:id]) || {}
        (scm['x-events'.to_sym] || {}).each_pair do |event, _info|
          ret << [srv[:alias], event]
        end
      end
      ret
    end
  end
  # :nocov:

  class ServiceConfigApplication < ServiceConfig
    def initialize(api_id=nil)
      @solntype = 'application.id'
      super
    end
  end

  class ServiceConfigProduct < ServiceConfig
    def initialize(api_id=nil)
      @solntype = 'product.id'
      super
    end
  end
end


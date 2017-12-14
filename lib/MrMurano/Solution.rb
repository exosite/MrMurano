# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

require 'rainbow'
require 'uri'
require 'MrMurano/http'
require 'MrMurano/verbosing'
require 'MrMurano/Config'
require 'MrMurano/SolutionId'
require 'MrMurano/SyncUpDown'

module MrMurano
  class SolutionBase
    include Http
    include Verbose
    include SolutionId

    def initialize(from=nil)
      @uriparts_apidex = 1
      # Introspection. Feels hacky.
      if from.is_a? MrMurano::Solution
        init_api_id!(from.api_id)
        @valid_api_id = from.valid_api_id
        # We shouldn't need to worry about other things...
        #@token = from.token
        #@http = from.http
        #@json_opts = from.json_opts
      else
        init_api_id!(from)
      end
      @uriparts = [:solution, @api_id]
      @itemkey = :id
      @project_section = nil unless defined?(@project_section)
    end

    def ==(other)
      other.class == self.class && other.state == state
    end

    protected

    def state
      [@api_id, @valid_api_id, @sid, @uriparts, @solntype, @itemkey, @project_section]
    end

    public

    ## Generate an endpoint in Murano
    # Uses the uriparts and path
    # @param path String: any additional parts for the URI
    # @return URI: The full URI for this endpoint.
    def endpoint(path='')
      super
      parts = [$cfg['net.protocol'] + ':/', $cfg['net.host'], 'api:1'] + @uriparts
      s = parts.map(&:to_s).join('/')
      URI(s + path.to_s)
    end
    # …

    def get(path='', query=nil, &block)
      aggregate = nil
      total = nil
      remaining = -1
      orig_query = (query || []).dup
      while remaining != 0
        ret = super
        if ret.nil? && !@suppress_error
          warning "No solution with ID: #{@api_id}"
          whirly_interject { say 'Run `murano show` to see the business and list of solutions.' }
          MrMurano::SolutionBase.warn_configfile_env_maybe
          exit 1
        end
        return nil if ret.nil?
        # Pagination: Check if more data.
        if ret.is_a?(Hash) && ret.key?(:total) && ret.key?(:items)
          query = orig_query.dup
          if total.nil?
            total = ret[:total]
            remaining = total - ret[:items].length
            # The response also includes a hint of how to get the next page.
            #   ret[:next] == "/api/v1/eventhandler?query={\
            #     \"solution_id\":\"XXXXXXXXXXXXXXXX\"}&limit=20&offset=20"
            # But note that the URL we use is a little different
            #   https://bizapi.hosted.exosite.io/api:1/solution/XXXXXXXXXXXXXXXXX/eventhandler
          else
            if total != ret[:total]
              warning "Unexpected: subsequence :total not total: #{ret[:total]} != #{total}"
            end
            remaining -= ret[:items].length
          end
          if remaining > 0
            #query.push ['limit', 20]
            query.push ['offset', total - remaining]
          elsif remaining != 0
            warning "Unexpected: negative remaining: #{fancy_ticks(total)}"
            remaining = 0
          end
          if aggregate.nil?
            aggregate = ret
          else
            aggregate[:items].concat ret[:items]
          end
        else
          # ret is not a hash, or it's missing :total or :items.
          warning "Unexpected: aggregate set: #{aggregate} / ret: #{ret}" unless aggregate.nil?
          aggregate = ret
          remaining = 0
        end
      end
      aggregate
    end

    # This at least works for EventHandler and ServiceConfig.
    # - ServiceConfig overrides to fetch also 'script_key'.
    def search(svc_name, path=nil)
      # NOTE: You can ask the server to filter the list.
      #   E.g., the web UI filters with:
      #     ?select=service,id,solution_id,script_key,alias
      #   NOTE: ServiceConfig has 'script_key', but EventHandler does not.
      #     So a default filter would exclude 'script_key'.
      #   HOWEVER: As of 2017-06-28, there is no discernible change in
      #     processing time, so no real reason to ask server to filter
      #     the results.
      #path = path || '?select=id,service'
      matches = list(path)
      # 2017-08-21: The only caller so far is the link command,
      #   which passes the Solution ID as svc_name.
      matches.select { |match| match[:service] == svc_name }
    end

    def self.warn_configfile_env_maybe
      if !$cfg.get('business.id', :env).to_s.empty? &&
         !$cfg.get('business.id', :project).to_s.empty? &&
         $cfg.get('business.id', :env) != $cfg.get('business.id', :project)
        MrMurano::Verbose.warning(
          'NOTE: MURANO_CONFIGFILE specifies a different business.id than the local project file'
        )
      end
    end

    include SyncUpDown
  end

  class Solution < SolutionBase
    def initialize(api_id=nil)
      meta = api_id if api_id.is_a?(Hash)
      api_id = api_id[:api_id] || api_id[:apiId] if api_id.is_a?(Hash)
      super(api_id)
      set_name
      @meta = {}
      @valid = false
      self.meta = meta unless meta.nil?
    end

    # The Solution @name.
    attr_reader :name

    # A reference to the business account object.
    attr_accessor :biz

    attr_reader :meta

    protected

    def state
      parts = super
      parts + [@name, @meta, @valid]
    end

    public

    # *** Network calls

    def version
      get('/version')
    end

    def info
      get
    end

    def info_safe
      @suppress_error = true
      resp = get
      if resp.is_a?(Hash) && !resp.key?(:error)
        self.meta = resp
        @valid_api_id = true
      else
        self.meta = {}
        @valid_api_id = false
      end
      @suppress_error = false
    end

    def list
      get('/')
      # MAYBE/2017-08-17:
      #   ret = get('/')
      #   return [] unless ret.is_a?(Array)
      #   sort_by_name(ret)
    end

    def usage
      get('/usage')
    end

    def log
      get('/logs')
    end

    # *** Solution utils

    def cfg_key_id
      "#{type}.id"
    end

    def cfg_key_name
      "#{type}.name"
    end

    # meta is from the list of solutions fetched from business/<bizid>/solution/,
    # e.g., from a call to solutions(), applications(), or products(); or it's
    # from a call to info.
    def meta=(data)
      @meta = data
      # Verify the solution ID.
      # NOTE: The Solution info fetched from business/<bizid>/solutions endpoint
      #   includes the keys, :name, :api_id, :sid, and :domain (see calls to
      #   solutions()). The solution details fetched from a call to Solution.get()
      #   include the keys, :name, :id, and :domain, among others.
      #   Note that the info() response does not include :type.
      api_id = @meta[:apiId] || @meta[:id]
      unless @api_id.to_s.empty? || api_id.to_s.empty? || api_id.to_s == @api_id.to_s
        warning(
          "#{type_name} ID mismatch. Server says #{fancy_ticks(api_id)}, " \
          "but config says #{fancy_ticks(@api_id)}."
        )
      end
      self.api_id = api_id
      # NOTE: In Murano 1.0 (pre-ADC), api_id != sid; in Murano 1.1, they're ==.
      #   The sid is used in business/<bid>/solution/<sid>
      #   The apiId is used in solution/<apiId>
      @sid = @meta[:sid]
      # Verify/set the name.
      unless @name.to_s.empty? || @meta[:name].to_s == @name.to_s
        warning(
          "Name mismatch. Server says #{fancy_ticks(@meta[:name])}, " \
          "but config says #{fancy_ticks(@name)}."
        )
      end
      return if @meta[:name].to_s.empty?
      # NOTE: Pre-ADC (a/k/a migrated) applications are not named, at least
      # when you query the business/<bid>/solution/ endpoint. But when you
      # call info_safe, which GETs the solution details, the name is
      # the domain and contains dots, which is considered an illegal name!
      return if @meta[:name] == @meta[:domain]
      set_name(@meta[:name])
      return if @valid_name || type == :solution
      warning(
        "Unexpected: Server returned invalid name: #{fancy_ticks(@meta[:name])}"
      )
    end

    def domain
      @meta[:domain]
    end

    def pretty_desc(add_type: false, raw_url: false)
      # [lb] would normally put presentation code elsewhere (i.e., model
      #   classes should not be formatting output), but this seems okay.
      desc = ''
      desc += "#{type.to_s.capitalize}: " if add_type
      name = !self.name.empty? && self.name || '~Unnamed~'
      api_id = !self.api_id.empty? && self.api_id || '~No-ID~'
      desc += "#{Rainbow(name).underline} <#{api_id}>"
      if domain
        desc += ' '
        desc += 'https://' unless raw_url
        desc += domain
      end
      desc
    end

    def type
      # info() doesn't return :type. So get from class name, e.g.,
      # if soln.class == 'MrMurano::Product', type is :product.
      #self.class.to_s.gsub(/^.*::/, '')
      #raise 'Not implemented'
      # Return, e.g., :application or :product.
      self.class.to_s.gsub(/^.*::/, '').downcase.to_sym
    end

    def type_name
      type.to_s.capitalize
    end

    # FIXME/Rubocop/2017-07-02: Style/AccessorMethodName
    #   Rename set_name, perhaps to apply_name?
    # rubocop:disable Style/AccessorMethodName
    def set_name(name=nil)
      # Use duck typing instead of `is_a? String` to be more duck-like.
      if name.respond_to?(:to_str) && name != ''
        @name = name
        # FIXME/Rubocop/2017-07-02: Double-negation
        @valid_name = !@name.match(name_validate_regex).nil?
      else
        @name = ''
        @valid_name = false
      end
    end

    # FIXME/Rubocop/2017-07-02: Style/AccessorMethodName
    #   Or maybe no. Cannot create method `def name!=(name)` and I [lb]
    #   kinda like the bang!. You could call it apply_name!, perhaps.
    def set_name!(name)
      raise 'Expecting name, not nothing' unless name && name != ''
      raise MrMurano::ConfigError.new(name_validate_help) unless name.match(name_validate_regex)
      @name = name
      @valid_name = true
    end

    def quoted_name
      if @name.to_s.empty?
        ''
      else
        fancy_ticks(@name)
      end
    end

    def valid?
      @valid_api_id && @valid_name
    end

    def valid_name?
      @valid_name
    end

    def name_validate_regex
      /^$/
    end

    def name_validate_help
      ''
    end
  end

  class Application < Solution
    def initialize(api_id=nil)
      @solntype = 'application.id'
      super
    end

    # FIXME/2017-07-02: Test long names:
    # Murano Appl:
    #     /^[a-zA-Z0-9-\s]{1,63}$/
    #   E.g., longest acceptable name:
    #     #ABCdefGHIjklMNOpqrSTUvwxYZAbcdefghijklmnopqrstuvwxyz34567890123
    #     99-Party-TIME-XXX-YOU-BETCHA-letsallridebikes4ever-and-4ever111
    # Murano Prod:
    #     /^(?![0-9])[a-zA-Z0-9]{2,63}$/
    #     Yassssssssssssssssssss11111111111111111111111111111111111111111
    # Either (should be too long):
    #     abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz345678901234567890123456789

    # FIXME/2017-06-28: Test uppercase characters again.

    # SYNC_ME: See regex in bizapi: lib/api/route/business/solution.js
    def name_validate_regex
      /^[a-zA-Z0-9\-\s]{1,63}$/
    end

    def name_validate_help
      %(
The Application name may only contain letters, numbers, and dashes.
The name must contain at least 1 character and no more than 63.
      ).strip
    end
  end

  class Product < Solution
    def initialize(api_id=nil)
      # Code path for `murano domain`.
      @solntype = 'product.id'
      super
    end

    # SYNC_ME: See regex in bizapi: lib/api/route/business/solution.js
    def name_validate_regex
      /^(?![0-9])[a-zA-Z0-9]{2,63}$/
    end

    def name_validate_help
      %(
The Product name may contain only letters and numbers, and the name may
not start with a number. The name must contain at least 3 characters and
no more than 63.
      ).strip
    end
  end
end

def solution_factory_reset(sol)
  new_sol = nil
  if sol.is_a? MrMurano::Solution
    unless sol.meta[:template].to_s.empty?
      begin
        clazz = Object.const_get("MrMurano::#{sol.meta[:template].capitalize}")
        new_sol = clazz.new(sol)
        new_sol.meta = sol.meta
      rescue NameError => _err
        MrMurano::Verbose.warning(
          "Unrecognized solution :template value: #{sol.meta[:template]}"
        )
      end
    end
  end
  new_sol || sol
end


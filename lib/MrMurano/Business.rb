# Last Modified: 2017.08.02 /coding: utf-8
# frozen_string_literal: true

# Copyright © 2016-2017 Exosite LLC.
# License: MIT. See LICENSE.txt.
#  vim:tw=0:ts=2:sw=2:et:ai

require 'date'
require 'inflecto'
require 'json'
require 'net/http'
require 'pathname'
require 'rainbow'
require 'uri'
require 'yaml'
require 'MrMurano/http'
require 'MrMurano/verbosing'
require 'MrMurano/Config'
require 'MrMurano/Solution'
require 'MrMurano/Passwords'

module MrMurano
  # The Business class represents an end user's solutions.
  class Business
    include Http
    include Verbose

    #attr_accessor :bid
    #attr_accessor :name
    attr_accessor :role
    attr_reader :meta
    attr_writer :bid
    attr_writer :name

    def initialize(data=nil)
      @bid = nil
      @name = nil
      @valid = false
      @user_bizes = {}
      self.meta = data unless data.nil?
    end

    def valid?
      @valid
    end

    def bid
      return @bid unless @bid.to_s.empty?
      $cfg['business.id'].to_s
    end

    def name
      return @name unless @name.to_s.empty?
      $cfg['business.name'].to_s
    end

    def bizid
      bid
    end

    def ==(other)
      other.class == self.class && other.state == state
    end

    protected

    def state
      [bid, name, @valid, @user_bizes]
    end

    public

    # Consume data returned from Account::businesses.
    def meta=(data)
      @valid = !data.nil?
      return unless @valid
      @bid = data[:bizid]
      @name = data[:name]
      @role = data[:role]
      @meta = data
    end

    def write(scope=:project)
      $cfg.set('business.id', bid, scope)
      $cfg.set('business.name', name, scope)
      self
    end

    # MAYBE: Check that ADC is enabled on the business. If not, tell
    #   user to run Murano 2.x. [lb] is not sure which value from
    #   Murano to check. Is it :enableMurano or :enableProjects?
    #   See the overview method.
    #def adc_compat_check
    #  unless $cfg['business.id'].nil?
    #    unless projects?($cfg['business.id'])
    #      # This is 3.x which does not support projects!
    #      warning('!'*80)
    #      warning "Your business requires Murano CLI 2.x"
    #      warning "Some features may not work correctly."
    #      warning('!'*80)
    #    end
    #  end
    #end

    def must_business_id!
      raise MrMurano::ConfigError.new(Business.missing_business_id_msg) if bid.to_s.empty?
    end

    def self.missing_business_id_msg
      %(
Missing Business ID.
Call `#{MrMurano::EXE_NAME} business list` to get a list of business IDs.
Set the ID temporarily using --config business.id=<ID>
or add to the project config using \`#{MrMurano::EXE_NAME} config business.id <ID>\`
or add to the user config using \`#{MrMurano::EXE_NAME} config business.id <ID> --user\`
or set it interactively using \`#{MrMurano::EXE_NAME} init\`
      ).strip
    end

    def pretty_name_and_id
      "‘#{Rainbow(name).underline}’ <#{bid}>"
    end

    # ---------------------------------------------------------------------

    #def projects?(id)
    #  ret = get("business/#{id}/overview")
    #  return false unless ret.is_a?(Hash)
    #  return false unless ret.key?(:tier)
    #  tier = ret[:tier]
    #  return false unless tier.is_a?(Hash)
    #  return false unless tier.key?(:enableProjects)
    #  tier[:enableProjects]
    #end

    def overview(&block)
      # Here are all the goodies that the overview endpoint returns:
      #  {:name=>"XXX", :email=>"XXX", :contact=>"XXX",
      #   :billing=>{
      #     :terms=>0, :balance=>0, :overdue=>0},
      #   :tier=>{
      #     :name=>"Community", :id=>"free", :price=>0, :users=>nil, :domains=>0,
      #     :ssl=>false, :rebrand=>false, :billing=>false, :multisolution=>true,
      #     :phonesupport=>false, :supportLevel=>"Community", :servicesTier=>"Core",
      #     :onboarding=>{}, :enableMurano=>true, :enableProjects=>true},
      #   :accountManager=>{
      #     :name=>"", :email=>"", :phone=>""},
      #   :accountLimits=>{
      #     :teamMembers=>1, :solutionApis=>1, :productModels=>1,
      #     :perModelDevices=>10, :perApiUsers=>10}, :lineitems=>[]}
      # EXPLAIN/2017-06-30: Which value(s) tell us if ADC is enabled?
      whirly_start('Fetching Business...')
      data = get("business/#{bid}/overview", &block)
      whirly_stop
      @valid = !data.nil?
      @name = data[:name] if @valid
      @valid
    end

    # ---------------------------------------------------------------------

    # 2017-06-30: In ADC-enabled Murano, there are now just 2 solution types.
    # LATER: This'll change in the future; Murano will support arbitrary
    #   solution types.
    #ALLOWED_TYPES = [:domain, :onepApi, :dataApi, :application, :product,].freeze
    ALLOWED_TYPES = %i[application product].freeze

    def solutions(
      type=:all, invalidate=false, match_sid=nil, match_name=nil, match_either=nil
    )
      debug "Getting all solutions of type #{type}"
      must_business_id!

      type = type.to_sym
      raise "Unknown type(#{type})" unless type == :all || ALLOWED_TYPES.include?(type)
      # Cache the result since sometimes both products() and applications() are called.
      if invalidate || @user_bizes[type].nil?
        #got = get('business/' + bid + '/solution/')
        got = get('business/' + bid + '/solution/') do |request, http|
          response = http.request(request)
          case response
          when Net::HTTPSuccess
            workit_response(response)
          when Net::HTTPForbidden # 403
            # FIXME/CONFIRM/2017-07-13: Is this really what platform
            # says when business has no solutions? I do not remember
            # seeing this before... [lb]
            nil
          else
            showHttpError(request, response)
          end
        end
        @user_bizes[type] = got unless got.nil?
      end
      if @user_bizes[type].nil?
        solz = []
      else
        solz = @user_bizes[type].dup
      end
      solz.select! { |i| i[:type] == type.to_s } unless type == :all

      solz.select! { |sol| sol[:apiId] == match_sid } unless match_sid.to_s.empty?
      solz.select! { |sol| sol[:name] == match_name } unless match_name.to_s.empty?
      unless match_either.to_s.empty?
        solz.select! do |sol|
          sol[:name] == match_either || sol[:apiId] == match_either
        end
      end

      solz.map! do |meta|
        case meta[:type].to_sym
        when :application
          MrMurano::Application.new(meta)
        when :product
          MrMurano::Product.new(meta)
        else
          warning("Unexpected solution type: #{meta[:type]}")
          MrMurano::Solution.new(meta)
        end
      end

      # Sort results.
      solz.sort_by!(&:name)
      solz.sort_by! { |sol| ALLOWED_TYPES.index(sol.type) }
    end

    ## Given a type (:application or :product), return a Solution instance.
    def solution_from_type!(type)
      type = type.to_s.to_sym
      raise "Unknown type(#{type})" unless ALLOWED_TYPES.include? type
      sid = MrMurano::Solution::INVALID_SID
      if type == :application
        sol = MrMurano::Application.new(sid)
      elsif type == :product
        sol = MrMurano::Product.new(sid)
      else
        raise "Unexpected path: Unrecognized type ‘#{type}’"
      end
      sol.biz = self
      sol
    end

    ## Create a new solution in the current business
    def new_solution!(name, type)
      must_business_id!
      sol = solution_from_type!(type)
      sol.set_name!(name)
      if $cfg['tool.dry']
        say "--dry: Not creating solution #{name}"
        return nil
      end
      whirly_start 'Creating solution...'
      resp = post(
        'business/' + bid + '/solution/',
        label: sol.name,
        type: sol.type,
      ) do |request, http|
        response = http.request(request)
        MrMurano::Verbose.whirly_stop
        if response.is_a?(Net::HTTPSuccess)
          workit_response(response)
        else
          MrMurano::Verbose.error(
            "Unable to create #{sol.type_name}: ‘#{sol.name}’"
          )
          ok = false
          if response.is_a?(Net::HTTPConflict)
            _isj, jsn = isJSON(response.body)
            if jsn[:message] == 'limit'
              ok = true
              MrMurano::Verbose.error(
                "You've reached your limit of #{Inflecto.pluralize(sol.type.to_s)}."
              )
            else
              ok = false
            end
          end
          showHttpError(request, response) unless ok
          # Hard stop.
          exit 1
          nil
        end
      end
      whirly_stop
      new_solution_prepare!(sol, resp)
    end

    def new_solution_prepare!(sol, resp)
      if resp.nil?
        error("Create #{sol.type_name} failed: Request failed")
        exit 1
      end
      unless resp.is_a?(Hash)
        error("Create #{sol.type_name} failed: Unexpected response: #{resp}")
        exit 1
      end
      if resp[:id].to_s.empty?
        error("Unexpected: Solution ID not returned: #{resp}")
        exit 1
      end
      sol.sid = resp[:id]
      sol.affirm_valid
      # 2017-06-29: The code used to hunt for the solution ID, because
      #   POST business/<bizid>/solution/ used to not return anything,
      #   but now it returns the solution ID.
      # FIXME: Delete this eventually, once you verify the new behavior.
      #if false
      #  # Create doesn't return anything, so go looking for it.
      #  MrMurano::Verbose.whirly_start('Verifying solution...')
      #  invalidate_cache = true
      #  ret = solutions(sol.type, invalidate_cache).select do |meta|
      #    meta[:name] == sol.name || meta[:domain] =~ /#{sol.name}\./i
      #  end
      #  MrMurano::Verbose.whirly_stop
      #  if ret.count > 1
      #    warning("Found more than 1 matching solution: #{ret}")
      #  elsif ret.count.zero?
      #    error("Unable to verify solution created for ‘#{sol.name}’: #{ret}")
      #    exit 3
      #  end
      #  sol.meta = ret.first
      #  if sol.sid.to_s.empty? then
      #    error("New solution created for ‘#{sol.name}’ missing ID?: #{ret}")
      #    exit 3
      #  end
      #  sol.sid = sid
      #end
      sol
    end

    def delete_solution(sid)
      must_business_id!
      delete('business/' + bid + '/solution/' + sid)
    end

    # ---------------------------------------------------------------------

    def products
      solutions(:product)
    end

    ## Create a new product in the current business
    def new_product(name, type=:product)
      new_solution!(name, type)
    end

    def delete_product(sid)
      delete_solution(sid)
    end

    # ---------------------------------------------------------------------

    def applications
      solutions(:application)
    end

    ## Create a new application in the current business
    def new_application(name, type=:application)
      new_solution!(name, type)
    end

    def delete_application(sid)
      delete_solution(sid)
    end
  end
end


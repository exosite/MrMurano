# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

require 'MrMurano/verbosing'

module MrMurano
  module SolutionId
    INVALID_API_ID = '-1'
    UNEXPECTED_TYPE_OR_ERROR_MSG = (
      'Unexpected result type or error: assuming empty instead'
    )

    attr_reader :api_id
    attr_reader :valid_api_id
    attr_reader :sid

    def init_api_id!(api_id=nil)
      @valid_api_id = false
      unless defined?(@solntype) && @solntype
        # Note that 'solution.id' isn't an actual config setting;
        # see instead 'application.id' and 'product.id'. We just
        # use 'solution.id' to indicate that the caller specified
        # a solution ID explicitly (i.e., it's not from the $cfg).
        raise 'Missing api_id or class @solntype!?' if api_id.to_s.empty?
        @solntype = 'solution.id'
      end
      if api_id
        self.api_id = api_id
      else
        # Get the application.id or product.id.
        self.api_id = $cfg[@solntype]
      end
      # Maybe raise 'No application!' or 'No product!'.
      return unless @api_id.to_s.empty?
      raise MrMurano::ConfigError.new("No #{/(.*).id/.match(@solntype)[1]} ID!")
    end

    def api_id?
      # The @api_id should never be nil or empty, but let's at least check.
      @api_id != INVALID_API_ID && !@api_id.to_s.empty?
    end

    def api_id=(api_id)
      api_id = INVALID_API_ID if api_id.nil? || !api_id.is_a?(String) || api_id.empty?
      if api_id.to_s.empty? || api_id == INVALID_API_ID || (defined?(@api_id) && api_id != @api_id)
        @valid_api_id = false
      end
      @api_id = api_id
      # MAGIC_NUMBER: The 2nd element is the solution ID, e.g., solution/<api_id>/...
      raise "Unexpected @uriparts_apidex #{@uriparts_apidex}" unless @uriparts_apidex == 1
      # We're called on initialize before @uriparts is built, so don't always do this.
      @uriparts[@uriparts_apidex] = @api_id if defined?(@uriparts)
    end

    def affirm_valid
      @valid_api_id = true
    end

    def valid_api_id?
      @valid_api_id
    end

    def endpoint(_path='')
      # This is hopefully just a DEV error, and not something user will ever see!
      return unless @uriparts[@uriparts_apidex] == INVALID_API_ID
      error("Solution ID missing! Invalid #{MrMurano::Verbose.fancy_ticks(@solntype)}")
      exit 2
    end
  end
end


# Last Modified: 2017.07.27 /coding: utf-8
# frozen_string_literal: true

# Copyright © 2016-2017 Exosite LLC.
# License: MIT. See LICENSE.txt.
#  vim:tw=0:ts=2:sw=2:et:ai

module MrMurano
  module SolutionId
    INVALID_SID = '-1'

    attr_reader :sid
    attr_reader :valid_sid

    def init_sid!(sid=nil)
      @valid_sid = false
      unless defined?(@solntype) && @solntype
        # Note that 'solution.id' isn't an actual config setting;
        # see instead 'application.id' and 'product.id'. We just
        # use 'solution.id' to indicate that the caller specified
        # a solution ID explicitly (i.e., it's not from the $cfg).
        raise 'Missing sid or class @solntype!?' if sid.to_s.empty?
        @solntype = 'solution.id'
      end
      if sid
        self.sid = sid
      else
        # Get the application.id or product.id.
        self.sid = $cfg[@solntype]
      end
      # Maybe raise 'No application!' or 'No product!'.
      return unless @sid.to_s.empty?
      raise MrMurano::ConfigError.new("No #{/(.*).id/.match(@solntype)[1]} ID!")
    end

    def sid?
      # The @sid should never be nil or empty, but let's at least check.
      @sid != INVALID_SID && !@sid.to_s.empty?
    end

    def sid=(sid)
      sid = INVALID_SID if sid.nil? || !sid.is_a?(String) || sid.empty?
      @valid_sid = false if sid.to_s.empty? || sid == INVALID_SID || (defined?(@sid) && sid != @sid)
      @sid = sid
      # MAGIC_NUMBER: The 2nd element is the solution ID, e.g., solution/<sid>/...
      raise "Unexpected @uriparts_sidex #{@uriparts_sidex}" unless @uriparts_sidex == 1
      # We're called on initialize before @uriparts is built, so don't always do this.
      @uriparts[@uriparts_sidex] = @sid if defined?(@uriparts)
    end

    def affirm_valid
      @valid_sid = true
    end

    def valid_sid?
      @valid_sid
    end

    # rubocop:disable Style/MethodName
    def apiId
      @sid
    end

    def endpoint(_path='')
      # This is hopefully just a DEV error, and not something user will ever see!
      return unless @uriparts[@uriparts_sidex] == INVALID_SID
      error("Solution ID missing! Invalid ‘#{@solntype}’")
      exit 2
    end
  end
end


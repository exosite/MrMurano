# Last Modified: 2017.07.26 /coding: utf-8
# frozen_string_literal: true

# Copyright © 2016-2017 Exosite LLC.
# License: MIT. See LICENSE.txt.
#  vim:tw=0:ts=2:sw=2:et:ai

require 'uri'
require 'MrMurano/Config'
require 'MrMurano/http'
require 'MrMurano/verbosing'
require 'MrMurano/SolutionId'
require 'MrMurano/SyncUpDown'

module MrMurano
  ## The details of talking to the Webservice service.
  module Webservice
    class WebserviceBase
      include Http
      include Verbose
      include SolutionId

      def initialize
        @solntype = 'application.id'
        @uriparts_sidex = 1
        init_sid!
        # FIXME/2017-06-05/MRMUR-XXXX: Update to new endpoint.
        #@uriparts = [:service, @sid, :webservice]
        @uriparts = [:solution, @sid]
        @itemkey = :id
        #@locationbase = $cfg['location.base']
        @location = nil
      end

      ## Generate an endpoint in Murano
      # Uses the uriparts and path
      # @param path String: any additional parts for the URI
      # @return URI: The full URI for this endpoint.
      def endpoint(path='')
        super
        parts = ['https:/', $cfg['net.host'], 'api:1'] + @uriparts
        s = parts.map{|v| v.to_s}.join('/')
        URI(s + path.to_s)
      end
      # …

      include SyncUpDown
    end
  end
end


# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

require 'eventmachine'
require 'faye/websocket'

require 'MrMurano/http'
require 'MrMurano/verbosing'

module MrMurano
  module Logs
    class Follow
      def initialize(query, limit=nil)
        @query = query
        @limit = limit
      end

      def run_event_loop(sol, &block)
        # block_given?
        @message_handler = block
        EM.run do
          uri = ws_logs_uri(sol)
          MrMurano::Http.curldebug_log(uri)
          run_client_websocket(uri)
        end
      end

      def ws_logs_uri(sol)
        protocol = ($cfg['net.protocol'] == 'https') && 'wss' || 'ws'
        # There are multiple endpoints: api:1/log/<sid>/[events|all|logs]
        # FIXME/2017-12-12 (landonb): Which endpoint do we want?
        #   /events, or /all, or /logs??
        uri = [
          protocol + ':/', $cfg['net.host'], 'api:1', 'solution', sol.api_id, 'logs',
        ].join('/')
        uri += %(?token=#{sol.token})
        uri += %(&query=#{@query}) unless @query.to_s.empty?
        uri += %(&limit=#{@limit}) unless @limit.nil?
        # MAYBE: (landonb): Add projection options? (Use for tracking exclusion.)
        #   uri += %(&projection={})
        # MAYBE: (landonb): Add limit option? This is number
        #  of old log events to fetch first before streaming.
        #   uri += %(&limit=20)
        uri
      end

      def run_client_websocket(uri)
        protocols = nil
        @ws = Faye::WebSocket::Client.new(uri, protocols, ping: 1)
        # (landonb): The ws.on method expects a class instance object. If we
        # were to pass a plain procedural method (i.e., a normal method defined
        # outside of a class), then Faye calls the function back with the first
        # parameter -- event -- as the 'self' of the callback! Furthermore, we
        # have to explicitly set `public :method`, which I didn't even think
        # you could do outside of a class! Ruby is so weird sometimes.
        @ws.on :open, &method(:ws_on_open)
        @ws.on :message, &method(:ws_on_message)
        @ws.on :close, &method(:ws_on_close)
      end

      def ws_on_open(event)
        MrMurano::Verbose.verbose("WebSocket opened: #{event}")
      end

      def ws_on_message(event)
        event.data.split("\n").each do |msg|
          if @message_handler
            @message_handler.call(msg)
          else
            puts "message: #{msg}"
          end
        end
        $stdout.flush
      end

      def ws_on_close(event)
        # Returns:
        #   event.code      # From RFC
        #   event.reason    # Not always set
        # For a list of close event codes, see:
        #   https://developer.mozilla.org/en-US/docs/Web/API/CloseEvent
        #   https://www.iana.org/assignments/websocket/websocket.xml#close-code-number
        #   https://tools.ietf.org/html/rfc6455#section-7.4.1
        @ws = nil
        MrMurano::Verbose.warning("WebSocket closed [#{event.code}]")
        EM.stop_event_loop
      end
    end
  end
end


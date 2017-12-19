# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# frozen_string_literal: true

# License: PROPRIETARY. See LICENSE.txt.
# Unauthorized copying of this file is strictly prohibited.
# vim:tw=0:ts=2:sw=2:et:ai

require 'eventmachine'
require 'faye/websocket'
require 'websocket/driver'

begin
  # From RSpec.
  require 'fixtures/websocket/simple_connection'
rescue LoadError
  # From invocation.
  require_relative 'simple_connection'
end

module SimpleWebSocket
  class Server
    DEFAULT_WS_PORT = 4180

    attr_writer :connection

    def initialize(options={}, connection=SimpleWebSocket::SimpleConnection)
      @options = options
      @connection = connection
    end

    def start_timer
      return if !@options[:timeout] || @options[:timeout] <= 0
      _timer = EventMachine::Timer.new(@options[:timeout]) do
        EM.stop_event_loop
      end
    end

    def start_server
      trap_interrupt
      trap_termination
      start_event_loop
    end

    def trap_interrupt
      Signal.trap('INT') do
        EM.stop_event_loop
      end
    end

    def trap_termination
      Signal.trap('TERM') do
        EM.stop_event_loop
      end
    end

    def start_event_loop
      EM.run do
        start_timer
        EM.start_server(
          '127.0.0.1',
          @options[:port],
          @connection
        )
      end
      # EM event loop runs until we tell it to stop.
    end
  end
end


# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# frozen_string_literal: true

# License: PROPRIETARY. See LICENSE.txt.
# Unauthorized copying of this file is strictly prohibited.
# vim:tw=0:ts=2:sw=2:et:ai

require 'eventmachine'
require 'websocket/driver'

module SimpleWebSocket
  class SimpleConnection < EventMachine::Connection
    def initialize
      @driver = WebSocket::Driver.server(self)

      @driver.on :connect, &method(:conn_on_open)

      @driver.on :message, -> (e) {
        @driver.text(e.data)
      }

      @driver.on :close, -> (e) {
        close_connection_after_writing
      }
    end

    def receive_data(data)
      @driver.parse(data)
    end

    def write(data)
      send_data(data)
    end

    def conn_on_open(event)
      if WebSocket::Driver.websocket?(@driver.env)
        @driver.start
      else
        # Other HTTP requests.
        warn "WARNING: unhandled request: #{event}"
      end
    end
  end
end


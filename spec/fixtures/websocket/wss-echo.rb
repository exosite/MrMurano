#!/usr/bin/env ruby
# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# frozen_string_literal: true

# License: PROPRIETARY. See LICENSE.txt.
# Unauthorized copying of this file is strictly prohibited.
# vim:tw=0:ts=2:sw=2:et:ai

require 'json'

require 'eventmachine'

require_relative 'simple_connection'
require_relative 'simple_options'

module EchoReceiver
  def initialize(driver)
    @driver = driver
  end

  def receive_data(data)
    # If we don't encode correctly, websocket-driver barfs. E.g., if we
    # tried to transmit "something with ‘curly quotes’", we'd get:
    #   `encode': "\xE2" from ASCII-8BIT to UTF-8 (Encoding::UndefinedConversionError)
    msg = data.chomp.force_encoding('UTF-8')
    puts "receive_data: #{msg}"
    # (landonb): What does the parse method do? I don't think we care.
    #   @driver.parse(data)
    if msg == 'EXIT'
      EM.stop_event_loop
    end
    @driver.text(msg)
  end
end

class WSStdinPassthru < SimpleWebSocket::SimpleConnection
  def conn_on_open(event)
    super(event)
    EM.attach $stdin, EchoReceiver, @driver
  end
end

def main
  options = SimpleWebSocket::Options.new.setup_and_parse_opts
  ws_svr = SimpleWebSocket::Server.new(options, WSStdinPassthru)
  ws_svr.start_server
end

main


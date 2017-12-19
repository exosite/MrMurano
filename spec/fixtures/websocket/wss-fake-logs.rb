#!/usr/bin/env ruby
# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# frozen_string_literal: true

# License: PROPRIETARY. See LICENSE.txt.
# Unauthorized copying of this file is strictly prohibited.
# vim:tw=0:ts=2:sw=2:et:ai

require_relative 'logs_blather'
require_relative 'simple_options'

def main
  options = SimpleWebSocket::Options.new.setup_and_parse_opts
  ws_svr = SimpleWebSocket::Server.new(options)
  ws_svr.connection = LogsBlatherConnection
  ws_svr.start_server
end

main


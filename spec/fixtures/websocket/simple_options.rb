# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# frozen_string_literal: true

# License: PROPRIETARY. See LICENSE.txt.
# Unauthorized copying of this file is strictly prohibited.
# vim:tw=0:ts=2:sw=2:et:ai

require 'optparse'

require_relative 'simple_server'

module SimpleWebSocket
  class Options
    def initialize
      reset_opts
    end

    def reset_opts
      @options = {
        behave: '',
        timeout: 0,
      }
      @options[:port] = SimpleWebSocket::Server::DEFAULT_WS_PORT
    end

    def setup_and_parse_opts
      opt_parser = OptionParser.new do |parser|
        parser.banner = "Usage: #{File.basename($PROGRAM_NAME)} [options]"
        opt_setup_help(parser)
        opt_setup_behavior(parser)
        opt_setup_timeout(parser)
      end
      opt_parser.parse!
      # The optparse library pulls values out of ARGV, so if we wanted to
      #   use positional parameters, we could inspect ARGV. But we don't.
      @options
    end

    def opt_setup_help(parser)
      parser.on('-h', '--help', 'Show this help message') do
        puts parser
      end
    end

    def opt_setup_behavior(parser)
      parser.on(
        '-b',
        '--behavior FLAVOR',
        "[reserved] How to behave. We probably don't need this..."
      ) do |flavor|
        @options[:behave] = flavor
      end
    end

    def opt_setup_port(parser)
      def_port = SimpleWebSocket::Server::DEFAULT_WS_PORT
      parser.on(
        '-p',
        '--port PORT',
        "Port on which to run server. Default: #{def_port}"
      ) do |msecs|
        @options[:timeout] = msecs.to_i / 1000.0
      end
    end

    def opt_setup_timeout(parser)
      parser.on(
        '-t',
        '--timeout MSECS',
        'How long to run before exiting. O to run forever.'
      ) do |msecs|
        @options[:timeout] = msecs.to_i / 1000.0
      end
    end
  end
end


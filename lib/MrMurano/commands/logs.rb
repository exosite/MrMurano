# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

require 'json'

require 'MrMurano/hash'
require 'MrMurano/http'
require 'MrMurano/makePretty'
require 'MrMurano/verbosing'
require 'MrMurano/Logs'
require 'MrMurano/ReCommander'
require 'MrMurano/Solution'

def command_logs(c)
  cmd_add_logs_meta(c)
  # Add global solution flag: --type [application|product].
  cmd_add_solntype_pickers(c, exclude_all: true)
  cmd_add_logs_options(c)
  c.action do |args, options|
    c.verify_arg_count!(args)
    logs_action(options)
  end
end

def cmd_add_logs_meta(c)
  c.syntax = %(murano logs [--options])
  c.summary = %(Get the logs for a solution)
  cmd_add_logs_help(c)
end

def cmd_add_logs_help(c)
  c.description = %(
    Get the logs for a solution.

    Each log record contains a number of fields, including the following.

    Severity
    ================================================================
    The severity of the log message, as defined by rsyslog standard.

      ID | Name          | Description
      -- | ------------- | -----------------------------------------
      0  | Emergency     | System is unusable
      1  | Alert         | Action must be taken immediately
      2  | Critical      | Critical conditions
      3  | Error         | Error conditions
      4  | Warning       | Warning conditions
      5  | Notice        | Normal but significant condition
      6  | Informational | Informational messages
      7  | Debug         | Debug-level messages

    Type
    ================================================================
    The type (emitter system) of the message.

      Name    | Description
      ------- | ----------------------------------------------------
      Script  | Pegasus-Engine: on User Lua “print()” function call
      Call    | Dispatcher: On service calls from Lua.
      Event   | Dispatcher: On event trigger from services
      Config  | Pegasus-API: On solution configuration change or
              |   used service deprecation warning.
      Service | Services generated & transmitted to Dispatcher.

    Message
    ================================================================
    Message can be up to 64kb containing plain text describing a log
    of the event

    Service
    ================================================================
    The service via which the event name is coming or the service of
    which the function is called.

    Event
    ================================================================
    Depending on the type:

      Event, Script => Event name
      Call          => operationId

    Tracking ID
    ================================================================
    End to end Murano processing id.
    Used to group logs together for one endpoint request.
  ).strip
end

def cmd_add_logs_options(c)
  c.option '-f', '--follow', %(Follow logs from server)
  c.option '-r', '--retry', %(Always retry the connection)
  c.option '--[no-]localtime', %(Adjust Timestamps to be in local time)
  c.option '--[no-]pretty', %(Reformat JSON blobs in logs.)
  c.option '--raw', %(Don't do any formating of the log data)
  c.option '--tracking', %(Include start of the Murano Tracking ID)
  c.option '--tracking-full', %(Include the full Murano Tracking ID)

  c.option '--http', %(Use HTTP connection [deprecated; will be removed])
end

def logs_action(options)
  cmd_default_logs_options(options)
  cmd_defaults_solntype_pickers(options, :application)
  sol = cmd_get_sol!(options)
  logs_display(sol, options)
end

def cmd_default_logs_options(options)
  options.default(
    follow: false,
    retry: false,
    pretty: true,
    localtime: true,
    raw: false,
    type: :application,
  )
end

def cmd_get_sol!(options)
  if options.type == :application
    MrMurano::Application.new
  elsif options.type == :product
    MrMurano::Product.new
  else
    MrMurano::Verbose.error "Unknown --type specified: #{options.type}"
    exit 1
  end
end

def logs_display(sol, options)
  if !options.follow
    logs_once(sol, options)
  else
    logs_follow(sol, options)
  end
end

def logs_once(sol, options)
  ret = sol.get('/logs')
  if ret.is_a?(Hash) && ret.key?(:items)
    ret[:items].reverse.each do |line|
      if options.raw
        puts line
      else
        puts MrMurano::Pretties.MakePrettyLogsV1(line, options)
      end
    end
  else
    sol.error "Could not get logs: #{ret}"
    exit 1
  end
end

def logs_follow(sol, options)
  if !options.http
    logs_follow_wss(sol, options)
  else
    logs_follow_http(sol, options)
  end
end

# FIXME: (landonb): Delete this after checking in once.
def logs_follow_http(sol, options)
  # Open a lasting connection and continually feed MakePrettyLogsV1().
  sol.get('/logs?polling=true') do |request, http|
    request['Accept-Encoding'] = 'None'
    http.request(request) do |response|
      remainder = ''
      response.read_body do |chunk|
        chunk = remainder + chunk unless remainder.empty?

        # For all complete JSON blobs, make them pretty.
        chunk.gsub!(/\{(?>[^}{]+|\g<0>)*\}/m) do |m|
          if options.raw
            puts m
          else
            begin
              js = JSON.parse(
                m,
                allow_nan: true,
                symbolize_names: true,
                create_additions: false,
              )
              puts MrMurano::Pretties.MakePrettyLogsV1(js, options)
            rescue StandardError
              sol.error '=== JSON parse error, showing raw instead ==='
              puts m
            end
          end
          '' #remove (we're kinda abusing gsub here.)
        end

        # Is there an incomplete one?
        chunk.match(/(\{.*$)/m) do |mat|
          remainder = mat[1]
        end
      end
    end
  end
# rubocop:disable Lint/HandleExceptions: Do not suppress exceptions.
rescue Interrupt => _
end

# LATER/2017-12-14 (landonb): Show logs from all associated solutions.
#   We'll have to wire all the WebSockets from within the EM.run block.
def logs_follow_wss(sol, options)
  formatter = get_formatter(options)
  keep_running = true
  while keep_running
    keep_running = options.retry
    logs = MrMurano::Logs::Follow.new
    logs.run_event_loop(sol) do |line|
      log_entry = parse_logs_line(line)
      formatter.call(log_entry, options) unless log_entry.nil?
    end
  end
end

def parse_logs_line(line)
  log_entry = JSON.parse(line)
  elevate_hash(log_entry)
rescue StandardError => err
  MrMurano::Verbose.warning "Not JSON: #{err} / #{line}"
  nil
end

def get_formatter(options)
  if options.raw
    method(:print_raw)
  else
    method(:print_pretty)
  end
end

def print_raw(line, _options={})
  puts line
end

def print_pretty(line, options={})
  puts MrMurano::Pretties.MakePrettyLogsV2(line, options)
rescue StandardError => err
  MrMurano::Verbose.error "Failed to parse log: #{err} / #{line}"
  raise
end

command :logs, &method(:command_logs)
alias_command 'logs application', 'logs', '--type', 'application'
alias_command 'logs product', 'logs', '--type', 'product'
alias_command 'application logs', 'logs', '--type', 'application'
alias_command 'product logs', 'logs', '--type', 'product'


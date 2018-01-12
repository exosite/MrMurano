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

# Because Ruby 2.0 does not support quoted keys, e.g., { '$eq': 'value' }.
# rubocop:disable Style/HashSyntax

class LogsCmd
  include MrMurano::Verbose

  LOG_EMITTER_TYPES = %i[
    script
    call
    event
    config
    service
  ].freeze

  LOG_SEVERITIES = %i[
    emergency
    alert
    critical
    error
    warning
    notice
    informational
    debug
  ].freeze

  # (lb): Ideally, we'd use +/- and not +/:, but rb-commander (or is it
  # OptionParser?) double-parses things that look like switches. E.g.,
  # `murano logs --types -call` would set options.types to ["-call"]
  # but would also set options.config to "all". Just one more reason
  # I do not think rb-commander should call itself a "complete solution".
  # (Note also we cannot use '!' instead of '-', because Bash.)
  # Another option would be to use the "no-" option, e.g., "--[no-]types",
  # but then what do you do with the sindle character '-T' option?
  EXCLUDE_INDICATOR = ':'
  INCLUDE_INDICATOR = '+'

  def initialize
    @filter_severity = []
    @filter_types = []
    @filter_events = []
    @filter_endpoints = []
  end

  def command_logs(cmd)
    cmd_add_logs_meta(cmd)
    # Add global solution flag: --type [application|product].
    cmd_add_solntype_pickers(cmd, exclude_all: true)
    cmd_add_logs_options(cmd)
    cmd_add_format_options(cmd)
    cmd_add_filter_options(cmd)
    cmd.action do |args, options|
      @options = options
      cmd.verify_arg_count!(args)
      logs_action
    end
  end

  def cmd_add_logs_meta(cmd)
    cmd.syntax = %(murano logs [--options])
    cmd.summary = %(Get the logs for a solution)
    cmd_add_help(cmd)
    cmd_add_examples(cmd)
  end

  def cmd_add_help(cmd)
    cmd.description = %(
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
  Script  | Script Engine: When User Lua script calls `print()`
  Call    | Dispatcher: On service calls from Lua
  Event   | Dispatcher: On event trigger from services
  Config  | API: On solution configuration change, or
          |      used service deprecation warning
  Service | Services generated & transmitted to Dispatcher


Message
================================================================
Message can be up to 64kb containing plain text describing a log
of the event.

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

  # NOTE (landonb): The Service & Script Debug Log RFC mentions 'subject',
  #                 but I've never seen it in any debug log reply.
  #    The Subject line can be used for a short summary.
  #    It should be shorter than 80 characters.

  def cmd_add_examples(cmd)
    cmd.example %(
      View the last 100 product log entries
    ).strip, 'murano logs'

    cmd.example %(
      View the last 10 product log entries
    ).strip, 'murano logs --limit 10'

    cmd.example %(
      Stream the application logs, including the last 100 records
    ).strip, 'murano logs --follow'

    cmd.example %(
      Stream the logs generated by 'device2' events
    ).strip, 'murano logs --follow --event device2'

    cmd.example %(
      Stream the logs generated by the types, 'event' and 'script'
    ).strip, 'murano logs --follow --types event,script'

    cmd.example %(
      Stream the logs generated by the types, 'call' and 'config'
    ).strip, 'murano logs --follow --types call -T config'

    cmd.example %(
      Exclude the logs generated by the 'script' type
    ).strip, 'murano logs --follow -T :script'

    cmd.example %(
      Show last 100 logs with any severity level expect DEBUG
    ).strip, 'murano logs --severity 0-6'

    cmd.example %(
      Stream only the logs with the DEBUG severity level
    ).strip, 'murano logs --follow -V --severity deB'

    cmd.example %(
      Stream logs with the severity levels ALERT, CRITICAL, WARNING, and DEBUG
    ).strip, 'murano logs --follow -V -l 1-2,WARN,7'

    cmd.example %(
      Show only log entries whose message contains the case-insensitive substring, "hello"
    ).strip, 'murano logs --message hello'

    cmd.example %(
      Show only log entries whose message contains the case-sensitive substring, "Hello"
    ).strip, 'murano logs --message Hello --no-insensitive'

    cmd.example %(
      Display logs using a custom timestamp format (see `man strftime` for format options)
    ).strip, %(murano logs --sprintf '%m/%d/%Y %Hh %Mm %Ss')

    cmd.example %(
      Stream logs using compact format, using one line per log entry
    ).strip, 'murano logs --follow --one-line'

    cmd.example %(
      Stream logs using two lines per log entry (1 header line and 1 message line)
    ).strip, 'murano logs --follow --message-only'

    cmd.example %(
      Format log entries as JSON (useful if you want to pipe the results, e.g., to `jq`)
    ).strip, 'murano logs --json'

    cmd.example %(
      Format log entries as YAML
    ).strip, 'murano logs --yaml'
  end

  def cmd_add_logs_options(cmd)
    cmd.option '-f', '--[no-]follow', %(Follow logs from server)
    cmd.option '-r', '--retry', %(Always retry the connection)
    cmd.option(
      '-i', '--[no-]insensitive',
      %(Use case-insensitive matching (default: true))
    )
    cmd.option '-N', '--limit LIMIT', Integer, %(Retrieve this many existing logs at start of command (only works with --no-follow))
  end

  def cmd_add_format_options(cmd)
    cmd_add_format_options_localtime(cmd)
    cmd_add_format_options_pretty(cmd)
    cmd_add_format_options_raw(cmd)
    cmd_add_format_options_message_only(cmd)
    cmd_add_format_options_one_line(cmd)
    cmd_add_format_options_align_columns(cmd)
    cmd_add_format_options_indent_body(cmd)
    cmd_add_format_options_separators(cmd)
    cmd_add_format_options_include_tracking(cmd)
    cmd_add_format_options_sprintf(cmd)
  end

  def cmd_add_format_options_localtime(cmd)
    cmd.option '--[no-]localtime', %(Adjust Timestamps to be in local time)
  end

  def cmd_add_format_options_pretty(cmd)
    cmd.option '--[no-]pretty', %(Reformat JSON blobs in logs)
  end

  def cmd_add_format_options_raw(cmd)
    cmd.option '--raw', %(Do not format the log data)
  end

  def cmd_add_format_options_message_only(cmd)
    cmd.option '-o', '--message-only', %(Show only headers and the 'print' message)
  end

  def cmd_add_format_options_one_line(cmd)
    cmd.option '--one-line', %(Squeeze each log entry onto one line (wrapping as necessary))
  end

  def cmd_add_format_options_align_columns(cmd)
    cmd.option '--[no-]align', %(Align columns in formatted output)
  end

  def cmd_add_format_options_indent_body(cmd)
    cmd.option '--[no-]indent', %(Indent body content in formatted output)
  end

  def cmd_add_format_options_separators(cmd)
    cmd.option '--[no-]separators', %(Indent body content in formatted output)
  end

  def cmd_add_format_options_include_tracking(cmd)
    cmd.option '--[no-]tracking', %(Include tracking ID)
  end

  def cmd_add_format_options_sprintf(cmd)
    cmd.option '--sprintf FORMAT', %(Specify timestamp format (default: '%Y-%m-%d %H:%M:%S'))
  end

  def cmd_add_filter_options(cmd)
    # Common log fields.
    cmd_add_filter_option_severity(cmd)
    cmd_add_filter_option_type(cmd)
    cmd_add_filter_option_message(cmd)
    cmd_add_filter_option_service(cmd)
    cmd_add_filter_option_event(cmd)
    # Skipping: timestamp filter
    # Skipping: tracking_id filter
    # Type-specific fields in data.
    cmd_add_filter_option_endpoint(cmd)
    # Skipping: module filter
    # Skipping: elapsed time filter (i.e., could do { elapsed: { $gt: 10 } })
  end

  def cmd_add_filter_option_severity(cmd)
    cmd.option(
      '-l', '--severity [NAME|LEVEL|RANGE[,NAME|LEVEL|RANGE...]]', Array,
      %(
Only show log entries of this severity.
May be specified by name, value, or range, e.g., WARN, 3, 1-4.
  #{LOG_SEVERITIES.map.with_index { |s, i| "#{s}(#{i})" }.join(' ')}
      ).strip
    ) do |value|
      @filter_severity.push value
    end
  end

  def cmd_add_filter_option_type(cmd)
    emitter_type_help = %(
Filter log entries by type (emitter system) of message.
EMITTERS is 1 or more comma-separated types:
  #{LOG_EMITTER_TYPES.map(&:to_s)}
Use a "#{INCLUDE_INDICATOR}" or "#{EXCLUDE_INDICATOR}" prefix to include or exclude types, respectively.
    ).strip
    cmd.option('-T EMITTERS', '--types EMITTERS', Array, emitter_type_help) do |values|
      # This seems a little roundabout, but rb-commander only keeps last value.
      @filter_types.push values
      values.map do |val|
        val.sub(/^[#{INCLUDE_INDICATOR}#{EXCLUDE_INDICATOR}]/, '')
      end
    end
  end

  def cmd_add_filter_option_message(cmd)
    cmd.option '-m', '--message GLOB', %(
      Filter log entries by the message contents
    ).strip
  end

  def cmd_add_filter_option_service(cmd)
    cmd.option '-s', '--service GLOB', %(
      Filter log entries by the originating service
    ).strip
  end

  def cmd_add_filter_option_event(cmd)
    cmd.option(
      '-E', '--event GLOB', Array,
      %(Filter log entries by the event)
    ) do |value|
      @filter_events.push value
    end
  end

  def cmd_add_filter_option_endpoint(cmd)
    cmd.option(
      '-e', '--endpoint ENDPOINT',
      %(Filter log entries by the endpoint (ENDPOINT is VERB:PATH))
    ) do |value|
      @filter_endpoints.push value
    end
  end

  def logs_action
    cmd_default_logs_options
    cmd_verify_logs_options!
    cmd_defaults_solntype_pickers(@options, :application)
    @query = assemble_query
    verbose %(query: #{@query})
    sol = cmd_get_sol!
    logs_display(sol)
  end

  def cmd_default_logs_options
    @options.default(
      type: :application,
      follow: false,
      retry: false,
      insensitive: true,
      limit: nil,
      localtime: true,
      pretty: true,
      raw: false,
      message_only: false,
      one_line: false,
      tracking: false,
      sprintf: '%Y-%m-%d %H:%M:%S',
      align: false,
      indent: false,
      separators: false,
      severity: nil,
      types: [],
      message: nil,
      service: nil,
      event: nil,
      endpoint: nil,
    )
  end

  def cmd_verify_logs_options!
    n_formatting = 0
    n_formatting += 1 if @options.raw
    n_formatting += 1 if @options.message_only
    n_formatting += 1 if @options.one_line
    # Global options should really be checked elsewhere. Oh, well.
    n_formatting += 1 if @options.json
    n_formatting += 1 if @options.yaml
    n_formatting += 1 if @options.pp
    return unless n_formatting > 1
    format_options = '--raw, --message-only, --one-line, --json, --yaml, or --pp'
    warn "Try using just one of #{format_options}, but not two or more."
    exit 1
  end

  def cmd_get_sol!
    if @options.type == :application
      MrMurano::Application.new
    elsif @options.type == :product
      MrMurano::Product.new
    else
      error "Unknown --type specified: #{@options.type}"
      exit 1
    end
  end

  def assemble_query
    query_parts = {}
    assemble_query_severity(query_parts)
    assemble_query_types_array(query_parts)
    assemble_query_message(query_parts)
    assemble_query_service(query_parts)
    assemble_query_event(query_parts)
    assemble_query_endpoint(query_parts)
    # Assemble and return actual query string.
    assemble_query_string(query_parts)
  end

  def assemble_query_severity(query_parts)
    filter_severity = @filter_severity.flatten
    return if filter_severity.empty?
    indices = []
    filter_severity.each do |sev|
      index = sev if sev =~ /^[0-9]$/
      index = LOG_SEVERITIES.find_index { |s| s.to_s =~ /^#{sev.downcase}/ } unless index
      if index
        indices.push index.to_i
      else
        parts = /^([0-9])-([0-9])$/.match(sev)
        if !parts.nil?
          start = parts[1].to_i
          finis = parts[2].to_i
          if start < finis
            more_indices = (start..finis).to_a
          else
            more_indices = (finis..start).to_a
          end
          indices += more_indices
        else
          warning "Invalid severity: #{sev}"
          exit 1
        end
      end
    end
    query_parts['severity'] = { '$in' => indices }
  end

  def assemble_query_types_array(query_parts)
    assemble_in_or_nin_query(query_parts, 'type', @filter_types.flatten) do |type|
      index = LOG_EMITTER_TYPES.find_index { |s| s.to_s =~ /^#{type.downcase}/ }
      if index
        LOG_EMITTER_TYPES[index].to_s
      else
        warning "Invalid emitter type: #{type}"
        exit 1
      end
    end
  end

  def assemble_query_message(query_parts)
    assemble_string_search_one(query_parts, 'message', @options.message, regex: true)
  end

  def assemble_query_service(query_parts)
    assemble_string_search_one(query_parts, 'service', @options.service)
  end

  def assemble_query_event(query_parts)
    assemble_string_search_many(query_parts, 'event', @filter_events)
  end

  def assemble_query_endpoint(query_parts)
    terms = @filter_endpoints.map { |endp| format_endpoint(endp) }
    # FIXME: (lb): MUR-5446: Still unresolved: How to query endpoints.
    #   The RFC says to use 'endpoint', but I've also been told to use
    #   'data.section.' Neither work for me.
    assemble_string_search_many(query_parts, 'data.section', terms)
  end

  def format_endpoint(endp)
    # E.g., ?query={"data.section":"get_/set"}
    # The format the user is most likely to use is with a colon, but
    # we can let the user be a little sloppy, too, e.g., "get /set".
    parts = endp.split(' ', 2)
    parts = endp.split(':', 2) unless parts.length > 1
    parts.join('_').downcase
  end

  def assemble_string_search_one(query_parts, field, value, regex: false)
    return if value.to_s.empty?
    if !regex
      # Note that some options support strict equality, e.g.,
      #   { 'key': { '$eq': 'value' } }
      # but post-processed keys like 'data.section' do not.
      # So we just do normal equality, e.g.,
      #   { 'key': 'value' }
      query_parts[field] = value
    else
      query_parts[field] = { :'$regex' => value }
      query_parts[field][:'$options'] = 'i' if @options.insensitive
    end
  end

  def assemble_string_search_many(query_parts, field, arr_of_arrs)
    terms = arr_of_arrs.flatten
    return if terms.empty?
    if terms.length == 1
      assemble_string_search_one(query_parts, field, terms[0])
    else
      assemble_in_or_nin_query(query_parts, field, terms)
    end
  end

  def assemble_in_or_nin_query(query_parts, field, terms, &block)
    return if terms.empty?
    exclude = term_indicates_exclude?(terms[0])
    resolved_terms = []
    terms.each do |term|
      process_query_term(term, resolved_terms, exclude, field, terms, &block)
    end
    return if resolved_terms.empty?
    if !exclude
      operator = '$in'
    else
      operator = '$nin'
    end
    query_parts[field] = { operator.to_s => resolved_terms }
  end

  def term_indicates_exclude?(term)
    if term.start_with? EXCLUDE_INDICATOR
      true
    else
      false
    end
  end

  def process_query_term(term, resolved_terms, exclude, field, terms)
    verify_term_plus_minux_prefix!(term, exclude, field, terms)
    term = term.sub(/^[#{INCLUDE_INDICATOR}#{EXCLUDE_INDICATOR}]/, '')
    term = yield term if block_given?
    resolved_terms.push term
  end

  def verify_term_plus_minux_prefix!(term, exclude, field, terms)
    return unless term =~ /^[#{INCLUDE_INDICATOR}#{EXCLUDE_INDICATOR}]/
    return unless (
      (!exclude && term.start_with?(EXCLUDE_INDICATOR)) ||
      (exclude && term.start_with?(INCLUDE_INDICATOR))
    )
    warning(
      %(You cannot mix + and ! for "#{field}": #{terms.join(',')})
    )
    exit 1
  end

  def assemble_query_string(query_parts)
    if query_parts.empty?
      ''
    else
      # (lb): I tried escaping parts of the query but it broke things.
      # So I'm assuming we don't need CGI.escape or URI.encode_www_form.
      query_parts.to_json
    end
  end

  def logs_display(sol)
    if !@options.follow
      logs_once(sol)
    else
      logs_follow(sol)
    end
  end

  def logs_once(sol)
    ret = sol.get("/logs#{query_string}")
    if ret.is_a?(Hash) && ret.key?(:items)
      ret[:items].reverse.each do |line|
        if pretty_printing
          print_pretty(line)
        else
          print_raw(line)
        end
      end
    else
      sol.error "Could not get logs: #{ret}"
      exit 1
    end
  end

  def query_string
    # NOTE (lb): Unsure whether we need to encode parts of the query,
    # possibly with CGI.escape. Note that http.get calls
    # URI.encode_www_form(query), which the server will accept,
    # but it will not produce any results.
    params = []
    params += ["query=#{@query}"] unless @query.empty?
    params += ["limit=#{@options.limit}"] unless @options.limit.nil?
    querys = params.join('&')
    querys = "?#{querys}" unless querys.empty?
    querys
  end

  # LATER/2017-12-14 (landonb): Show logs from all associated solutions.
  #   We'll have to wire all the WebSockets from within the EM.run block.
  def logs_follow(sol)
    formatter = fetch_formatter
    keep_running = true
    while keep_running
      keep_running = @options.retry
      logs = MrMurano::Logs::Follow.new(@query, @options.limit)
      logs.run_event_loop(sol) do |line|
        log_entry = parse_logs_line(line)
        if log_entry[:statusCode] == 400
          warning "Query error: #{log_entry}"
        else
          formatter.call(log_entry) unless log_entry.nil?
        end
      end
    end
  end

  def parse_logs_line(line)
    log_entry = JSON.parse(line)
    elevate_hash(log_entry)
  rescue StandardError => err
    warning "Not JSON: #{err} / #{line}"
    nil
  end

  def fetch_formatter
    if pretty_printing
      method(:print_pretty)
    else
      method(:print_raw)
    end
  end

  def pretty_printing
    !@options.raw && ($cfg['tool.outformat'] == 'best')
  end

  def print_raw(line)
    outf line
  end

  def print_pretty(line)
    determine_format(line) if @log_format_is_v2.nil?
    if @log_format_is_v2
      puts MrMurano::Pretties.MakePrettyLogsV2(line, @options)
    else
      puts MrMurano::Pretties.MakePrettyLogsV1(line, @options)
    end
  rescue StandardError => err
    error "Failed to parse log: #{err} / #{line}"
    raise
  end

  def determine_format(line)
    # FIXME/2018-01-05 (landonb): On bizapi-dev, I see new-format logs,
    # but on bizapi-staging, I see old school format. So deal with it.
    # Logs V1 have 4 entries: type, timestamp, subject, data
    # Logs V2 have lots more entries, including type, timestamp and data.
    # We could use presence of subject to distinguish; or we could check
    # timestamp, which is seconds in V1 but msecs in V2; or we could check
    # data, which is string in V1, and Hash in V2.
    @log_format_is_v2 = !(line[:data].is_a? String)
  end
end

def wire_cmd_logs
  logs_cmd = LogsCmd.new
  command(:logs) { |cmd| logs_cmd.command_logs(cmd) }
  alias_command 'logs application', 'logs', '--type', 'application'
  alias_command 'logs product', 'logs', '--type', 'product'
  alias_command 'application logs', 'logs', '--type', 'application'
  alias_command 'product logs', 'logs', '--type', 'product'
end

wire_cmd_logs


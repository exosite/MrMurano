# Last Modified: 2017.10.05 /coding: utf-8
# frozen_string_literal: true

# Copyright © 2016-2017 Exosite LLC.
# License: MIT. See LICENSE.txt.
#  vim:tw=0:ts=2:sw=2:et:ai

require 'date'
require 'MrMurano/ReCommander'
require 'MrMurano/Solution-ServiceConfig'
require 'MrMurano/SubCmdGroupContext'

module MrMurano
  module ServiceConfigs
    class Tsdb < ServiceConfig
      def initialize(api_id=nil)
        # FIXME/2017-07-03: What soln types have TSDBs?
        @solntype = 'application.id'
        super
        @service_name = 'tsdb'
      end

      def write(data)
        call(:write, :post, data)
      end

      def query(query)
        call(:query, :post, query)
      end

      # FIXME/2017-08-16: Convert to snake_case. Or is this method name magical?
      # rubocop:disable Style/MethodName: Use snake_case for method names.
      def listTags
        call(:listTags)
      end

      def listMetrics
        call(:listMetrics)
      end

      def str_to_timestamp(str)
        if str =~ /^\d+(u|ms|s)?$/
          str
        else
          dt = DateTime.parse(str)
          (dt.to_time.to_f * 1_000_000).to_i
        end
      end
    end
  end
end

command :tsdb do |c|
  c.syntax = %(murano tsdb)
  c.summary = %(Show list of TSDB commands)
  c.description = %(
The tsdb sub-commands let you interact directly with the TSDB instance in a
solution. This allows for easier debugging, being able to quickly try out
different queries or write test data.
  ).strip
  c.project_not_required = true
  c.subcmdgrouphelp = true

  c.action do |_args, _options|
    ::Commander::UI.enable_paging unless $cfg['tool.no-page']
    say MrMurano::SubCmdGroupHelp.new(c).get_help
  end
end

command 'tsdb write' do |c|
  c.syntax = %(murano tsdb write [--options] <metric=value>|@<tag=value> … )
  c.summary = %(Write data to the TSDB)
  c.description = %(
Write data to the time series database (TSDB).

TIMESTAMP is microseconds since unix epoch, or can be suffixed with units.
Units are u (microseconds), ms (milliseconds), s (seconds)

Also, many date-time formats can be parsed and will be converted to microseconds
  ).strip

  c.option '--when TIMESTAMP', %(When this data happened (default: now))
  # TODO: add option to take data from STDIN.

  c.example 'murano tsdb write hum=45 lux=12765 @sn=44', %(Write two metrics (hum and lux) with a tag (sn))

  c.action do |args, options|
    # SKIP: c.verify_arg_count!(args)

    sol = MrMurano::ServiceConfigs::Tsdb.new

    # we have hash of tags, hash of metrics, optional timestamp.
    metrics = {}
    tags = {}
    args.each do |item|
      key, value = item.split('=', 2)
      if key[0] == '@'
        tags[key[1..-1]] = value.to_s # tags are always strings.
      else
        value = value.to_i if value == value.to_i.to_s
        metrics[key] = value
      end
    end

    data = { tags: tags, metrics: metrics }
    if !options.when.nil? && options.when != 'now'
      data[:ts] = sol.str_to_timestamp(options.when)
    end

    ret = sol.write(data)
    sol.error ret if ret != {}
  end
end

command 'tsdb query' do |c|
  c.syntax = %(murano tsdb query [--options] <metric>|@<tag=value> …)
  c.summary = %(Query data from the TSDB)
  c.description = %(
Query data from the time series database (TSDB).

FUNCS is a comma separated list of the aggregate functions.
Currently: avg, min, max, count, sum.  For string metrics, only count.

FILL is null, none, any integer, previous

DURATION is an integer with time unit to indicate relative time before now.
Units are u (microseconds), ms (milliseconds), s (seconds), m (minutes),
h (hours), d (days), w (weeks)

TIMESTAMP is microseconds since unix epoch, or can be suffixed with units.
Units are u (microseconds), ms (milliseconds), s (seconds)

Also, many date-time formats can be parsed and will be converted to microseconds
  ).strip

  c.option '--start_time TIMESTAMP', %(Start time range)
  c.option '--end_time TIMESTAMP', %(End time range; defaults to now)
  c.option '--relative_start DURATION', %(Start time relative from now)
  c.option '--relative_end DURATION', %(End time relative from now)
  c.option '--sampling_size DURATION', %(The size of time slots used for downsampling)
  c.option '--limit NUM', Integer, %(Limit number of data points returned)
  c.option '--epoch UNIT', %w[u ms s], %(Set size of returned timestamps)
  c.option '--mode MODE', %w[merge split], %(Merge or split each returned metric)
  c.option '--fill FILL', %(Value to fill for time slots with no data points exist in merge mode)
  c.option '--order_by ORDER', %w[desc asc], %(Return results in ascending or descending time order)
  c.option '--aggregate FUNCS', %(Aggregation functions to apply)

  c.option '-o', '--output FILE', %(Download to file instead of STDOUT)

  c.example 'murano tsdb query hum', 'Get all hum metric entries'
  c.example 'murano tsdb query hum @sn=45', 'Get all hum metric entries for tag sn=45'
  c.example 'murano tsdb query hum --limit 1', 'Get just the most recent entry'
  c.example 'murano tsdb query hum --relative_start 1h', 'Get last hour of hum entries'
  c.example 'murano tsdb query hum --relative_start -1h', 'Get last hour of hum entries'
  c.example 'murano tsdb query hum --relative_start 2h --relative_end 1h', 'Get hum entries of two hours ago, but not the last hours'
  c.example 'murano tsdb query hum --sampling_size 30m', 'Get one hum entry from each 30 minute chunk of time'
  c.example 'murano tsdb query hum --sampling_size 30m --aggregate avg', 'Get average hum entry from each 30 minute chunk of time'

  def query_from_args(args)
    query = {}
    tags = {}
    metrics = []
    args.each do |arg|
      if arg =~ /=/
        # a tag.
        k, v = arg.split('=', 2)
        k = k[1..-1] if k[0] == '@'
        tags[k] = v
      else
        metrics << arg
      end
    end
    query[:tags] = tags unless tags.empty?
    query[:metrics] = metrics unless metrics.empty?
    query
  end

  def query_add_options(query, options, sol)
    # A query without any metrics is invalid.  So if the user didn't provide any,
    # look up all of them (well, frist however many) and use that list.
    if query[:metrics].to_s.empty?
      ret = sol.listMetrics
      query[:metrics] = ret[:metrics]
    end

    unless options.start_time.nil?
      query[:start_time] = sol.str_to_timestamp(options.start_time)
    end
    unless options.end_time.nil?
      query[:end_time] = sol.str_to_timestamp(options.end_time)
    end

    unless options.relative_start.nil?
      o = options.relative_start
      o = "-#{o}" unless o[0] == '-'
      query[:relative_start] = o
    end
    unless options.relative_end.nil?
      o = options.relative_end
      o = "-#{o}" unless o[0] == '-'
      query[:relative_end] = o
    end
    query[:sampling_size] = options.sampling_size unless options.sampling_size.nil?

    query[:limit] = options.limit unless options.limit.nil?
    query[:epoch] = options.epoch unless options.epoch.nil?
    query[:mode] = options.mode unless options.mode.nil?
    query[:order_by] = options.order_by unless options.order_by.nil?

    query[:fill] = options.fill unless options.fill.nil?
    return if options.aggregate.nil?
    query[:aggregate] = options.aggregate.split(',')
  end

  def unpack_aggregate(query, options, dd)
    # If aggregated, then we need to break up the columns. since each is now a
    # hash of the aggregated functions

    # 2017-10-05: Some examples.
    #
    # When using, e.g., --sampling_size 30m
    #
    #   { :values=>[["2017-10-05T13:30:00.000000+00:00", {:avg=>360.5}]],
    #     :tags=>{},
    #     :metrics=>["temperature"],
    #     :columns=>["time", "temperature"] }
    #
    # When not using --sampling_size, e.g.,
    #
    #   { :values=>{:temperature=>{:avg=>360.5}},
    #     :tags=>{},
    #     :metrics=>["temperature"] }
    #
    # Or, if there are not metrics in the specified time frame,
    #
    #   { :values=>{:temperature=>{:avg=>nil}},
    #     :tags=>{},
    #     :metrics=>["temperature"] }

    if options.aggregate.nil?
      # Return just :columns and :values to not pollute other
      # output, i.e., --json, etc.
      [dd[:columns], dd[:values]]
    elsif options.sampling_size.nil?
      # dd[:values] is a Hash.
      unpack_grouped_values(query, dd)
    else
      # dd[:values] is a list.
      unpack_raw_values(query, dd)
    end
  end

  def unpack_raw_values(query, dd)
    vals = dd[:values].map do |row|
      row.map do |value|
        if value.is_a? Hash
          query[:aggregate].map { |qa| value[qa.to_sym] }
        elsif value == 'none'
          # Fill in empty cells, one for each aggregate.
          query[:aggregate].map { 'none' }
        else
          value
        end
      end.flatten
    end
    cols = dd[:columns].map do |col|
      if col == 'time'
        col
      else
        query[:aggregate].map { |qa| "#{col}.#{qa}" }
      end
    end.flatten!
    [cols, vals]
  end

  def unpack_grouped_values(query, dd)
    vals = []
    cols = ['metric'] + query[:aggregate]
    dd[:values].map do |metric, results|
      row = [metric]
      query[:aggregate].each do |agg|
        agg = agg.to_sym
        if !results.key? agg
          row += ['none']
        else
          row += [results[agg] || '']
        end
      end
      vals += [row]
    end
    [cols, vals]
  end

  def query_solution_query(query, options, sol)
    io = File.open(options.output, 'w') if options.output
    results = sol.query(query)
    sol.outf(results) do |dd, ios|
      cols, vals = unpack_aggregate(query, options, dd)
      sol.tabularize(
        {
          headers: cols,
          rows: vals,
        },
        ios
      )
    end
    io.close unless io.nil?
  end

  c.action do |args, options|
    # SKIP: c.verify_arg_count!(args)
    query = query_from_args(args)
    sol = MrMurano::ServiceConfigs::Tsdb.new
    query_add_options(query, options, sol)
    query_solution_query(query, options, sol)
  end
end

command 'tsdb list tags' do |c|
  c.syntax = %(murano tsdb list tags [--options])
  c.summary = %(List tags)
  c.description = %(
List tags.
  ).strip

  c.option '--values', %(Include the known tag values)

  c.action do |args, options|
    c.verify_arg_count!(args)
    options.default(values: false)

    sol = MrMurano::ServiceConfigs::Tsdb.new
    ret = sol.listTags
    # TODO: handle looping if :next != nil

    if options.values
      sol.outf(ret[:tags]) do |dd, ios|
        data = {}
        data[:headers] = dd.keys
        data[:rows] = dd.keys.map { |k| dd[k] }
        len = data[:rows].map(&:length).max
        data[:rows].each { |r| r.fill(nil, r.length, len - r.length) }
        data[:rows] = data[:rows].transpose
        sol.tabularize(data, ios)
      end
    else
      sol.outf ret[:tags].keys
    end
  end
end

command 'tsdb list metrics' do |c|
  c.syntax = %(murano tsdb list metrics)
  c.summary = %(List metrics)
  c.description = %(
List metrics.
  ).strip

  c.action do |args, _options|
    c.verify_arg_count!(args)
    sol = MrMurano::ServiceConfigs::Tsdb.new
    ret = sol.listMetrics
    # TODO: handle looping if :next != nil
    sol.outf ret[:metrics]
  end
end


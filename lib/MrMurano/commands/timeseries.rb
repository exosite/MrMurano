# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

require 'csv'
require 'MrMurano/ReCommander'
require 'MrMurano/Solution-ServiceConfig'

module MrMurano
  class Timeseries < ServiceConfig
    def initialize(api_id=nil)
      # FIXME/2017-07-03: What soln types have timeseries?
      @solntype = 'application.id'
      super
      @service_name = 'timeseries'
    end

    def query(query)
      call(:query, :post, q: query)
    end

    def write(writestr)
      call(:write, :post, query: writestr)
    end

    def command(cmd)
      call(:command, :post, q: cmd)
    end
  end
end

command :timeseries do |c|
  c.syntax = %(murano timeseries)
  c.summary = %(About Timeseries)
  c.description = %(
These commands are deprecated.

The timeseries sub-commands let you interact directly with the Timeseries
instance in a solution. This allows for easier debugging, being able to
quickly try out different queries or write test data.
  ).strip
  c.subcmdgrouphelp = true

  c.action do |_args, _options|
    ::Commander::UI.enable_paging unless $cfg['tool.no-page']
    say MrMurano::SubCmdGroupHelp.new(c).get_help
  end
end

command 'timeseries query' do |c|
  c.syntax = %(murano timeseries query <query string>)
  c.summary = %(Query the timeseries database)
  c.description = %(
This command is deprecated.

Query the timeseries database.
  ).strip
  c.option '-o', '--output FILE', %(Download to file instead of STDOUT)
  c.option '--[no-]json', %(Display results as raw json)
  c.option '--[no-]csv', %(Display results as CSV)

  c.action do |args, options|
    # SKIP: c.verify_arg_count!(args)
    options.defalts json: false, csv: false
    sol = MrMurano::Timeseries.new
    ret = sol.query args.join(' ')

    $cfg['tool.outformat'] = 'json' if options.json
    $cfg['tool.outformat'] = 'best csv' if options.csv

    io = File.open(options.output, 'w') if options.output
    sol.outf(ret, io) do |_dd, ios|
      (ret[:results] || []).each do |res|
        (res[:series] || []).each do |ser|
          sol.tabularize(
            {
              title: ser[:name],
              headers: ser[:columns],
              rows: ser[:values],
            },
            ios
          )
        end
      end
    end
    io.close unless io.nil?
  end
end
alias_command 'tsq', 'timeseries query'

command 'timeseries write' do |c|
  c.syntax = %(murano timeseries <write string>)
  c.summary = %(Write data into the timeseries database)
  c.description = %(
This command is deprecated.

Write data into the timeseries database.
  ).strip
  c.option '--[no-]json', %(Display results as raw json)
  c.action do |args, options|
    c.verify_arg_count!(args)
    options.defalts(json: false)
    $cfg['tool.outformat'] = 'json' if options.json
    sol = MrMurano::Timeseries.new
    ret = sol.write args.join(' ')
    sol.outf ret
  end
end
alias_command 'tsw', 'timeseries write'

command 'timeseries command' do |c|
  c.syntax = %(murano timeseries command <db command>)
  c.summary = %(Execute a non-query command in the database)
  c.description = %(
This command is deprecated.

Execute a non-query command in the database.
  ).strip
  c.option '--[no-]json', %(Display results as raw json)
  c.action do |args, options|
    # SKIP: c.verify_arg_count!(args)
    options.defalts(json: false)
    $cfg['tool.outformat'] = 'json' if options.json
    sol = MrMurano::Timeseries.new
    ret = sol.command args.join(' ')
    sol.outf ret
  end
end


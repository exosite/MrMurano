# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

require 'MrMurano/ReCommander'
require 'MrMurano/Solution-ServiceConfig'

module MrMurano
  class Postgresql < ServiceConfig
    def initialize(api_id=nil)
      # FIXME/2017-07-03: What soln types have PSQLs?
      @solntype = 'application.id'
      super
      @service_name = 'postgresql'
    end

    def query(query, params=nil)
      aqr = { sql: query }
      aqr[:parameters] = params unless params.nil?
      call(:query, :post, aqr)
    end

    def queries(query, params=nil)
      aqr = { sql: query }
      aqr[:parameters] = params unless params.nil?
      call(:queries, :post, aqr)
    end
  end
end

command :postgresql do |c|
  c.syntax = %(murano postgresql <SQL Commands>)
  c.summary = %(Query the relational database)
  c.description = %(
Query the relational database.

Queries can include $# escapes that are filled from the --param option.
  ).strip

  c.option '--param LIST', Array, %(Values to fill $# with)
  c.option '-f', '--file FILE', %(File of SQL commands)
  c.option '-o', '--output FILE', %(Download to file instead of STDOUT)

  c.example %(murano postgresql 'select * from bob'), %(Run a SQL command)
  c.example(
    %(murano postgresql 'select * from prices' -c outformat=csv -o prices.csv),
    %(Download all values in prices to a CSV file.)
  )
  c.example(
    %(murano postgresql 'INSERT INTO prices (price, item) VALUES ($1,$2)' --param 1.24,Food),
    %(Insert using parameters.)
  )
  c.example %(murano postgresql -f cmds.sql), %(Run multiple commands from a file)

  c.action do |args, options|
    # SKIP: c.verify_arg_count!(args)

    pg = MrMurano::Postgresql.new
    if options.file
      sqls = File.read(options.file)
      ret = pg.queries(sqls, options.param)
    else
      ret = pg.query(args.join(' '), options.param)
    end

    exit 1 if ret.nil?
    unless ret[:error].nil?
      pg.error "Returned error: #{ret[:error]}"
      exit 1
    end

    io = nil
    io = File.open(options.output, 'w') if options.output

    pg.outf(ret, io) do |dd, ios|
      dd = dd[:result]
      # Look for date cells and pretty them. (a Hash with specific fields)
      # All others, call to_s
      rows = dd[:rows].map do |row|
        row.map do |cell|
          if cell.is_a?(Hash) && cell.keys.sort == %i[day hour min month sec usec year]
            t = Time.gm(
              cell[:year], cell[:month], cell[:day], cell[:hour], cell[:min], cell[:sec], cell[:usec]
            )
            t.getlocal.strftime('%F %T.%6N %z')
          else
            cell.to_s
          end
        end
      end
      pg.tabularize(
        {
          headers: dd[:columns],
          rows: rows,
        },
        ios
      )
    end
    io.close unless io.nil?
  end
end

command 'postgresql migrate' do |c|
  c.syntax = %(murano postgresql migrate (up|down) [<level>])
  c.summary = %(Run database migration scripts.)
  c.description = %(
Run database migration scripts.

The names of the script files must be in the "<level>-<name>-<up|down>.sql"
format. Each file is a series of Postgres SQL commands.

The current version of the migrations (last <level> ran) will be stored in an
extra table in your database. (__murano_cli__.migrate_version)
  ).strip

  c.option '--dir DIR', %(Directory where migrations live)

  c.example %(murano postgresql migrate up), %(Run migrations up to largest version.)
  c.example %(murano postgresql migrate up 2), %(Run migrations up to version 2.)
  c.example %(murano postgresql migrate down 1), %(Run migrations down to version 1.)
  c.example %(murano postgresql migrate down 0), %(Run migrations down to version 0.)

  c.action do |args, options|
    c.verify_arg_count!(args, 2, ['Missing direction'])
    options.default(
      dir: File.join($cfg['location.base'], ($cfg['postgresql.migrations_dir'] || '')),
    )

    pg = MrMurano::Postgresql.new

    direction = args.shift
    if direction =~ /down/i
      direction = 'down'
    elsif direction =~ /up/i
      direction = 'up'
    else
      pg.error "Unrecognized direction: #{MrMurano::Verbose.fancy_ticks(direction)}"
      exit 1
    end

    want_version = args.first

    # get current version of DB.
    ret = pg.queries %(
      CREATE SCHEMA IF NOT EXISTS __murano_cli__;
      CREATE TABLE IF NOT EXISTS __murano_cli__.migrate_version (version integer);
      SELECT version FROM __murano_cli__.migrate_version ORDER BY version DESC;
    ).gsub(/^\s+/, '')
    unless ret[:error].nil?
      pp ret
      exit 1
    end
    pg.debug "create/select: #{ret}"
    current_version = (((((ret[:result] || []).last || {})[:rows] || []).first || []).first || 0).to_i

    # Get migrations
    migrations = Dir[File.join(options.dir, "*-#{direction}.sql")].sort
    if migrations.empty?
      pg.error 'No migrations to run.'
      exit 1
    end
    migrations.reverse! if direction == 'down'

    want_version, = File.basename(migrations.last).split('-') if want_version.nil?
    want_version = want_version.to_i
    pg.verbose "Will migrate from version #{current_version} to #{want_version}"
    if direction == 'down'
      if want_version >= current_version
        say 'Nothing to do.'
        exit 0
      end
    elsif want_version <= current_version
      say 'Nothing to do.'
      exit 0
    end

    pg.debug "Migrations before: #{migrations}"
    # Select migrations between current and desired
    migrations.select! do |m|
      mvrs, = File.basename(m).split('-')
      mvrs = mvrs.to_i
      if direction == 'down'
        mvrs <= current_version && mvrs > want_version
      else
        mvrs > current_version && mvrs <= want_version
      end
    end
    pg.debug "Migrations after: #{migrations}"

    # Run migrations.
    migrations.each do |m|
      mvrs, = File.basename(m).split('-')
      pg.verbose "Running migration: #{File.basename(m)}"
      next if $cfg['tool.dry']
      pg.query 'BEGIN;'
      ret = pg.queries File.read(m)
      if !ret[:error].nil?
        pg.query 'ROLLBACK;'
        pg.error "Migrations failed at level #{mvrs}"
        pg.error "Because: #{ret[:error]}"
        exit 5
      elsif direction == 'down'
        pg.queries %(
          DELETE FROM __murano_cli__.migrate_version WHERE version = #{mvrs};
          COMMIT;
        ).gsub(/^\s+/, '')
      else
        pg.queries %(
          INSERT INTO __murano_cli__.migrate_version values (#{mvrs});
          COMMIT;
        ).gsub(/^\s+/, '')
      end
    end
  end
end


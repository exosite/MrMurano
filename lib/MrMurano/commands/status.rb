# Last Modified: 2017.07.26 /coding: utf-8
# frozen_string_literal: true

# Copyright © 2016-2017 Exosite LLC.
# License: MIT. See LICENSE.txt.
#  vim:tw=0:ts=2:sw=2:et:ai

require 'MrMurano/verbosing'
require 'MrMurano/SyncRoot'

command :status do |c|
  c.syntax = %(murano status [options] [filters])
  c.summary = %(Get the status of files)
  c.description = %(
Get the status of files.

Compares the local project against what is up in Murano, showing a summary
of what things are new or changed.

When --diff is passed, for items that have changes, the remote item and
local item are passed to a diff tool and that output is included.

The diff tool and options to it can be set with the config key 'diff.cmd'.

Filters allow for selecting a subset of items to check based on patterns.

File glob filters can be used to select local files. The glob is compared
with the full file path.

Each item type also supports specific filters. These always start with #.
Endpoints can be selected with a "#<method>#<path glob>" pattern.
  ).gsub(/^ +/, '').strip
  c.option '--all', 'Check everything'

  # Load options to control which things to status
  MrMurano::SyncRoot.instance.each_option do |s, l, d|
    c.option s, l, d
  end

  c.option '--[no-]asdown', %(Report as if syncdown instead of syncup)
  c.option '--[no-]asup', %(Report as if syncup instead of syncdown (default: true))
  c.option '--[no-]diff', %(For modified items, show a diff)
  c.option '--[no-]grouped', %(Group all adds, deletes, and mods together)
  c.option '--[no-]showall', %(List unchanged as well)

  c.action do |args, options|
    options.default(
      asdown: nil,
      asup: nil,
      diff: false,
      grouped: true,
      showall: false,
      # delete/create/update are not options the user can specify
      # for status or diff commands; but the SyncUpDown class expects
      # them.
      delete: true,
      create: true,
      update: true,
    )

    def fmtr(item)
      if item.key? :local_path
        lp = item[:local_path].relative_path_from(Pathname.pwd).to_s
        return "#{lp}:#{item[:line]}" if item.key?(:line) && item[:line] > 0
        lp
      else
        id = item[:synckey]
        id += " (#{item[:pp_desc]})" unless item[:pp_desc].to_s.empty? || item[:pp_desc] == item[:synckey]
        id
      end
    end

    def pretty(ret, options)
      pretty_group_header(ret[:toadd], 'Only on local machine', 'new locally', options.grouped)
      ret[:toadd].each { |item| say " + #{item[:pp_type]}  #{highlight_chg(fmtr(item))}" }

      pretty_group_header(ret[:todel], 'Only on remote server', 'new remotely', options.grouped)
      ret[:todel].each { |item| say " - #{item[:pp_type]}  #{highlight_del(fmtr(item))}" }

      pretty_group_header(ret[:tomod], 'Items that differ', 'that differs', options.grouped)
      ret[:tomod].each do |item|
        say " M #{item[:pp_type]}  #{highlight_chg(fmtr(item))}"
        say item[:diff] if options.diff
      end

      unless ret[:skipd].empty?
        pretty_group_header(ret[:skipd], 'Items without a solution', 'without a solution', options.grouped)
        ret[:skipd].each { |item| say " - #{item[:pp_type]}  #{highlight_del(fmtr(item))}" }
      end

      return unless options.showall
      say 'Unchanged:' if options.grouped
      ret[:unchg].each { |item| say "   #{item[:pp_type]}  #{fmtr(item)}" }
    end

    def pretty_group_header(group, header_any, header_empty, grouped)
      return unless grouped
      if !group.empty?
        say "#{header_any}:"
      else
        say "Nothing #{header_empty}"
      end
    end

    def highlight_chg(msg)
      Rainbow(msg).green.bright
    end

    def highlight_del(msg)
      Rainbow(msg).red.bright
    end

    @grouped = { toadd: [], todel: [], tomod: [], unchg: [], skipd: [] }
    def gmerge(ret, type, desc, options)
      if options.grouped
        out = @grouped
      else
        out = { toadd: [], todel: [], tomod: [], unchg: [], skipd: [] }
      end

      %i[toadd todel tomod unchg skipd].each do |kind|
        ret[kind].each do |item|
          item = item.to_h
          item[:pp_type] = type
          item[:pp_desc] = desc
          out[kind] << item
        end
      end

      pretty(out, options) unless options.grouped
    end

    # Method code starts here!

    # Check that user doesn't try to asdown and asup, or no-asdown and no-asup.
    if options.asdown.nil? && options.asup.nil?
      options.asdown = false
      options.asup = true
    elsif !options.asdown.nil? && !options.asup.nil?
      unless options.asdown ^ options.asup
        error('Please specify either --asdown or --asup, but not both!')
        exit 1
      end
    elsif options.asdown.nil?
      options.asdown = !options.asup
    elsif options.asup.nil?
      options.asup = !options.asdown
    else
      raise('Unexpected code path.')
    end

    MrMurano::SyncRoot.instance.each_filtered(options.__hash__) do |_name, type, klass, desc|
      MrMurano::Verbose.whirly_msg "Fetching #{desc}..."
      begin
        syncable = klass.new
      rescue MrMurano::ConfigError => err
        MrMurano::Verbose.error "Could not fetch status for #{desc}: #{err}"
      rescue StandardError => _err
        raise
      else
        # Different syncables use different solution types, so if a
        # certain solution doesn't exist, its syncables won't have an sid.
        if syncable.sid?
          ret = syncable.status(options, args)
        else
          ret = { toadd: [], todel: [], tomod: [], unchg: [], skipd: [] }
          ret[:skipd] << { synckey: desc }
        end
        gmerge(ret, type, desc, options)
      end
    end
    MrMurano::Verbose.whirly_stop

    pretty(@grouped, options) if options.grouped
  end
end

alias_command :diff, :status, '--diff', '--no-grouped'


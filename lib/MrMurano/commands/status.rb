# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

require 'inflecto'
require 'pathname'
require 'MrMurano/verbosing'
require 'MrMurano/SyncRoot'

# Load options to control which things to sync
def cmd_option_syncable_pickers(cmd)
  MrMurano::SyncRoot.instance.each_option do |short, long, desc|
    cmd.option short, long, Inflecto.pluralize(desc)
  end
  MrMurano::SyncRoot.instance.each_alias_opt do |long, desc|
    cmd.option long, Inflecto.pluralize(desc)
  end

  cmd.option(
    '--[no-]nesting',
    %(Disable support for arranging Lua modules hierarchically)
  ) do |nestation|
    # This is only called if user specifies switch.
    $cfg['modules.no-nesting'] = !nestation
  end
end

def cmd_defaults_syncable_pickers(options)
  # Weird. The options is a Commander::Command::Options object, but
  # options.class says nil! Also, you cannot index properties or
  # even options.send('opt'). But we can just twiddle the raw table.
  table = options.__hash__
  MrMurano::SyncRoot.instance.each_alias_sym do |pseudo, pseudo_sym, name, name_sym|
    unless table[pseudo_sym].nil?
      if table[name_sym].nil?
        table[name_sym] = table[pseudo_sym]
      elsif table[name_sym] != table[pseudo_sym]
        MrMurano::Verbose.warning("Ignoring --#{pseudo} because --#{name} also specified")
      end
    end
  end
end

command :status do |c|
  c.syntax = %(murano status [--options] [filters])
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

  # Add flag: --type [application|product|all].
  cmd_add_solntype_pickers(c)

  c.option '--all', 'Check everything'
  c.option '--[no-]asdown', %(Report as if syncdown instead of syncup)
  c.option '--[no-]asup', %(Report as if syncup instead of syncdown (default: true))
  c.option '--[no-]diff', %(For modified items, show a diff)
  c.option '--[no-]grouped', %(Group all adds, deletes, and mods together)
  c.option '--[no-]show-all', %(List unchanged as well)
  c.option '--[no-]show-type', %(Include type of item)
  cmd_option_syncable_pickers(c)

  c.action do |args, options|
    # SKIP: c.verify_arg_count!(args)
    options.default(
      all: nil,
      asdown: nil,
      asup: nil,
      diff: false,
      grouped: true,
      show_all: false,
      show_type: false,
      # delete/create/update are not options the user can specify
      # for status or diff commands; but the SyncUpDown class expects
      # them.
      delete: true,
      create: true,
      update: true,
    )
    cmd_defaults_solntype_pickers(options)
    cmd_defaults_syncable_pickers(options)

    def fmtr(item, options)
      if item.key?(:local_path)
        desc = item[:local_path].relative_path_from(Pathname.pwd).to_s
        desc = "#{desc}:#{item[:line]}" if item.key?(:line) && item[:line] > 0
      else
        desc = item[:synckey]
      end
      return desc unless options.show_type
      unless item[:pp_desc].to_s.empty? || item[:pp_desc] == item[:synckey]
        desc += " (#{item[:pp_desc]})"
      end
      # NOTE: This path is the endpoint path.
      desc += " [#{item[:method]} #{item[:path]}]" if item[:method] && item[:path]
      desc
    end

    def interject(msg)
      MrMurano::Verbose.whirly_interject { say msg }
    end

    def pretty(ret, options)
      pretty_group_header(
        ret[:toadd], 'Only on local machine', 'new locally', options.grouped
      )
      ret[:toadd].each do |item|
        interject " + #{item[:pp_type]}  #{highlight_chg(fmtr(item, options))}"
        pretty_diff(item, options)
      end

      pretty_group_header(
        ret[:todel], 'Only on remote server', 'new remotely', options.grouped
      )
      ret[:todel].each do |item|
        interject " - #{item[:pp_type]}  #{highlight_del(fmtr(item, options))}"
        pretty_diff(item, options)
      end

      pretty_group_header(
        ret[:tomod], 'Items that differ', 'that differs', options.grouped
      )
      ret[:tomod].each do |item|
        interject " M #{item[:pp_type]}  #{highlight_chg(fmtr(item, options))}"
        interject item[:diff] if options.diff
      end

      unless ret[:skipd].empty?
        pretty_group_header(
          ret[:skipd], 'Items without a solution', 'without a solution', options.grouped
        )
        ret[:skipd].each do |item|
          interject " - #{item[:pp_type]}  #{highlight_del(fmtr(item, options))}"
        end
      end

      unless ret[:clash].empty?
        pretty_group_header(
          ret[:clash], 'Conflicting items', 'in conflict', options.grouped
        )
        ret[:clash].each do |item|
          abbrev = $cfg['tool.ascii'] && 'x' || '✗'
          interject " #{abbrev} #{item[:pp_type]}  #{highlight_del(fmtr(item, options))}"
        end
      end

      return unless options.show_all
      interject 'Unchanged:' if options.grouped
      ret[:unchg].each { |item| interject "   #{item[:pp_type]}  #{fmtr(item, options)}" }
    end

    def pretty_group_header(group, header_any, header_empty, grouped)
      return unless grouped
      if !group.empty?
        interject "#{header_any}:"
      else
        interject "Nothing #{header_empty}"
      end
    end

    def pretty_diff(item, options)
      return unless options.diff && $cfg['tool.verbose'] && !item[:diff].empty?
      interject item[:diff]
    end

    def highlight_chg(msg)
      Rainbow(msg).green.bright
    end

    def highlight_del(msg)
      Rainbow(msg).red.bright
    end

    @grouped = { toadd: [], todel: [], tomod: [], unchg: [], skipd: [], clash: [] }
    def gmerge(ret, type, desc, options)
      if options.grouped
        out = @grouped
      else
        out = { toadd: [], todel: [], tomod: [], unchg: [], skipd: [], clash: [] }
      end

      %i[toadd todel tomod unchg skipd clash].each do |kind|
        ret[kind].each do |item|
          item = item.to_h
          item[:pp_type] = type
          item[:pp_desc] = desc
          out[kind] << item
        end
      end

      pretty(out, options) unless options.grouped
    end

    # *** Method code starts here ***

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
      MrMurano::Verbose.whirly_msg "Fetching #{Inflecto.pluralize(desc)}..."
      begin
        syncable = klass.new
      rescue MrMurano::ConfigError => err
        MrMurano::Verbose.error "Could not fetch status for #{desc}: #{err}"
      rescue StandardError => _err
        raise
      else
        ret = syncable.status(options, args)
        gmerge(ret, type, desc, options)
      end
    end
    MrMurano::Verbose.whirly_stop

    pretty(@grouped, options) if options.grouped
  end
end
alias_command 'diff', 'status', '--diff', '--no-grouped'
alias_command 'diff application', 'status', '--diff', '--no-grouped', '--type', 'application'
alias_command 'diff product', 'status', '--diff', '--no-grouped', '--type', 'product'
alias_command 'application diff', 'status', '--diff', '--no-grouped', '--type', 'application'
alias_command 'product diff', 'status', '--diff', '--no-grouped', '--type', 'product'


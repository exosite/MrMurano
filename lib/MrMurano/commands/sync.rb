# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

require 'MrMurano/verbosing'
require 'MrMurano/SyncRoot'
require 'MrMurano/commands/status'

def sync_add_options(c, locale)
  c.option '--[no-]delete', %(Don't delete things from #{locale})
  c.option '--[no-]create', %(Don't create things on #{locale})
  c.option '--[no-]update', %(Don't update things on #{locale})
  c.option '--ignore-errors', %(Don't die on sync errors)
end

def syncdown_files(options, args=nil)
  args = [] if args.nil?
  num_synced = 0
  MrMurano::SyncRoot.instance.each_filtered(options) do |_name, _type, klass, desc|
    MrMurano::Verbose.whirly_msg "Syncing #{Inflecto.pluralize(desc)}..."
    sol = klass.new
    num_synced += sol.syncdown(options, args)
  end
  MrMurano::Verbose.whirly_stop
  num_synced
end

command :syncdown do |c|
  c.syntax = %(murano syncdown [--options] [filters])
  c.summary = %(Sync project down from Murano)
  c.description = %(
Sync project down from Murano.
  ).strip

  # Add flag: --type [application|product|all].
  cmd_add_solntype_pickers(c)

  c.option '--all', 'Sync everything'
  cmd_option_syncable_pickers(c)
  sync_add_options(c, 'local machine')

  c.example %(Make local be like what is on the server), %(murano syncdown --all)
  c.example %(Pull down new things, but don't delete or modify anything), %(murano syncdown --all --no-delete --no-update)
  c.example %(Only Pull new static files), %(murano syncdown --files --no-delete --no-update)

  c.action do |args, options|
    # SKIP: c.verify_arg_count!(args)
    options.default(delete: true, create: true, update: true)
    cmd_defaults_solntype_pickers(options)
    cmd_defaults_syncable_pickers(options)
    syncdown_files(options.__hash__, args)
  end
end
alias_command 'pull', 'syncdown', '--no-delete'
alias_command 'pull application', 'syncdown', '--no-delete', '--type', 'application'
alias_command 'pull product', 'syncdown', '--no-delete', '--type', 'product'
alias_command 'application pull', 'syncdown', '--no-delete', '--type', 'application'
alias_command 'product pull', 'syncdown', '--no-delete', '--type', 'product'

command :syncup do |c|
  c.syntax = %(murano syncup [--options] [filters])
  c.summary = %(Sync project up into Murano)
  c.description = %(
Sync project up into Murano.
  ).strip

  # Add flag: --type [application|product|all].
  cmd_add_solntype_pickers(c)

  c.option '--all', 'Sync everything'
  cmd_option_syncable_pickers(c)
  sync_add_options(c, 'server')

  c.example %(Deploy project to server), %(murano syncup --all)
  c.example %(Update static files), %(murano syncup --files)
  c.example %(Only add or modify static files), %(murano syncup --files --no-delete)

  c.action do |args, options|
    # SKIP: c.verify_arg_count!(args)
    options.default(delete: true, create: true, update: true)
    cmd_defaults_solntype_pickers(options)
    cmd_defaults_syncable_pickers(options)
    #MrMurano::Verbose.whirly_start "Syncing solutions..."
    MrMurano::SyncRoot.instance.each_filtered(options.__hash__) do |_name, _type, klass, desc|
      MrMurano::Verbose.whirly_msg "Syncing #{Inflecto.pluralize(desc)}..."
      sol = klass.new
      sol.syncup(options, args)
    end
    MrMurano::Verbose.whirly_stop
  end
end
alias_command 'push', 'syncup', '--no-delete'
alias_command 'push application', 'syncup', '--no-delete', '--type', 'application'
alias_command 'push product', 'syncup', '--no-delete', '--type', 'product'
alias_command 'application push', 'syncup', '--no-delete', '--type', 'application'
alias_command 'product push', 'syncup', '--no-delete', '--type', 'product'


# Last Modified: 2017.07.26 /coding: utf-8
# frozen_string_literal: true

# Copyright © 2016-2017 Exosite LLC.
# License: MIT. See LICENSE.txt.
#  vim:tw=0:ts=2:sw=2:et:ai

require 'MrMurano/verbosing'
require 'MrMurano/SyncRoot'

def sync_add_options(c, locale)
  c.option '--[no-]delete', %(Don't delete things from #{locale})
  c.option '--[no-]create', %(Don't create things on #{locale})
  c.option '--[no-]update', %(Don't update things on #{locale})
end

def syncdown_files(options, args=nil)
  args = [] if args.nil?
  num_synced = 0
  MrMurano::SyncRoot.instance.each_filtered(options) do |_name, _type, klass, desc|
    MrMurano::Verbose.whirly_msg "Syncing #{desc}..."
    sol = klass.new
    num_synced += sol.syncdown(options, args)
  end
  MrMurano::Verbose.whirly_stop
  num_synced
end

command :syncdown do |c|
  c.syntax = %(murano syncdown [options] [filters])
  c.summary = %(Sync project down from Murano)
  c.description = %(
Sync project down from Murano.
  ).strip
  c.option '--all', 'Sync everything'

  # Load options to control which things to sync
  MrMurano::SyncRoot.instance.each_option do |s, l, d|
    c.option s, l, d
  end

  sync_add_options(c, 'local machine')

  c.example %(Make local be like what is on the server), %(murano syncdown --all)
  c.example %(Pull down new things, but don't delete or modify anything), %(murano syncdown --all --no-delete --no-update)
  c.example %(Only Pull new static files), %(murano syncdown --files --no-delete --no-update)

  c.action do |args, options|
    options.default delete: true, create: true, update: true

    syncdown_files(options.__hash__, args)
  end
end
alias_command :pull, :syncdown, '--no-delete'

command :syncup do |c|
  c.syntax = %(murano syncup [options] [filters])
  c.summary = %(Sync project up into Murano)
  c.description = %(
Sync project up into Murano.
  ).strip
  c.option '--all', 'Sync everything'

  # Load options to control which things to sync
  MrMurano::SyncRoot.instance.each_option do |s, l, d|
    c.option s, l, d
  end

  sync_add_options(c, 'server')

  c.example %(Deploy project to server), %(murano syncup --all)
  c.example %(Update static files), %(murano syncup --files)
  c.example %(Only add or modify static files), %(murano syncup --files --no-delete)

  c.action do |args, options|
    options.default delete: true, create: true, update: true

    #MrMurano::Verbose.whirly_start "Syncing solutions..."
    MrMurano::SyncRoot.instance.each_filtered(options.__hash__) do |_name, _type, klass, desc|
      MrMurano::Verbose.whirly_msg "Syncing #{desc}..."
      sol = klass.new
      sol.syncup(options, args)
    end
    MrMurano::Verbose.whirly_stop
  end
end
alias_command :push, :syncup, '--no-delete'


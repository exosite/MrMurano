# Last Modified: 2017.07.25 /coding: utf-8
# frozen_string_literal: true

# Copyright © 2016-2017 Exosite LLC.
# License: MIT. See LICENSE.txt.
#  vim:tw=0:ts=2:sw=2:et:ai

command :config do |c|
  c.syntax = %(murano config [options] <key> [<new value>])
  c.summary = %(Get and set options)
  c.description = %(
Get, set, or query config options.

All config options are in a 'section.key' format.

There is also a layer of scopes that the keys can be saved in.

If section is left out, then key is assumed to be in the 'tool' section.
  ).strip

  c.example %(
    View the combined config
  ).strip, 'murano config --dump'

  c.example %(
    View the config and path for each config file
  ).strip, 'murano config --locations'

  c.example %(
    Query a value
  ).strip, 'murano config application.id'

  c.example %(
    Set a new value, which writes to the project config file
  ).strip, 'murano config application.id XXXXXXXX'

  c.example %(
    Set a new valuem, and write it to the user config file
  ).strip, 'murano config --user user.name my@email.address'

  c.example %(
    Unset a value. If the value is set in multiple config files,
    # this unsets it from the outermost config file and unmasks
    # a value set in a lower scope
  ).strip, 'murano config diff.cmd --unset'

  c.option '--user', 'Use only the config file in $HOME (.mrmuranorc)'
  c.option '--project', 'Use only the config file in the project (.mrmuranorc)'
  c.option '--env', 'Use only the config file from $MR_CONFIGFILE'
  c.option '--specified', 'Use only the config file from the --config option.'

  c.option '--unset', 'Remove key from config file.'
  c.option '--dump', 'Dump the current combined view of the config'
  c.option '--locations', 'List the locations of all known configs'

  c.project_not_required = true

  c.action do |args, options|
    c.verify_arg_count!(args, 2)
    options.default(
      user: false,
      project: false,
      env: false,
      specified: false,
      unset: false,
      dump: false,
      locations: false,
    )

    if options.dump
      puts $cfg.dump
    elsif options.locations
      puts 'This list is ordered. The first value found for a key is the value used.'
      puts $cfg.locations
    elsif args.count.zero?
      say_error 'Need a config key'
    else
      scope = get_scope_from_options(options)
      if args.count == 1 && !options.unset
        # For read, if no scopes, than all. Otherwise just those specified
        scopes = []
        scopes << scope unless scope.nil?
        scopes = MrMurano::Config::CFG_SCOPES if scopes.empty?
        say $cfg.get(args[0], scopes)
      else
        # For write, if scope is specified, only write to that scope.
        scope = :project if scope.nil?
        args[1] = nil if options.unset
        $cfg.set(args[0], args[1], scope)
      end
    end
  end

  def get_scope_from_options(options)
    num_scopes = verify_scope_options!(options)
    return nil if num_scopes.zero?
    scope = nil
    scope = :user if options.user
    scope = :project if options.project
    scope = :env if options.env
    scope = :specified if options.specified
    scope
  end

  def verify_scope_options!(options)
    num_scopes = 0
    num_scopes += 1 if options.user
    num_scopes += 1 if options.project
    num_scopes += 1 if options.env
    num_scopes += 1 if options.specified
    return num_scopes unless num_scopes > 1
    MrMurano::Verbose.error(
      'Ambiguous: Please specify only one of --user, --project, --env, or --specified'
    )
    exit 1
  end
end


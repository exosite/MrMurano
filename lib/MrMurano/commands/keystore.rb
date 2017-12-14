# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

require 'MrMurano/Keystore'
require 'MrMurano/ReCommander'
require 'MrMurano/Solution-ServiceConfig'

command :keystore do |c|
  c.syntax = %(murano keystore)
  c.summary = %(About Keystore)
  c.description = %(
The Keystore sub-commands let you interact directly with the Keystore instance
in a solution. This allows for easier debugging, being able to quickly get and
set data. As well as calling any of the other supported REDIS commands.
  ).strip
  c.project_not_required = true
  c.subcmdgrouphelp = true

  c.action do |_args, _options|
    ::Commander::UI.enable_paging unless $cfg['tool.no-page']
    say MrMurano::SubCmdGroupHelp.new(c).get_help
  end
end

command 'keystore clearAll' do |c|
  c.syntax = %(murano keystore clearAll)
  c.summary = %(Delete all keys in the keystore)
  c.description = %(
Delete all keys in the keystore.
  ).strip

  c.action do |args, _options|
    c.verify_arg_count!(args)
    sol = MrMurano::Keystore.new
    sol.clearall
  end
end

command 'keystore info' do |c|
  c.syntax = %(murano keystore info)
  c.summary = %(Show info about the Keystore)
  c.description = %(
Show info about the Keystore.
  ).strip

  c.action do |args, _options|
    c.verify_arg_count!(args)
    sol = MrMurano::Keystore.new
    sol.outf sol.keyinfo
  end
end

command 'keystore list' do |c|
  c.syntax = %(murano keystore list)
  c.summary = %(List all of the keys in the Keystore)
  c.description = %(
List all of the keys in the Keystore.
  ).strip

  c.action do |args, _options|
    c.verify_arg_count!(args)
    sol = MrMurano::Keystore.new
    # FIXME/2017-06-14: This outputs nothing if not list, unlike other
    #   list commands that say, e.g., "No solutions found"
    sol.outf sol.listkeys
  end
end

command 'keystore get' do |c|
  c.syntax = %(murano keystore get <key>)
  c.summary = %(Get the value of a key in the Keystore)
  c.description = %(
Get the value of a key in the Keystore.
  ).strip

  c.action do |args, _options|
    c.verify_arg_count!(args, 1, ['Missing key'])
    sol = MrMurano::Keystore.new
    ret = sol.getkey(args[0])
    sol.outf ret
  end
end

command 'keystore set' do |c|
  c.syntax = %(murano keystore set <key> <value...>)
  c.summary = %(Set the value of a key in the Keystore)
  c.description = %(
Set the value of a key in the Keystore.
  ).strip

  c.action do |args, _options|
    c.verify_arg_count!(args, nil, ['Missing key', 'Missing value(s)'])
    sol = MrMurano::Keystore.new
    sol.setkey(args[0], args[1..-1].join(' '))
  end
end

command 'keystore delete' do |c|
  c.syntax = %(murano keystore delete <key>)
  c.summary = %(Delete a key from the Keystore)
  c.description = %(
Delete a key from the Keystore.
  ).strip

  # MAYBE?/2017-08-16: Verify on delete.
  #c.option('-y', '--[no-]yes', %(Answer "yes" to all prompts and run non-interactively))

  c.action do |args, _options|
    c.verify_arg_count!(args, 1, ['Missing key'])
    sol = MrMurano::Keystore.new
    sol.delkey(args[0])
  end
end
alias_command 'keystore rm', 'keystore delete'
alias_command 'keystore del', 'keystore delete'

command 'keystore command' do |c|
  c.syntax = %(murano keystore command <command> <key> [<args...>])
  c.summary = %(Call some Redis commands in the Keystore)
  c.description = %(
Call some Redis commands in the Keystore.

Only a subset of all Redis commands is supported.

For current list, see:

  http://docs.exosite.com/murano/services/keystore/#command
  ).strip
  c.example %(murano keystore command lpush mykey myvalue), %(Push a value onto list)
  c.example %(murano keystore command lpush mykey A B C), %(Push three values onto list)
  c.example %(murano keystore command lrem mykey 0 B), %(Remove all B values from list)

  c.action do |args, _options|
    #c.verify_arg_count!(args, nil, ['Missing command', 'Missing key', 'Missing value(s)'])
    c.verify_arg_count!(args, nil, ['Missing command', 'Missing key'])
    sol = MrMurano::Keystore.new
    ret = sol.command(args[1], args[0], args[2..-1])
    if ret.key?(:value)
      sol.outf ret[:value]
    else
      sol.error "#{ret[:code]}: #{ret.message}"
      sol.outf ret[:error] if $cfg['tool.debug'] && ret.key?(:error)
    end
  end
end
alias_command 'keystore cmd', 'keystore command'

# A bunch of common REDIS commands that are suported in Murano
alias_command 'keystore lpush', 'keystore command', 'lpush'
alias_command 'keystore lindex', 'keystore command', 'lindex'
alias_command 'keystore llen', 'keystore command', 'llen'
alias_command 'keystore linsert', 'keystore command', 'linsert'
alias_command 'keystore lrange', 'keystore command', 'lrange'
alias_command 'keystore lrem', 'keystore command', 'lrem'
alias_command 'keystore lset', 'keystore command', 'lset'
alias_command 'keystore ltrim', 'keystore command', 'ltrim'
alias_command 'keystore rpop', 'keystore command', 'rpop'
alias_command 'keystore rpush', 'keystore command', 'rpush'
alias_command 'keystore sadd', 'keystore command', 'sadd'
alias_command 'keystore srem', 'keystore command', 'srem'
alias_command 'keystore scard', 'keystore command', 'scard'
alias_command 'keystore smembers', 'keystore command', 'smembers'
alias_command 'keystore spop', 'keystore command', 'spop'


# Last Modified: 2017.07.25 /coding: utf-8
# frozen_string_literal: true

# Copyright © 2016-2017 Exosite LLC.
# License: MIT. See LICENSE.txt.
#  vim:tw=0:ts=2:sw=2:et:ai

command :password do |c|
  c.syntax = %(murano password)
  c.summary = %(About password commands)
  c.description = %(
Commands for working with usernames and passwords.
  ).strip
  c.project_not_required = true
  c.action do |_args, _options|
    ::Commander::UI.enable_paging
    say MrMurano::SubCmdGroupHelp.new(c).get_help
  end
end
alias_command 'password current', :config, 'user.name'

command 'password list' do |c|
  c.syntax = %(murano password list)
  c.summary = %(List the usernames with saved passwords)
  c.description = %(
List the usernames and hosts that have been saved.
  ).strip
  c.project_not_required = true

  c.action do |args, _options|
    c.verify_arg_count!(args)

    psd = MrMurano::Passwords.new
    psd.load

    ret = psd.list
    psd.outf(ret) do |dd, ios|
      rows = []
      dd.each_pair do |key, value|
        value.each { |v| rows << [key, v] }
      end
      psd.tabularize(
        { rows: rows, headers: %i[Host Username] },
        ios
      )
    end
  end
end
alias_command 'passwords list', 'password list'

command 'password set' do |c|
  c.syntax = %(murano password set <username> [<host>])
  c.summary = %(Set password for username)
  c.description = %(
Set password for username.
  ).strip
  c.option '--password PASSWORD', String, %(The password to use)
  c.option '--from_env', %(Use password in MURANO_PASSWORD)
  c.project_not_required = true

  c.action do |args, options|
    c.verify_arg_count!(args, 2, ['Missing username'])

    username = args.shift
    host = args.shift
    host = $cfg['net.host'] if host.nil?

    psd = MrMurano::Passwords.new
    psd.load
    if options.password
      pws = options.password
    elsif options.from_env
      pws = ENV['MURANO_PASSWORD']
    else
      pws = ask('Password:  ') { |q| q.echo = '*' }
    end
    psd.set(host, username, pws)
    psd.save
  end
end

command 'password delete' do |c|
  c.syntax = %(murano password delete <username> [<host>])
  c.summary = %(Delete password for username)
  c.description = %(
Delete password for username.
  ).strip
  c.project_not_required = true

  c.action do |args, _options|
    psd = MrMurano::Passwords.new
    psd.load

    if args.count < 1
      psd.error 'Missing username'
      exit 1
    end

    username = args.shift
    host = args.shift
    host = $cfg['net.host'] if host.nil?

    psd.remove(host, username)
    psd.save
  end
end


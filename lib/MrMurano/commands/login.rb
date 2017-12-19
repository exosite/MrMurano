# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

require 'MrMurano/Account'
require 'MrMurano/Config'
require 'MrMurano/ReCommander'

command 'login' do |c|
  c.syntax = %(murano login)
  c.summary = %(Log into Murano)
  c.description = %(
Log into Murano.

If you are having trouble logging in, try deleting the saved password first:

  murano password delete <username>
  ).strip
  c.option '--show-token', %(Shows the API token)
  c.project_not_required = true
  c.prompt_if_logged_off = true

  c.action do |args, options|
    c.verify_arg_count!(args)
    tok = MrMurano::Account.instance.token
    say tok if options.show_token
  end
end

command 'logout' do |c|
  c.syntax = %(murano logout)
  c.summary = %(Log out of Murano)
  c.description = %(
Log out of Murano.

This command will unset the user.name in the user config, and
it will remove that user's password from the password file.

Essentially, this command is the same as:

  murano password delete <username>
  murano password delete <username>/twofactor
  murano config --unset --user user.name
  ).strip
  c.project_not_required = true

  c.option '--token', 'Remove just the two-factor token'

  c.action do |args, options|
    c.verify_arg_count!(args)
    MrMurano::Account.instance.logout(options.token)
  end
end


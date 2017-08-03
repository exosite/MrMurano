# Last Modified: 2017.08.03 /coding: utf-8
# frozen_string_literal: true

# Copyright © 2016-2017 Exosite LLC.
# License: MIT. See LICENSE.txt.
#  vim:tw=0:ts=2:sw=2:et:ai

require 'MrMurano/Account'
require 'MrMurano/Config'

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
  murano config --unset --user user.name
  ).strip
  c.project_not_required = true

  c.action do |args, _options|
    c.verify_arg_count!(args)

    net_host = verify_set('net.host')
    user_name = verify_set('user.name')
    if net_host && user_name
      psd = MrMurano::Passwords.new
      psd.load
      psd.remove(net_host, user_name)
      psd.save
    end

    user_net_host = $cfg.get('net.host', :user)
    user_net_host = $cfg.get('net.host', :defaults) if user_net_host.nil?
    user_user_name = $cfg.get('user.name', :user)
    if (user_net_host == net_host) && (user_user_name == user_name)
      # Only clear user name from the user config if the net.host
      # or user.name did not come from a different config, like the
      # --project config.
      $cfg.set('user.name', nil, :user)
      $cfg.set('business.id', nil, :user)
      $cfg.set('business.name', nil, :user)
    end
  end

  def verify_set(cfg_key)
    cfg_val = $cfg.get(cfg_key)
    if cfg_val.to_s.empty?
      cfg_val = nil
      MrMurano::Verbose.warning("No config key ‘#{cfg_key}’: no password to delete")
    end
    cfg_val
  end
end


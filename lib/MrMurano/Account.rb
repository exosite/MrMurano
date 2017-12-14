# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

require 'json'
require 'net/http'
require 'uri'
require 'yaml'
require 'MrMurano/hash'
require 'MrMurano/http'
require 'MrMurano/verbosing'
require 'MrMurano/Business'
require 'MrMurano/Config'
require 'MrMurano/Passwords'
require 'MrMurano/Solution'

module MrMurano
  class Account
    # The tool only works for a single user. To avoid fetching the
    # token multiple times (and to avoid having to pass an Account
    # object around), we make the class a singleton.
    include Singleton

    include Http
    include Verbose

    def initialize
      @token = nil
      @twofactor_token = nil
    end

    def host
      $cfg['net.host'].to_s
    end

    def user
      $cfg['user.name'].to_s
    end

    def endpoint(path)
      URI($cfg['net.protocol'] + '://' + host + '/api:1/' + path.to_s)
    end

    # ---------------------------------------------------------------------

    LOGIN_ADVICE = %(
Please login using `murano login` or `murano init`.
Or set your password with `murano password set <username>`.
    ).strip
    LOGIN_NOTICE = 'Please login.'

    def login_info
      warned_once = false

      if user.empty?
        prologue = 'No Murano user account found.'
        unless $cfg.prompt_if_logged_off
          MrMurano::Verbose.whirly_stop
          error("#{prologue}\n#{LOGIN_ADVICE}")
          exit 2
        end
        MrMurano::Verbose.whirly_pause
        error("#{prologue} #{LOGIN_NOTICE}")
        warned_once = true
        username = ask('User name: ')
        $cfg.set('user.name', username, :user)
        $project.refresh_user_name
        MrMurano::Verbose.whirly_unpause
      end

      pwd_file = pwd_file_load
      user_pass = pwd_file.get(host, user)
      if user_pass.nil?
        prologue = "No Murano password found for #{user}."
        unless $cfg.prompt_if_logged_off
          MrMurano::Verbose.whirly_stop
          error("#{prologue}\n#{LOGIN_ADVICE}")
          exit 2
        end
        MrMurano::Verbose.whirly_pause
        error(%(#{prologue} #{LOGIN_NOTICE}).strip) unless warned_once
        user_pass = ask('Password: ') { |q| q.echo = '*' }
        pwd_file.set(host, user, user_pass)
        pwd_file.set(host, user + '/twofactor', nil)
        pwd_file.save
        MrMurano::Verbose.whirly_unpause
      else
        @twofactor_token = token_twofactor_lookup(pwd_file)
      end

      {
        email: user,
        password: user_pass,
      }
    end

    def pwd_file_load
      pwd_path = $cfg.file_at('passwords', :user)
      pwd_file = MrMurano::Passwords.new(pwd_path)
      pwd_file.load
      pwd_file
    end

    def token_twofactor_lookup(pwd_file)
      twoftoken = pwd_file.lookup(host, user + '/twofactor')
      if twoftoken.to_s.empty?
        nil
      elsif twoftoken !~ /^[a-fA-F0-9]+$/
        warning "Malformed twofactor token: #{twoftoken}"
        nil
      else
        twoftoken
      end
    end

    # ---------------------------------------------------------------------

    def token
      return '' if defined?(@logging_on) && @logging_on
      token_fetch if @token.to_s.empty?
      @token
    end

    def token_reset(value=nil)
      @token = value
    end

    def token_fetch
      @logging_on = true
      creds = login_info
      @token = nil

      # If 2fa token found, verify it works.
      unless @twofactor_token.nil?
        get('token/' + @twofactor_token) do |request, http|
          http.request(request) do |response|
            if response.is_a?(Net::HTTPSuccess)
              # response.body is, e.g., "{\"email\":\"xxx@yyy.zzz\",\"ttl\":172800}"
              @token = @twofactor_token
            end
          end
        end
        unless @token.nil?
          @logging_on = false
          return
        end
        @twofactor_token = nil
      end

      MrMurano::Verbose.whirly_start('Logging in...')
      post('token/', creds) do |request, http|
        http.request(request) do |response|
          reply = JSON.parse(response.body, json_opts)
          if response.is_a?(Net::HTTPSuccess)
            @token = reply[:token]
          elsif response.is_a?(Net::HTTPConflict) && reply[:message] == 'twofactor'
            MrMurano::Verbose.whirly_interject do
              # Prompt user for emailed code.
              token_twofactor_fetch(creds)
            end
          else
            showHttpError(request, response)
            error 'Check to see if username and password are correct.'
            unless ENV['MURANO_PASSWORD'].to_s.empty?
              pwd_path = $cfg.file_at('passwords', :user)
              warning "NOTE: MURANO_PASSWORD specifies the password; it was not read from #{pwd_path}"
            end
          end
        end
      end
      MrMurano::Verbose.whirly_stop
      @logging_on = false
    end

    def token_twofactor_fetch(creds)
      error 'Two-factor Authentication'
      warning 'A verification code has been sent to your email.'
      code = ask('Please enter the code here to continue: ').strip
      unless code =~ /^[a-fA-F0-9]+$/
        error 'Expected token to contain only numbers and hexadecimal letters.'
        exit 1
      end
      MrMurano::Verbose.whirly_start('Verifying code...')

      path = 'key/' + code

      response = get(path)
      # Response is, e.g., {
      #   purpose: "twofactor",
      #   status: "exists",
      #   email: "xxx@yyy.zzz",
      #   bizid: null,
      #   businessName: null, }
      return if response.nil?

      response = post(path, password: creds[:password])
      # Response is, e.g., { "token": "..." }
      return if response.nil?

      @twofactor_token = response[:token]
      pwd_file = pwd_file_load
      pwd_file.set(host, user + '/twofactor', @twofactor_token)
      pwd_file.save
      @token = @twofactor_token
      MrMurano::Verbose.whirly_stop

      warning 'Please run `murano logout --token` to clear your two-factor token when finished.'
    end

    def logout(token_delete_only)
      @logging_on = true

      pwd_file = pwd_file_load
      twoftoken = token_twofactor_lookup(pwd_file)

      # First, delete/invalidate the remote token.
      unless twoftoken.to_s.empty?
        verbose 'Removing two-factor token.'
        @suppress_error = true
        delete('token/' + twoftoken)
        # The response is nil if the token was not recognized, otherwise it's
        # {}. We don't really care, since we're going to forget our copy of
        # the token, anyway.
        @suppress_error = false
      end

      net_host = verify_set('net.host')
      user_name = verify_set('user.name')
      if net_host && user_name
        pwd_file = MrMurano::Passwords.new
        pwd_file.load
        pwd_file.remove(net_host, user_name) unless token_delete_only
        pwd_file.remove(net_host, user_name + '/twofactor')
        pwd_file.save
      else
        verbose 'Skipping password scrub: need both net.host and user.name to remove.'
      end

      clear_from_config(net_host, user_name) unless token_delete_only

      @logging_on = false
    end

    def clear_from_config(net_host, user_name)
      user_net_host = $cfg.get('net.host', :user)
      user_net_host = $cfg.get('net.host', :defaults) if user_net_host.nil?
      user_user_name = $cfg.get('user.name', :user)
      # Only clear user name from the user config if the net.host
      # or user.name did not come from a different config, like the
      # --project config.
      unless (user_net_host == net_host) && (user_user_name == user_name)
        verbose 'Skipping config scrub: net.host and/or user.name do not match.'
        return
      end
      $cfg.set('user.name', nil, :user)
      $cfg.set('business.id', nil, :user)
      $cfg.set('business.name', nil, :user)
    end

    def verify_set(cfg_key)
      cfg_val = $cfg.get(cfg_key)
      if cfg_val.to_s.empty?
        cfg_val = nil
        cfg_key_q = MrMurano::Verbose.fancy_ticks(cfg_key)
        MrMurano::Verbose.warning("No config key #{cfg_key_q}: no password to delete")
      end
      cfg_val
    end

    # ---------------------------------------------------------------------

    def businesses(bid: nil, name: nil, fuzzy: nil)
      # Ask user for name and password, if not saved to config and password files.
      login_info if user.empty?
      raise 'Missing user?!' if user.empty?

      MrMurano::Verbose.whirly_start 'Fetching Businesses...'
      bizes = get('user/' + user + '/membership/')
      MrMurano::Verbose.whirly_stop
      return [] unless bizes.is_a?(Array) && bizes.any?

      # 2017-06-30: The data for each message contains a :bizid, :role, and :name.
      #   :role is probably generally "owner".

      match_bid = ensure_array(bid)
      match_name = ensure_array(name)
      match_fuzzy = ensure_array(fuzzy)
      if match_bid.any? || match_name.any? || match_fuzzy.any?
        bizes.select! do |biz|
          (
            match_bid.include?(biz[:bizid]) ||
            match_name.include?(biz[:name]) ||
            match_fuzzy.any? do |term|
              biz[:name] =~ /#{Regexp.escape(term)}/i || biz[:bizid] =~ /#{Regexp.escape(term)}/i
            end
          )
        end
      end

      bizes.map! { |meta| MrMurano::Business.new(meta) }

      # Sort results.
      bizes.sort_by!(&:name)
    end

    # ---------------------------------------------------------------------

    # 2017-07-05: [lb] notes that the remaining methods are not called.
    #   (Tilstra might be calling these via the _qb plugin.)

    def new_account(email, name, company='')
      # this is a kludge.  If we're gonna support this, do it better.
      @token = ''
      post('key/', email: email, name: name, company: company, source: 'signup')
    end

    def reset_account(email)
      post('key/', email: email, source: 'reset')
    end

    def accept_account(token, password)
      # this is a kludge.  If we're gonna support this, do it better.
      @token = ''
      post("key/#{token}", password: password)
    end

    # ---------------------------------------------------------------------

    def new_business(name)
      post('business/', name: name)
    end

    def delete_business(id)
      delete("business/#{id}")
    end
  end
end


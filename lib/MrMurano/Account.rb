# Last Modified: 2017.08.22 /coding: utf-8
# frozen_string_literal: true

# Copyright © 2016-2017 Exosite LLC.
# License: MIT. See LICENSE.txt.
#  vim:tw=0:ts=2:sw=2:et:ai

require 'date'
require 'json'
require 'net/http'
require 'pathname'
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
    end

    def host
      $cfg['net.host'].to_s
    end

    def user
      $cfg['user.name'].to_s
    end

    def endpoint(path)
      URI('https://' + host + '/api:1/' + path.to_s)
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
      pwd_path = $cfg.file_at('passwords', :user)
      pwd_file = MrMurano::Passwords.new(pwd_path)
      pwd_file.load
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
        pwd_file.save
        MrMurano::Verbose.whirly_unpause
      end
      creds = {
        email: user,
        password: user_pass,
      }
      creds
    end

    # ---------------------------------------------------------------------

    def token
      token_fetch if @token.to_s.empty?
      @token
    end

    def token_reset(value=nil)
      @token = value
    end

    def token_fetch
      # Cannot have token call token, so cannot use Http::workit.
      uri = endpoint('token/')
      request = Net::HTTP::Post.new(uri)
      request['User-Agent'] = "MrMurano/#{MrMurano::VERSION}"
      request.content_type = 'application/json'
      curldebug(request)
      #request.basic_auth(username(), password())
      request.body = JSON.generate(login_info)

      MrMurano::Verbose.whirly_start('Logging in...')
      response = http.request(request)
      MrMurano::Verbose.whirly_stop

      case response
      when Net::HTTPSuccess
        token = JSON.parse(response.body, json_opts)
        @token = token[:token]
      else
        showHttpError(request, response)
        error 'Check to see if username and password are correct.'
        unless ENV['MURANO_PASSWORD'].to_s.empty?
          pwd_path = $cfg.file_at('passwords', :user)
          warning "NOTE: MURANO_PASSWORD specifies the password; it was not read from #{pwd_path}"
        end
        @token = nil
      end
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


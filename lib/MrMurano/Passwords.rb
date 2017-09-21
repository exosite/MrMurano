# Last Modified: 2017.09.20 /coding: utf-8
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
require 'MrMurano/http'
require 'MrMurano/verbosing'
require 'MrMurano/Config'
require 'MrMurano/Solution'

module MrMurano
  # The Passwords class manages an end user's Murano user name and password.
  class Passwords
    include Verbose

    def initialize(path=nil)
      path = $cfg.file_at('passwords', :user) if path.nil?
      path = Pathname.new(path) unless path.is_a?(Pathname)
      @path = path
      @data = nil
    end

    def load
      return unless @path.exist?
      @path.chmod(0o600)
      @path.open('rb') do |io|
        @data = YAML.load(io)
      end
    end

    def save
      if $cfg['tool.dry']
        say '--dry: Not saving config'
        return
      end
      @path.dirname.mkpath unless @path.dirname.exist?
      @path.open('wb') do |io|
        io << @data.to_yaml
      end
      @path.chmod(0o600)
    end

    def set(host, user, pass)
      unless @data.is_a?(Hash)
        @data = { host => { user => pass } }
        return
      end
      hd = @data[host]
      if hd.nil? || !hd.is_a?(Hash)
        @data[host] = { user => pass }
        return
      end
      @data[host][user] = pass
    end

    def get(host, user)
      return ENV['MURANO_PASSWORD'] unless ENV['MURANO_PASSWORD'].to_s.empty?
      unless ENV['MR_PASSWORD'].nil?
        warning %(
          Using deprecated environment variable, "MR_PASSWORD". Please rename to "MURANO_PASSWORD"
        ).strip
        return ENV['MR_PASSWORD']
      end
      lookup(host, user)
    end

    def lookup(host, user)
      return nil unless @data.is_a?(Hash)
      return nil unless @data.key?(host)
      return nil unless @data[host].is_a?(Hash)
      return nil unless @data[host].key?(user)
      @data[host][user]
    end

    ## Remove the password for a user.
    def remove(host, user)
      return unless @data.is_a?(Hash)
      hd = @data[host]
      return unless !hd.nil? && hd.is_a?(Hash)
      if $cfg['tool.dry']
        MrMurano::Verbose.whirly_interject do
          say(%(--dry: Not removing password for #{fancy_ticks("#{user}@#{host}")}))
        end
        return
      end
      @data[host].delete(user) if hd.key?(user)
    end

    ## Get all hosts and usernames. Does not return passwords.
    def list
      ret = {}
      @data.each_pair { |key, value| ret[key] = value.keys } unless @data.nil?
      ret
      # MAYBE/2017-08-17:
      #   sort_by_name(ret)
    end
  end
end


# Last Modified: 2017.07.26 /coding: utf-8
# frozen_string_literal: true

# Copyright © 2016-2017 Exosite LLC.
# License: MIT. See LICENSE.txt.
#  vim:tw=0:ts=2:sw=2:et:ai

require 'json'
require 'net/http'
require 'pp'
require 'uri'
require 'yaml'
require 'MrMurano/Solution'
#require 'MrMurano/SyncRoot'

module MrMurano
  ##
  # User Management common things
  class UserBase < SolutionBase
    def initialize
      super
    end

    def list
      get
    end

    def fetch(id)
      get('/' + id.to_s)
    end

    def remove(id)
      delete('/' + id.to_s)
    end

    # @param modify Bool: True if item exists already and this is changing it
    def upload(_local, remote, _modify)
      # Roles cannot be modified, so must delete and post.
      delete('/' + remote[@itemkey]) do |request, http|
        response = http.request(request)
        case response
        # rubocop:disable Lint/EmptyWhen: Avoid when branches without a body.
        when Net::HTTPSuccess
        when Net::HTTPNotFound
        else
          showHttpError(request, response)
        end
      end
      remote.reject! { |k, _v| %i[bundles synckey synctype].include? k }
      post('/', remote)
    end

    def download(local, item)
      # needs to append/merge with file
      # for now, we'll read, modify, write
      here = []
      if local.exist?
        # FIXME/2017-07-18: Security/YAMLLoad: Prefer using YAML.safe_load over YAML.load.
        #   Disabling [rubo]cop for now.
        # rubocop:disable Security/YAMLLoad
        local.open('rb') { |io| here = YAML.load(io) }
        here = [] if here == false
      end
      here.delete_if do |i|
        Hash.transform_keys_to_symbols(i)[@itemkey] == item[@itemkey]
      end
      here << item.reject { |k, _v| %i[synckey synctype].include? k }
      local.open('wb') do |io|
        io.write here.map { |i| Hash.transform_keys_to_strings(i) }.to_yaml
      end
    end

    def removelocal(local, item)
      # needs to append/merge with file
      # for now, we'll read, modify, write
      here = []
      if local.exist?
        # FIXME/2017-07-18: Security/YAMLLoad: Prefer using YAML.safe_load over YAML.load.
        local.open('rb') { |io| here = YAML.load(io) }
        here = [] if here == false
      end
      key = @itemkey.to_sym
      here.delete_if do |it|
        Hash.transform_keys_to_symbols(it)[key] == item[key]
      end
      local.open('wb') do |io|
        io.write here.map { |i| Hash.transform_keys_to_strings(i) }.to_yaml
      end
    end

    def tolocalpath(into, _item)
      into
    end

    def localitems(from)
      from = Pathname.new(from) unless from.is_a? Pathname
      unless from.exist?
        warning "Skipping missing #{from}"
        return []
      end
      unless from.file?
        warning "Cannot read from #{from}"
        return []
      end

      # MAYBE/2017-07-03: Do we care if there are duplicate keys in the yaml? See dup_count.
      here = []
      # FIXME/2017-07-18: Security/YAMLLoad: Prefer using YAML.safe_load over YAML.load.
      from.open { |io| here = YAML.load(io) }
      here = [] if here == false

      here.map { |i| Hash.transform_keys_to_symbols(i) }
    end
  end

  # …/role
  class Role < UserBase
    def initialize
      @solntype = 'application.id'
      #@solntype = 'product.id'
      super
      @uriparts << 'role'
      @itemkey = :role_id
    end

    def self.description
      %(Roles)
    end
  end
  #SyncRoot.instance.add('roles', Role, 'R', false)

  # …/user
  # :nocov:
  class User < UserBase
    def initialize
      # 2017-07-03: [lb] tried 'product.id' and got 403 Forbidden;
      #   And I tried 'application.id' and get() returned an empty [].
      @solntype = 'application.id'
      #@solntype = 'product.id'
      super
      @uriparts << 'user'
    end

    def self.description
      %(Users)
    end

    # @param modify Bool: True if item exists already and this is changing it
    def upload(_local, _remote, _modify)
      # TODO: figure out APIs for updating users.
      warning %(Updating Users isn't working currently.)
      # post does work if the :password field is set.
    end

    def synckey(item)
      item[:email]
    end
  end
  # :nocov:
  #SyncRoot.instance.add('users', User, 'U', false)
end


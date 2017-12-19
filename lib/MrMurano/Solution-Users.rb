# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

require 'json'
require 'net/http'
require 'pathname'
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
      # MAYBE/2017-08-17:
      #   ret = get
      #   return [] unless ret.is_a?(Array)
      #   sort_by_name(ret)
    end

    def fetch(id)
      get('/' + id.to_s)
    end

    def remove(id)
      return unless remove_item_allowed(id)
      delete('/' + id.to_s)
    end

    # @param modify Bool: True if item exists already and this is changing it
    def upload(_local, remote, _modify)
      return unless upload_item_allowed(remote[@itemkey])
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

    def download(local, item, _options=nil)
      # needs to append/merge with file
      # for now, we'll read, modify, write
      here = []
      if local.exist?
        local.open('rb') { |io| here = YAML.load(io) }
        here = [] if here == false
      end
      here.delete_if do |i|
        Hash.transform_keys_to_symbols(i)[@itemkey] == item[@itemkey]
      end
      here << item.reject { |k, _v| %i[synckey synctype].include? k }
      return unless download_item_allowed(item[@itemkey])
      local.open('wb') do |io|
        io.write here.map { |i| Hash.transform_keys_to_strings(i) }.to_yaml
      end
    end

    def removelocal(local, item)
      # needs to append/merge with file
      # for now, we'll read, modify, write
      here = []
      if local.exist?
        local.open('rb') { |io| here = YAML.load(io) }
        here = [] if here == false
      end
      key = @itemkey.to_sym
      here.delete_if do |it|
        Hash.transform_keys_to_symbols(it)[key] == item[key]
      end
      return unless removelocal_item_allowed(item[key])
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
      from.open { |io| here = YAML.load(io) }
      here = [] if here == false

      here.map! { |i| Hash.transform_keys_to_symbols(i) }

      sort_by_name(here)
    end
  end

  # …/role
  class Role < UserBase
    def initialize
      @solntype = 'application.id'
      #@solntype = 'product.id'
      super
      @uriparts << :role
      @itemkey = :role_id
    end

    def self.description
      %(Role)
    end
  end
  #SyncRoot.instance.add('roles', Role, 'G', false)

  # …/user
  # :nocov:
  class User < UserBase
    def initialize
      # 2017-07-03: [lb] tried 'product.id' and got 403 Forbidden;
      #   And I tried 'application.id' and get() returned an empty [].
      @solntype = 'application.id'
      #@solntype = 'product.id'
      super
      @uriparts << :user
    end

    def self.description
      %(User)
    end

    # @param modify Bool: True if item exists already and this is changing it
    def upload(local, _remote, _modify)
      # TODO: figure out APIs for updating users.
      warning %(Updating Users is not yet implemented.)
      # post does work if the :password field is set.
      return unless upload_item_allowed(local)
    end

    def synckey(item)
      item[:email]
    end
  end
  # :nocov:
  #SyncRoot.instance.add('users', User, 'U', false)
end


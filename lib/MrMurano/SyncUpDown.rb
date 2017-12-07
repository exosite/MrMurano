# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

# FIXME/MAYBE: Fix semicolon usage.
# rubocop:disable Style/Semicolon

require 'inflecto'
require 'open3'
require 'os'
require 'pathname'
#require 'shellwords'
require 'tempfile'
require 'time'
require 'MrMurano/progress'
require 'MrMurano/verbosing'
require 'MrMurano/hash'
#require 'MrMurano/Config'
#require 'MrMurano/ProjectFile'
require 'MrMurano/SyncAllowed'
##require 'MrMurano/SyncRoot'

module MrMurano
  ## The functionality of a Syncable thing.
  #
  # This provides the logic for computing what things have changed, and pushing and
  # pulling those things.
  #
  module SyncUpDown
    include SyncAllowed

    # This is one item that can be synced.
    class Item
      # @return [String] The name of this item.
      attr_accessor :name
      # @return [Pathname] Where this item lives.
      attr_accessor :local_path
      # FIXME/EXPLAIN: ??? what is this?
      attr_accessor :id
      # @return [String] The Lua code for this item. (not all items use this.)
      attr_accessor :script
      # @return [Integer] The line in #local_path where this #script starts.
      attr_accessor :line
      # @return [Integer] The line in #local_path where this #script ends.
      attr_accessor :line_end
      # @return [String] If requested, the diff output.
      attr_accessor :diff
      # @return [Boolean] When filtering, did this item pass.
      attr_accessor :selected
      # @return [String] The constructed name used to match local items to remote items.
      attr_accessor :synckey
      # @return [String] The syncable type.
      attr_accessor :synctype
      # @return [String] The updated_at time from the server is used to detect changes.
      attr_accessor :updated_at
      # @return [Integer] Positive if multiple conflicting files found for same item.
      attr_accessor :dup_count

      # Initialize a new Item with a few, or all, attributes.
      # @param hsh [Hash{Symbol=>Object}, Item] Initial values
      #
      # @example Initializing with a Hash
      #  Item.new(:name=>'Bob', :local_path => Pathname.new(…))
      # @example Initializing with an Item
      #  item = Item.new(:name => 'get')
      #  Item.new(item)
      def initialize(hsh={})
        hsh.each_pair { |k, v| self[k] = v }
      end

      def as_inst(key)
        return key if key.to_s[0] == '@'
        "@#{key}"
      end
      private :as_inst

      def as_sym(key)
        return key.to_sym if key.to_s[0] != '@'
        key.to_s[1..-1].to_sym
      end
      private :as_sym

      # Get attribute as if this was a Hash
      # @param key [String,Symbol] attribute name
      # @return [Object] The value
      def [](key)
        public_send(key.to_sym)
      rescue NoMethodError
        nil
      end

      # Set attribute as if this was a Hash
      # @param key [String,Symbol] attribute name
      # @param value [Object] value to set
      def []=(key, value)
        public_send("#{key}=", value)
      rescue StandardError => err
        MrMurano::Verbose.error(
          "Unable to set key: #{key} / value: #{value} / err: #{err} / self: #{inspect}"
        )
      end

      # Delete a key
      # @param key [String,Symbol] attribute name
      # @return [Object] The value
      def delete(key)
        inst = as_inst(key)
        remove_instance_variable(inst) if instance_variable_defined?(inst)
      end

      # @return [Hash{Symbol=>Object}] A hash that represents this Item
      def to_h
        Hash[instance_variables.map { |k| [as_sym(k), instance_variable_get(k)] }]
      end

      # Adds the contents of item to self.
      # @param item [Item,Hash] Stuff to merge
      # @return [Item] ourself
      def merge!(item)
        item.each_pair { |k, v| self[k] = v }
        self
      end

      # A new Item containing our plus items.
      # @param item [Item,Hash] Stuff to merge
      # @return [Item] New item with contents of both
      def merge(item)
        dup.merge!(item)
      end

      # Calls block once for each non-nil key
      # @yieldparam key [Symbol] The name of the key
      # @yieldparam value [Object] The value for that key
      # @return [Item]
      def each_pair
        instance_variables.each do |key|
          yield as_sym(key), instance_variable_get(key)
        end
        self
      end

      # Delete items in self that block returns true.
      # @yieldparam key [Symbol] The name of the key
      # @yieldparam value [Object] The value for that key
      # @yieldreturn [Boolean] True to delete this key
      # @return [Item] Ourself.
      def reject!(&_block)
        instance_variables.each do |key|
          drop = yield as_sym(key), instance_variable_get(key)
          delete(key) if drop
        end
        self
      end

      # A new Item with keys deleted where block is true
      # @yieldparam key [Symbol] The name of the key
      # @yieldparam value [Object] The value for that key
      # @yieldreturn [Boolean] True to delete this key
      # @return [Item] New Item with keys deleted
      def reject(&block)
        dup.reject!(&block)
      end

      # For unit testing.
      include Comparable
      def <=>(other)
        # rubocop:disable Style/RedundantSelf: Redundant self detected.
        #   MAYBE/2017-07-18: Permanently disable Style/RedundantSelf?
        self.to_h <=> other.to_h
      end
    end
    # MrMurano::SyncUpDown::Item

    #######################################################################
    # Methods that must be overridden

    ##
    # Get a list of remote items.
    #
    # Children objects Must override this
    #
    # @return [Array<Item>] of item details
    def list
      []
    end

    ## Remove remote item
    #
    # Children objects Must override this
    #
    # @param itemkey [String] The identifying key for this item
    def remove(_itemkey)
      # :nocov:
      raise 'Forgotten implementation'
      # :nocov:
    end

    def remove_lite(itemkey, _thereitem, _modify=false)
      remove(itemkey)
    end

    ## Upload local item to remote
    #
    # Children objects Must override this
    #
    # @param src [Pathname] Full path of where to upload from
    # @param item [Hash] The item details to upload
    # @param modify [Bool] True if item exists already and this is changing it
    def upload(_src, _item, _modify)
      # :nocov:
      raise 'Forgotten implementation'
      # :nocov:
    end

    ##
    # True if itemA and itemB are different
    #
    # Children objects must override this
    #
    def docmp(_item_a, _item_b)
      true
    end

    #
    #######################################################################

    #######################################################################
    # Methods that could be overridden

    ##
    # Compute a remote item hash from the local path
    #
    # Children objects should override this.
    #
    # @param root [Pathname,String] Root path for this resource type from config files
    # @param path [Pathname,String] Path to local item
    # @return [Item] hash of the details for the remote item for this path
    def to_remote_item(root, path)
      # This mess brought to you by Windows short path names.
      path = Dir.glob(path.to_s).first
      root = Dir.glob(root.to_s).first
      path = Pathname.new(path)
      root = Pathname.new(root)
      Item.new(name: path.realpath.relative_path_from(root.realpath).to_s)
    end

    ##
    # Compute the local name from remote item details
    #
    # Children objects should override this or #tolocalpath
    #
    # @param item [Item] listing details for the item.
    # @param itemkey [Symbol] Key for look up.
    def tolocalname(item, itemkey)
      item[itemkey].to_s
    end

    ##
    # Compute the local path from the listing details
    #
    # If there is already a matching local item, some of its details are also in
    # the item hash.
    #
    # Children objects should override this or #tolocalname
    #
    # @param into [Pathname] Root path for this resource type from config files
    # @param item [Item] listing details for the item.
    # @return [Pathname] path to save (or merge) remote item into
    def tolocalpath(into, item)
      return item[:local_path] unless item.local_path.nil?
      itemkey = @itemkey.to_sym
      name = tolocalname(item, itemkey)
      raise "Bad key(#{itemkey}) for #{item}" if name.nil?
      name = Pathname.new(name) unless name.is_a? Pathname
      name = name.relative_path_from(Pathname.new('/')) if name.absolute?
      into + name
    end

    ## Does item match pattern?
    #
    # Children objects should override this if synckey is not @itemkey
    #
    # Check child specific patterns against item
    #
    # @param item [Item] Item to be checked
    # @param pattern [String] pattern to check with
    # @return [Bool] true or false
    def match(_item, _pattern)
      false
    end

    ## Get the key used to quickly compare two items
    #
    # Children objects should override this if synckey is not @itemkey
    #
    # @param item [Item] The item to get a key from
    # @return [Object] The object to use a comparison key
    def synckey(item)
      key = @itemkey.to_sym
      item[key]
    end

    ## Download an item into local
    #
    # Children objects should override this or implement #fetch()
    #
    # @param local [Pathname] Full path of where to download to
    # @param item [Item] The item to download
    def download(local, item, options: {}, is_tmp: false)
      #if item[:bundled]
      #  warning "Not downloading into bundled item #{synckey(item)}"
      #  return
      #end
      id = item[@itemkey.to_sym]
      if id.to_s.empty?
        if @itemkey.to_sym != :id
          debug "Missing '#{@itemkey}', trying :id instead"
          id = item[:id]
        end
        if id.to_s.empty?
          debug %(Remote item "#{item[:name]}" missing :id / local: #{local} / item: #{item})
          return if options[:ignore_errors]
          error %(Remote item missing :id => #{local})
          say %(You can ignore this error using --ignore-errors)
          exit 1
        end
        debug ":id => #{id}"
      end
      unless is_tmp
        relpath = local.relative_path_from(Pathname.pwd).to_s
        return unless download_item_allowed(relpath)
      end
      # MAYBE: If is_tmp and doing syncdown, just use this file rather
      # than downloading again.
      local.dirname.mkpath
      local.open('wb') do |io|
        fetch(id) do |chunk|
          io.write config_vars_encode chunk
        end
      end
      update_mtime(local, item)
    end

    def diff_download(tmp_path, merged, options)
      download(tmp_path, merged, options: options, is_tmp: true)
    end

    ## Give the local file the same timestamp as the remote, because diff.
    #
    # @param local [Pathname] Full path of where to download to
    # @param item [Item] The item to download
    def update_mtime(local, item)
      # FIXME/MUR-XXXX: Ideally, server should use a hash we can compare.
      #   For now, we use the sometimes set :updated_at value.
      # FIXME/EXPLAIN/2017-06-23: Why is :updated_at sometimes not set?
      #   (See more comments, below.)
      return unless item[:updated_at]

      mod_time = item[:updated_at]
      mod_time = Time.parse(mod_time) unless mod_time.is_a?(Time)
      begin
        FileUtils.touch([local.to_path], mtime: mod_time)
      rescue Errno::EACCES => err
        # This happens on Windows...
        require 'rbconfig'
        # Check the platform, e.g., "linux-gnu", or other.
        #is_windows = (
        #  RbConfig::CONFIG['host_os'] =~ /mswin|msys|mingw|cygwin|bccwin|wince|emc/
        #)
        unless OS.windows?
          msg = 'Unexpected: touch failed on non-Windows machine'
          warn "#{msg} / host_os: #{RbConfig::CONFIG['host_os']} / err: #{err}"
        end

        # 2017-07-13: Nor does ctime work.
        #   Errno::EACCES:
        #   Permission denied @ utime_failed -
        #     C:/Users/ADMINI~1/AppData/Local/Temp/2/one.lua_remote_20170714-1856-by2nzk.lua
        #File.utime(mod_time, mod_time, local.to_path)

        # 2017-07-14: So this probably fails, too...
        #FileUtils.touch [local.to_path,], :ctime => mod_time

        # MAYBE/2017-07-14: How to make diff work on Windows?
        #   Would need to store timestamp in metafile?

        # FIXME/EXPLAIN/2017-06-23: Why is :updated_at sometimes not set?
        #     And why have I only triggered this from ./spec/cmd_syncdown_spec.rb ?
        #       (Probably because nothing else makes routes or files?)
        #     Here are the items in question:
        #
        # Happens to each of the MrMurano::Webservice::Endpoint::RouteItem's:
        #
        # <MrMurano::Webservice::Endpoint::RouteItem:0x007fe719cb6300
        #   @id="QeRq21Cfij",
        #   @method="delete",
        #   @path="/api/fire/{code}",
        #   @content_type="application/json",
        #   @script="--#ENDPOINT delete /api/fire/{code}\nreturn 'ok'\n\n-- vim: set ai sw=2 ts=2 :\n",
        #   @use_basic_auth=false,
        #   @synckey="DELETE_/api/fire/{code}">
        #
        # Happens to each of the MrMurano::Webservice::File::FileItem's:
        #
        # <MrMurano::Webservice::File::FileItem:0x007fe71a44a8f0
        #   @path="/",
        #   @mime_type="text/html",
        #   @checksum="da39a3ee5e6b4b0d3255bfef95601890afd80709",
        #   @synckey="/">
      end
    end

    ## Remove local reference of item
    #
    # Children objects should override this if move than just unlinking the local
    # item.
    #
    # @param dest [Pathname] Full path of item to be removed
    # @param item [Item] Full details of item to be removed
    def removelocal(dest, _item)
      return unless removelocal_item_allowed(dest)
      dest.unlink if dest.exist?
    end

    def syncup_before
      syncable_validate_api_id
    end

    def syncup_after
    end

    def syncdown_before
      syncable_validate_api_id
    end

    def syncdown_after(_local)
    end

    def diff_item_write(io, merged, _local, _remote)
      contents = merged[:local_path].read
      contents = config_vars_decode(contents)
      io << contents
    end

    #
    #######################################################################

    # So, for bundles this needs to look at all the places
    # and build up the merged stack of local items.
    #
    # Which means it needs the from to be split into the base
    # and the sub so we can inject bundle directories.

    ##
    # Get a list of local items.
    #
    # Children should never need to override this.
    # Instead they should override #localitems.
    #
    # This collects items in the project and all bundles.
    # @return [Array<Item>] items found
    #
    # 2017-07-02: [lb] removed this commented-out code from the locallist
    # body. I think it's for older Solutionfiles, like 0.2.0 and 0.3.0.
    #def locallist
    #  # so. if @locationbase/bundles exists
    #  #  gather and merge: @locationbase/bundles/*/@location
    #  # then merge @locationbase/@location
    #  #
    #  bundleDir = $cfg['location.bundles'] or 'bundles'
    #  bundleDir = 'bundles' if bundleDir.nil?
    #  items = {}
    #  if (@locationbase + bundleDir).directory?
    #    (@locationbase + bundleDir).children.sort.each do |bndl|
    #      if (bndl + @location).exist?
    #        verbose("Loading from bundle #{bndl.basename}")
    #        bitems = localitems(bndl + @location)
    #        bitems.map!{|b| b[:bundled] = true; b} # mark items from bundles.
    #        # use synckey for quicker merging.
    #        bitems.each { |b| items[synckey(b)] = b }
    #      end
    #    end
    #  end
    #end
    #
    def locallist(skip_warn: false)
      items = {}
      if location.exist?
        # Get a list of SyncUpDown::Item's, or a class derived thereof.
        bitems = localitems(location)
        # Use synckey for quicker merging.
        #bitems.each { |b| items[synckey(b)] = b }
        # 2017-07-02: If two files have the same identity, the simple loop
        #   masks that there are two files with the same identity. So check
        #   first for duplicates, and then process each item.
        seen = {}
        bitems.each do |item|
          skey = synckey(item)
          seen[skey] = seen.key?(skey) && seen[skey] + 1 || 1
        end
        counts = {}
        bitems.each do |item|
          skey = synckey(item)
          if seen[skey] > 1
            if items[skey].nil?
              items[skey] = MrMurano::EventHandler::EventHandlerItem.new(item)
              items[skey][:dup_count] = 0
            end
            counts[skey] = counts.key?(skey) && counts[skey] + 1 || 1
            # Use a unique synckey so all duplicates make it in the list.
            uniq_synckey = "#{skey}-#{counts[skey]}"
            item[:dup_count] = counts[skey]
            # This sets the alias for the output, so duplicates look unique.
            item[@itemkey.to_sym] = uniq_synckey
            items[uniq_synckey] = item
            msg = "Duplicate definition found for #{fancy_ticks(skey)}"
            if self.class.description.to_s != ''
              msg += " for #{fancy_ticks(self.class.description)}"
            end
            warning(msg)
            warning(" #{item.local_path}")
          else
            items[skey] = item
          end
        end
      elsif !skip_warn
        @missing_complaints = [] unless defined?(@missing_complaints)
        unless @missing_complaints.include?(location)
          # MEH/2017-07-31: This message is a little misleading on syncdown,
          #   e.g., in rspec ./spec/cmd_syncdown_spec.rb, one test blows away
          #   local directories and does a syncdown, and on stderr you'll see
          #     Skipping missing location
          #      ‘/tmp/d20170731-3150-1f50uj4/project/specs/resources.yaml’ (Resources)
          #   but then later in the syncdown, that directory and file gets created.
          msg = "Skipping missing location #{fancy_ticks(location)}"
          unless self.class.description.to_s.empty?
            msg += " (#{Inflecto.pluralize(self.class.description)})"
          end
          warning(msg)
          @missing_complaints << location
        end
      end
      items.values
    end

    def resurrect_undeletables(localbox, _therebox)
      # It's up to the Syncables to implement this, if they care.
      localbox
    end

    ##
    # Get the full path for the local versions
    # @return [Pathname] Location for local items
    def location
      raise 'Missing @project_section' if @project_section.nil?
      Pathname.new($cfg['location.base']) + $project["#{@project_section}.location"]
    end

    ##
    # Returns array of globs to search for files
    # @return [Array<String>] of Strings that are globs
    # rubocop:disable Style/MethodName: Use snake_case for method names.
    #  MAYBE/2017-07-18: Rename this. Beware the config has a related keyname.
    def searchFor
      raise 'Missing @project_section' if @project_section.nil?
      $project["#{@project_section}.include"]
    end

    ## Returns array of globs of files to ignore
    # @return [Array<String>] of Strings that are globs
    def ignoring
      raise 'Missing @project_section' if @project_section.nil?
      $project["#{@project_section}.exclude"]
    end

    ##
    # Get a list of local items rooted at #from
    #
    # Children rarely need to override this. Only when the locallist is not a set
    # of files in a directory will they need to override it.
    #
    # @param from [Pathname] Directory of items to scan
    # @return [Array<Item>] Items found
    def localitems(from)
      # TODO: Profile this.
      debug "#{self.class}: Getting local items from:\n  #{from}"
      search_in = from.to_s
      sf = searchFor.map { |i| ::File.join(search_in, i) }
      debug "#{self.class}: Globs:\n  #{sf.join("\n  ")}"
      # 2017-07-27: Add uniq to cull duplicate entries that globbing
      # all the ways might produce, otherwise status/sync/diff complain
      # about duplicate resources. I [lb] think this problem has existed
      # but was exacerbated by the change to support sub-directory scripts
      # (Nested Lua support).
      items = Dir[*sf].uniq.flatten.compact.reject do |path|
        if ::File.directory?(path)
          true
        else
          ignoring.any? { |pattern| self.ignore?(path, pattern) }
        end
      end
      items = items.map do |path|
        # Do not resolve symlinks, just relative paths (. and ..),
        # otherwise it makes nested Lua support tricky, because
        # symlinks might be outside the root item path, and then
        # the nested Lua path looks like ".......some_dir/some_item".
        if $cfg['modules.no-nesting']
          rpath = Pathname.new(path).realpath
        else
          rpath = Pathname.new(path).expand_path
        end
        item = to_remote_item(from, rpath)
        if item.is_a?(Array)
          item.compact.map { |i| i[:local_path] = rpath; i }
        elsif !item.nil?
          item[:local_path] = rpath
          item
        end
      end
      #items = items.flatten.compact.sort_by!(&:local_path)
      #debug "#{self.class}: items:\n  #{items.map(&:local_path).join("\n  ")}"
      items = items.flatten.compact.sort_by { |it| it[:local_path] }
      debug "#{self.class}: items:\n  #{items.map { |it| it[:local_path] }.join("\n  ")}"
      sort_by_name(items)
    end

    def ignore?(path, pattern)
      # 2017-08-18: [lb] not sure this block should be disabled for no-nesting.
      # The block *was* added for Nested Lua support. But I think it was
      # more necessary because modules.include is now '**/*.lua', not '*/*.lua'.
      # Or maybe this block was because we now use expand_path, not realpath.
      if !$cfg['modules.no-nesting'] && pattern.start_with?('**/')
        # E.g., '**/.*' or '**/*'
        dirname = File.dirname(path)
        return true if ['.', ::File::ALT_SEPARATOR, ::File::SEPARATOR].include?(dirname)
        # There's at least one ancestor directory.
        # Remove the '**', which ::File.fnmatch doesn't recognize, and the path delimiter.
        # 2017-08-08: Why does Rubocop not follow Style/RegexpLiteral here?
        #pattern = pattern.gsub(/^\*\*\//, '')
        pattern = pattern.gsub(%r{^\*\*\/}, '')
      end

      ignore = ::File.fnmatch(pattern, path)
      debug "Excluded #{path}" if ignore
      ignore
    end

    def resolve_config_var_usage!(there, local)
      # pass; derived classes should implement.
    end

    def config_vars_decode(script)
      script
    end

    def config_vars_encode(script)
      script
    end

    #######################################################################
    # Methods that provide the core status/syncup/syncdown

    def sync_update_progress(msg)
      if $cfg['tool.no-progress']
        say(msg)
      else
        verbose(msg + "\n")
      end
    end

    ## Make things in Murano look like local project
    #
    # This creates, uploads, and deletes things as needed up in Murano to match
    # what is in the local project directory.
    #
    # @param options [Hash, Commander::Command::Options] Options on operation
    # @param selected [Array<String>] Filters for _matcher
    def syncup(options={}, selected=[])
      return 0 unless api_id?

      options = elevate_hash(options)
      options[:asdown] = false

      num_synced = 0

      syncup_before

      dt = status(options, selected)

      toadd = dt[:toadd]
      todel = dt[:todel]
      tomod = dt[:tomod]

      itemkey = @itemkey.to_sym
      todel.each do |item|
        syncup_item(item, options, :delete, 'Removing') do |aitem|
          remove_lite(aitem[itemkey], aitem.reject { |k, _v| k == :local_path }, true)
          num_synced += 1
        end
      end
      toadd.each do |item|
        syncup_item(item, options, :create, 'Adding') do |aitem|
          upload(aitem[:local_path], aitem.reject { |k, _v| k == :local_path }, false)
          num_synced += 1
        end
      end
      tomod.each do |item|
        syncup_item(item, options, :update, 'Updating') do |aitem|
          upload(aitem[:local_path], aitem.reject { |k, _v| k == :local_path }, true)
          num_synced += 1
        end
      end

      syncup_after

      MrMurano::Verbose.whirly_stop(force: true)

      num_synced
    end

    def syncup_item(item, options, action, verbage)
      if options[action]
        # It's up to the callback to check and honor $cfg['tool.dry'].
        prog_msg = "#{verbage.capitalize} item #{item[:synckey]}"
        prog_msg += " (#{item[:synctype]})" if $cfg['tool.verbose']
        sync_update_progress(prog_msg)
        yield item
      elsif $cfg['tool.verbose']
        MrMurano::Verbose.whirly_interject do
          say("--no-#{action}: Not #{verbage.downcase} item #{item[:synckey]}")
        end
      end
    end

    ## Make things in local project look like Murano
    #
    # This creates, downloads, and deletes things as needed up in the local project
    # directory to match what is in Murano.
    #
    # @param options [Hash, Commander::Command::Options] Options on operation
    # @param selected [Array<String>] Filters for _matcher
    def syncdown(options={}, selected=[])
      return 0 unless api_id?

      options = elevate_hash(options)
      options[:asdown] = true
      options[:skip_missing_warning] = true

      num_synced = 0

      syncdown_before

      dt = status(options, selected)

      toadd = dt[:toadd]
      todel = dt[:todel]
      tomod = dt[:tomod]

      into = location
      todel.each do |item|
        syncdown_item(item, into, options, :delete, 'Removing') do |dest, aitem|
          removelocal(dest, aitem)
          num_synced += 1
        end
      end
      toadd.each do |item|
        syncdown_item(item, into, options, :create, 'Adding') do |dest, aitem|
          download(dest, aitem, options: options)
          num_synced += 1
        end
      end
      tomod.each do |item|
        syncdown_item(item, into, options, :update, 'Updating') do |dest, aitem|
          download(dest, aitem, options: options)
          num_synced += 1
        end
      end
      syncdown_after(into)

      num_synced
    end

    def syncdown_item(item, into, options, action, verbage)
      if options[action]
        prog_msg = "#{verbage.capitalize} item #{item[:synckey]}"
        prog_msg += " (#{item[:synctype]})" if $cfg['tool.verbose']
        sync_update_progress(prog_msg)
        dest = tolocalpath(into, item)
        yield dest, item
      elsif $cfg['tool.verbose']
        say("--no-#{action}: Not #{verbage.downcase} item #{item[:synckey]}")
      end
    end

    ## Call external diff tool on item
    #
    # WARNING: This will download the remote item to do the diff.
    #
    # @param merged [Hash] The merged item to get a diff of
    # @param local [MrMurano::Webservice::Endpoint::RouteItem] Raw local item
    # @param there [MrMurano::Webservice::Endpoint::RouteItem] Raw remote item
    # @param asdown [Boolean] Direction/prespective of diff
    # @return [String] The diff output
    def dodiff(merged, local, _there=nil, options={})
      trmt = Tempfile.new([tolocalname(merged, @itemkey) + '_remote_', '.lua'])
      tlcl = Tempfile.new([tolocalname(merged, @itemkey) + '_local_', '.lua'])
      Pathname.new(tlcl.path).open('wb') do |io|
        # Copy the local file to a temp file, for the diff command.
        # And for resources, remove the local-only :selected key, as
        # it's not part of the remote item that gets downloaded next.
        if merged.key?(:script)
          io << config_vars_decode(merged[:script])
        else
          # For most items, read the local file.
          # For resources, it's a bit trickier.
          # NOTE: This class adds a :selected key to the local item that we need
          # to remove, since it's not part of the remote items that gets downloaded.
          local = local.reject { |k, _v| k == :selected } unless local.nil?
          diff_item_write(io, merged, local, nil)
        end
      end

      stdout_and_stderr = ''
      begin
        tmp_path = Pathname.new(trmt.path)
        diff_download(tmp_path, merged, options)

        MrMurano::Verbose.whirly_stop

        # 2017-07-03: No worries, Ruby 3.0 frozen string literals, cmd is a list.
        cmd = $cfg['diff.cmd'].shellsplit
        # ALT_SEPARATOR is the platform specific alternative separator,
        # for Windows support.
        remote_path = trmt.path.gsub(
          ::File::SEPARATOR, ::File::ALT_SEPARATOR || ::File::SEPARATOR
        )
        local_path = tlcl.path.gsub(
          ::File::SEPARATOR, ::File::ALT_SEPARATOR || ::File::SEPARATOR
        )
        if options[:asdown]
          cmd << local_path
          cmd << remote_path
        else
          cmd << remote_path
          cmd << local_path
        end

        stdout_and_stderr, _status = Open3.capture2e(*cmd)
        # How important are the first two lines of the diff? E.g.,
        #     --- /tmp/raw_data_remote_20170718-20183-gdyeg9.lua	2017-07-18 ...
        #     +++ /tmp/raw_data_local_20170718-20183-71o4me.lua	2017-07-18 ...
        # Seems like printing the path to a since-deleted temporary file is
        # misleading, so cull these lines.
        if $cfg['diff.cmd'] == 'diff' || $cfg['diff.cmd'].start_with?('diff ')
          lineno = 0
          consise = stdout_and_stderr.lines.reject do |line|
            lineno += 1
            if lineno == 1 && line.start_with?('--- ')
              true
            elsif lineno == 2 && line.start_with?('+++ ')
              true
            else
              false
            end
          end
          stdout_and_stderr = consise.join
        end
      ensure
        trmt.close
        trmt.unlink
        tlcl.close
        tlcl.unlink
      end
      stdout_and_stderr
    end

    ##
    # Check if an item matches a pattern.
    # @param items [Array<Item>] Of items to filter
    # @param patterns [Array<String>] Filters for _matcher
    def _matcher(items, patterns)
      items.map do |item|
        if patterns.empty?
          item[:selected] = true
        else
          item[:selected] = patterns.any? do |pattern|
            if pattern.to_s[0] == '#'
              match(item, pattern)
            elsif !defined?(item.local_path) || item.local_path.nil?
              into = location
              lpath = tolocalpath(into, item)
              lpath.to_s.include? pattern
            else
              item[:local_path].to_s.include? pattern
            end
          end
        end
        item
      end
    end
    private :_matcher

    ## Get status of things here verses there
    #
    # @param options [Hash, Commander::Command::Options] Options on operation
    # @param selected [Array<String>] Filters for _matcher
    # @return [Hash{Symbol=>Array<Item>}] Items grouped by the action that should be taken
    def status(options={}, selected=[])
      options = elevate_hash(options)

      ret = filter_solution(options)
      return ret unless ret.nil?

      therebox, localbox = items_lists(options, selected)

      statuses = { skipd: [] }

      items_new_and_old!(statuses, options, therebox, localbox)

      items_mods_and_chgs!(statuses, options, therebox, localbox)

      statuses.merge!(statuses) { |_key, val1, _val2| sort_by_name(val1) }

      items_cull_clashes!(statuses)

      statuses.each_value { |items| select_selected(items) } unless options[:unselected]

      statuses
    end

    def filter_solution(options)
      # Get the solution name from the config.
      # Convert, e.g., application.id => application.name
      soln_name = $cfg[@solntype.gsub(/(.*)\.id/, '\1.name')]
      # Skip this syncable if the api_id is not set, or if user wants to skip
      # by solution.
      skip_sol = false
      if !api_id? ||
         (options[:type] == :application && @solntype != 'application.id') ||
         (options[:type] == :product && @solntype != 'product.id')
        skip_sol = true
      else
        tested = false
        passed = false
        if @solntype == 'application.id'
          # elevate_hash makes the hash return false rather than
          # nil on unknown keys, so preface with a key? guard.
          if options.key?(:application) && !options[:application].to_s.empty?
            if soln_name =~ /#{Regexp.escape(options[:application])}/i ||
               api_id =~ /#{Regexp.escape(options[:application])}/i
              passed = true
            end
            tested = true
          end
          if options.key?(:application_id) && !options[:application_id].to_s.empty?
            passed = true if options[:application_id] == api_id
            tested = true
          end
          if options.key?(:application_name) && !options[:application_name].to_s.empty?
            passed = true if options[:application_name] == soln_name
            tested = true
          end
        elsif @solntype == 'product.id'
          if options.key?(:product) && !options[:product].to_s.empty?
            if soln_name =~ /#{Regexp.escape(options[:product])}/i ||
               api_id =~ /#{Regexp.escape(options[:product])}/i
              passed = true
            end
            tested = true
          end
          if options.key?(:product_id) && !options[:product_id].to_s.empty?
            passed = true if options[:product_id] == api_id
            tested = true
          end
          if options.key?(:product_name) && !options[:product_name].to_s.empty?
            passed = true if options[:product_name] == soln_name
            tested = true
          end
        end
        skip_sol = true if tested && !passed
      end
      return nil unless skip_sol
      ret = { toadd: [], todel: [], tomod: [], unchg: [], skipd: [], clash: [] }
      ret[:skipd] << { synckey: self.class.description }
      ret
    end

    def syncable_validate_api_id
      # 2017-07-02: Now that there are multiple solution types, and because
      # SyncRoot.add is called on different classes that go with either or
      # both products and applications, if a user only created one solution,
      # then some syncables will have their api_id set to -1, because there's
      # not a corresponding solution in Murano.
      raise 'Syncable missing api_id or not valid_api_id??!' unless api_id?
    end

    def items_lists(options, selected)
      # Fetch arrays of items there, and items here/local.
      there = list
      local = locallist(skip_warn: options[:skip_missing_warning])

      resolve_config_var_usage!(there, local)

      there = _matcher(there, selected)
      local = _matcher(local, selected)

      therebox = {}
      there.each do |item|
        item[:synckey] = synckey(item)
        item[:synctype] = self.class.description
        therebox[item[:synckey]] = item
      end

      localbox = {}
      local.each do |item|
        skey = synckey(item)
        # 2017-07-02: Check for local duplicates.
        unless item[:dup_count].nil? || item[:dup_count].zero?
          skey += "-#{item[:dup_count]}"
        end
        item[:synckey] = skey
        item[:synctype] = self.class.description
        localbox[skey] = item
      end

      # Some items are considered "undeletable", meaning if a
      # corresponding file does not exist locally, we assume
      # it does but is just set to the empty string.
      localbox = resurrect_undeletables(localbox, therebox)

      [therebox, localbox]
    end

    def items_new_and_old!(statuses, options, therebox, localbox)
      if options[:asdown]
        todel = (localbox.keys - therebox.keys).map { |key| localbox[key] }
        toadd = (therebox.keys - localbox.keys).map { |key| therebox[key] }
      else
        toadd = (localbox.keys - therebox.keys).map { |key| localbox[key] }
        todel = (therebox.keys - localbox.keys).map { |key| therebox[key] }
      end
      statuses[:toadd] = toadd
      statuses[:todel] = todel
    end

    def items_mods_and_chgs!(statuses, options, therebox, localbox)
      tomod = []
      unchg = []
      toadd = []
      todel = []

      (localbox.keys & therebox.keys).each do |key|
        local = localbox[key]
        there = therebox[key]
        # Skip this item if it's got duplicate conflicts.
        next if !local.is_a?(Hash) && local.dup_count == 0
        if options[:asdown]
          # Want 'there' to override 'local'.
          mrg = local.merge(there)
        else
          # Want 'local' to override 'there' except for itemkey.
          mrg = local.reject { |k, _v| k == @itemkey.to_sym }
          mrg = there.merge(mrg)
        end

        if docmp(local, there)
          if (options[:diff] || local[:phantom]) && mrg[:selected]
            mrg[:diff] = dodiff(mrg.to_h, local, there, options)
            if mrg[:diff].to_s.empty?
              debug %(Clean diff: #{local[:synckey]})
              unchg << mrg
            elsif local[:phantom]
              if options[:asdown]
                toadd << mrg
              else
                todel << mrg
              end
              localbox.delete(key)
            else
              tomod << mrg
            end
          else
            tomod << mrg
          end
        else
          unchg << mrg
        end
      end

      statuses[:tomod] = tomod
      statuses[:unchg] = unchg
      statuses[:toadd] += toadd
      statuses[:todel] += todel
    end

    def sort_by_name(list)
      if list.any? && list.first.is_a?(Hash)
        # AFAIK, only SyncUpDown_spec.rb comes through here, because
        # it does not use SyncUpDown::Item but mocks its own items
        # using hashes (see calls to and_return). [lb]
        list.sort_by { |hsh| hsh[:name] }
      else
        list.sort_by(&:name)
      end
    end

    def select_selected(items)
      items.select! { |i| i[:selected] }
      items.map { |i| i.delete(:selected); i }
    end

    def items_cull_clashes!(statuses)
      clash = []
      statuses.each_value do |items|
        items.select! do |item|
          if item[:dup_count].nil?
            true
          elsif item[:dup_count].zero?
            # This is the control item.
            false
          else
            clash.push(item)
            false
          end
        end
      end
      statuses[:clash] = clash
    end
  end
end


# Last Modified: 2017.07.31 /coding: utf-8
# frozen_string_literal: true

# Copyright © 2016-2017 Exosite LLC.
# License: MIT. See LICENSE.txt.
#  vim:tw=0:ts=2:sw=2:et:ai

# FIXME/MAYBE: Fix semicolon usage.
# rubocop:disable Style/Semicolon

require 'open3'
require 'pathname'
#require 'shellwords'
require 'tempfile'
require 'MrMurano/progress'
require 'MrMurano/verbosing'
#require 'MrMurano/hash'
#require 'MrMurano/Config'
#require 'MrMurano/ProjectFile'
##require 'MrMurano/SyncRoot'

module MrMurano
  ## The functionality of a Syncable thing.
  #
  # This provides the logic for computing what things have changed, and pushing and
  # pulling those things.
  #
  module SyncUpDown
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
      # @return [String] For device2, the event type.
      attr_accessor :type
      # @return [String] For testing, the updated_at time the server would otherwise indicate.
      attr_accessor :updated_at
      # @return [Integer] Non-nil if multiple conflicting files found for same item.
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
      end

      # Set attribute as if this was a Hash
      # @param key [String,Symbol] attribute name
      # @param value [Object] value to set
      def []=(key, value)
        public_send("#{key}=", value)
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
    def download(local, item)
#      if item[:bundled]
#        warning "Not downloading into bundled item #{synckey(item)}"
#        return
#      end
      local.dirname.mkpath
      id = item[@itemkey.to_sym]
      if id.nil?
        debug "!!! Missing '#{@itemkey}', using :id instead!"
        debug ":id => #{item[:id]}"
        id = item[:id]
        raise "Both #{@itemkey} and id in item are nil!" if id.nil?
      end
      local.open('wb') do |io|
        fetch(id) do |chunk|
          io.write chunk
        end
      end
      update_mtime(local, item)
    end

    def diff_download(tmp_path, merged)
      download(tmp_path, merged)
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

      mod_time = DateTime.parse(item[:updated_at]).to_time
      begin
        FileUtils.touch([local.to_path], mtime: mod_time)
      rescue Errno::EACCES => err
        # This happens on Windows...
        require 'rbconfig'
        # Check the platform, e.g., "linux-gnu", or other.
        is_windows = (RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/)
        unless is_windows
          $stderr.puts(
            "Unexpected: touch failed on non-Windows machine / host_os: #{RbConfig::CONFIG['host_os']} / err: #{err}"
          )
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
      dest.unlink if dest.exist?
    end

    def syncup_before
    end

    def syncup_after
    end

    def syncdown_before
    end

    def syncdown_after(_local)
    end

    def diff_item_write(io, merged, _local, _remote)
      io << merged[:local_path].read
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
        # 2017-07-02: Argh. If two files have the same identity, this
        # simple loop masks that there are two files with the same identity!
        #bitems.each { |b| items[synckey(b)] = b }
        warns = {}
        bitems.each do |item|
          skey = synckey(item)
          if items.key? skey
            warns[skey] = 0 unless warns.key?(skey)
            if warns[skey].zero?
              items[skey][:dup_count] = warns[skey]
              # The dumb_synckey is just so we don't overwrite the
              # original item, or other duplicates, in the hash.
              dumb_synckey = "#{skey}-#{warns[skey]}"
              # This just sets the alias for the output, so duplicates look unique.
              item[@itemkey.to_sym] = dumb_synckey
              # Don't delete the original item, so that other dupes see it.
              #items.delete(skey)
              msg = "Duplicate local file(s) found for ‘#{skey}’"
              msg += " for ‘#{self.class.description}’" if self.class.description.to_s != ''
              #msg += '!'
              warning(msg)
            end
            warns[skey] += 1
            item[:dup_count] = warns[skey]
            dumb_synckey = "#{skey}-#{warns[skey]}"
            item[@itemkey.to_sym] = dumb_synckey
            items[dumb_synckey] = item
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
          #     Skipping missing location ‘/tmp/d20170731-3150-1f50uj4/project/specs/resources.yaml’ (Resources)
          #   but then later in the syncdown, that directory and file gets created.
          msg = "Skipping missing location ‘#{location}’"
          msg += " (#{self.class.description})" unless self.class.description.to_s.empty?
          warning(msg)
          @missing_complaints << location
        end
      end
      items.values
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
      debug "#{self.class}: Getting local items from: #{from}"
      search_in = from.to_s
      sf = searchFor.map { |i| ::File.join(search_in, i) }
      debug "#{self.class}: Globs: #{sf}"
      # 2017-07-27: Add uniq to cull duplicate entries that globbing
      # all the ways might produce, otherwise status/sync/diff complain
      # about duplicate resources. I [lb] think this problem has existed
      # but was exacerbated by the change to support sub-directory scripts.
      items = Dir[*sf].uniq.flatten.compact.reject do |p|
        ::File.directory?(p) || ignoring.any? do |i|
          ::File.fnmatch(i, p)
        end
      end
      items = items.map do |path|
        path = Pathname.new(path).realpath
        item = to_remote_item(from, path)
        if item.is_a?(Array)
          item.compact.map { |i| i[:local_path] = path; i }
        elsif !item.nil?
          item[:local_path] = path
          item
        end
      end
      items.flatten.compact
    end

    #######################################################################
    # Methods that provide the core status/syncup/syncdown

    ##
    # Take a hash or something (a Commander::Command::Options) and return a hash
    #
    # @param hsh [Hash, Commander::Command::Options] Thing we want to be a Hash
    # @return [Hash] an actual Hash with default value of false
    def elevate_hash(hsh)
      # Commander::Command::Options stripped all of the methods from parent
      # objects. I have not nice thoughts about that.
      begin
        hsh = hsh.__hash__
      # rubocop:disable Lint/HandleExceptions: Do not suppress exceptions.
      rescue NoMethodError
        # swallow this.
      end
      # build a hash where the default is 'false' instead of 'nil'
      Hash.new(false).merge(Hash.transform_keys_to_symbols(hsh))
    end
    private :elevate_hash

    def sync_update_progress(msg)
      if $cfg['tool.no-progress']
        say(msg)
      else
        MrMurano::Verbose.verbose(msg + "\n")
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
      options = elevate_hash(options)
      options[:asdown] = false

      num_synced = 0

      dt = status(options, selected)

      toadd = dt[:toadd]
      todel = dt[:todel]
      tomod = dt[:tomod]

      itemkey = @itemkey.to_sym
      todel.each do |item|
        syncup_item(item, options, :delete, 'Removing') do |aitem|
          remove(aitem[itemkey])
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
        if !$cfg['tool.dry']
          prog_msg = "#{verbage.capitalize} item #{item[:synckey]}"
          prog_msg += " (#{item[:synctype]})" if $cfg['tool.verbose']
          sync_update_progress(prog_msg)
          yield item
        else
          MrMurano::Verbose.whirly_interject do
            say("--dry: Not #{verbage.downcase} item #{item[:synckey]}")
          end
        end
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
      options = elevate_hash(options)
      options[:asdown] = true
      options[:skip_missing_warning] = true

      num_synced = 0

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
          download(dest, aitem)
          num_synced += 1
        end
      end
      tomod.each do |item|
        syncdown_item(item, into, options, :update, 'Updating') do |dest, aitem|
          download(dest, aitem)
          num_synced += 1
        end
      end
      syncdown_after(into)

      num_synced
    end

    def syncdown_item(item, into, options, action, verbage)
      if options[action]
        if !$cfg['tool.dry']
          prog_msg = "#{verbage.capitalize} item #{item[:synckey]}"
          prog_msg += " (#{item[:synctype]})" if $cfg['tool.verbose']
          sync_update_progress(prog_msg)
          dest = tolocalpath(into, item)
          yield dest, item
        else
          say("--dry: Not #{verbage.downcase} item #{item[:synckey]}")
        end
      elsif $cfg['tool.verbose']
        say("--no-#{action}: Not #{verbage.downcase} item #{item[:synckey]}")
      end
    end

    ## Call external diff tool on item
    #
    # WARNING: This will download the remote item to do the diff.
    #
    # @param merged [merged] The merged item to get a diff of
    # @local local, unadulterated (non-merged) item
    # @return [String] The diff output
    def dodiff(merged, local, asdown=false)
      trmt = Tempfile.new([tolocalname(merged, @itemkey) + '_remote_', '.lua'])
      tlcl = Tempfile.new([tolocalname(merged, @itemkey) + '_local_', '.lua'])
      Pathname.new(tlcl.path).open('wb') do |io|
        if merged.key?(:script)
          io << merged[:script]
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
        diff_download(tmp_path, merged)

        MrMurano::Verbose.whirly_stop

        # 2017-07-03: No worries, Ruby 3.0 frozen string literals, cmd is a list.
        cmd = $cfg['diff.cmd'].shellsplit
        remote_path = trmt.path.gsub(
          ::File::SEPARATOR, ::File::ALT_SEPARATOR || ::File::SEPARATOR
        )
        local_path = tlcl.path.gsub(
          ::File::SEPARATOR, ::File::ALT_SEPARATOR || ::File::SEPARATOR
        )
        if asdown
          cmd << local_path
          cmd << remote_path
        else
          cmd << remote_path
          cmd << local_path
        end

        stdout_and_stderr, _status = Open3.capture2e(*cmd)
        # How important are the first two lines of the diff? E.g.,
        #     --- /tmp/raw_data_remote_20170718-20183-gdyeg9.lua	2017-07-18 13:13:13.864051905 -0500
        #     +++ /tmp/raw_data_local_20170718-20183-71o4me.lua	2017-07-18 13:13:14.520049397 -0500
        # Seems like printing the path to a since-deleted temporary file is misleading.
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
              false
            else
              item[:local_path].fnmatch(pattern)
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

      # 2017-07-02: Now that there are multiple solution types, and because
      # SyncRoot.add is called on different classes that go with either or
      # both products and applications, if a user only created one solution,
      # then some syncables will have their sid set to -1, because there's
      # not a corresponding solution in Murano.
      raise 'Syncable missing sid or not valid_sid??!' unless sid?

      if options[:asdown]
        syncdown_before
      else
        syncup_before
      end

      itemkey = @itemkey.to_sym

      # Fetch arrays of items there, and items here/local.
      there = list
      there = _matcher(there, selected)
      local = locallist(skip_warn: options[:skip_missing_warning])
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
        skey += "-#{item[:dup_count]}" unless item[:dup_count].nil?
        item[:synckey] = skey
        item[:synctype] = self.class.description
        localbox[item[:synckey]] = item
      end
      toadd = []
      todel = []
      tomod = []
      unchg = []
      if options[:asdown]
        todel = (localbox.keys - therebox.keys).map { |key| localbox[key] }
        toadd = (therebox.keys - localbox.keys).map { |key| therebox[key] }
      else
        toadd = (localbox.keys - therebox.keys).map { |key| localbox[key] }
        todel = (therebox.keys - localbox.keys).map { |key| therebox[key] }
      end
      (localbox.keys & therebox.keys).each do |key|
        # Want 'local' to override 'there' except for itemkey.
        if options[:asdown]
          mrg = therebox[key].reject { |k, _v| k == itemkey }
          mrg = localbox[key].merge(mrg)
        else
          mrg = localbox[key].reject { |k, _v| k == itemkey }
          mrg = therebox[key].merge(mrg)
        end
        if docmp(localbox[key], therebox[key])
          if options[:diff] && mrg[:selected]
            mrg[:diff] = dodiff(mrg.to_h, localbox[key], options[:asdown])
            mrg[:diff] = '<Nothing changed (may be timestamp difference?)>' if mrg[:diff].empty?
          end
          tomod << mrg
        else
          unchg << mrg
        end
      end
      if options[:unselected]
        { toadd: toadd, todel: todel, tomod: tomod, unchg: unchg, skipd: [] }
      else
        {
          toadd: toadd.select { |i| i[:selected] }.map { |i| i.delete(:selected); i },
          todel: todel.select { |i| i[:selected] }.map { |i| i.delete(:selected); i },
          tomod: tomod.select { |i| i[:selected] }.map { |i| i.delete(:selected); i },
          unchg: unchg.select { |i| i[:selected] }.map { |i| i.delete(:selected); i },
          skipd: [],
        }
      end
    end
  end
end


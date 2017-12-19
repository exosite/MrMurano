# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

require 'inflecto'
require 'os'
require 'pathname'
require 'time'
require 'MrMurano/verbosing'
require 'MrMurano/SyncAllowed'
require 'MrMurano/SyncUpDown-Core'
require 'MrMurano/SyncUpDown-Item'

module MrMurano
  ## The functionality of a Syncable thing.
  #
  # This provides the logic for computing what things have changed,
  # and pushing and pulling those things.
  module SyncUpDown
    include SyncAllowed
    include SyncCore

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
          debug %(Missing id: remote: #{item[:name]} / local: #{local} / item: #{item})
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
      0
    end

    def syncdown_before
      syncable_validate_api_id
    end

    def syncdown_after(_local)
      0
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
    # 2017-07-02: [lb] removed this commented-out code from locallist body.
    #   See "Bundles" comments in TODO.taskpaper.
    #   This code builds the list of local items from all bundle
    #   subdirectories. Would that be how a bundles implementation
    #   works? Or would we rather just iterate over each bundle and
    #   process them separately, rather than all together at once?
    #
    #    def locallist
    #      # so. if @locationbase/bundles exists
    #      #  gather and merge: @locationbase/bundles/*/@location
    #      # then merge @locationbase/@location
    #      #
    #      bundleDir = $cfg['location.bundles'] or 'bundles'
    #      bundleDir = 'bundles' if bundleDir.nil?
    #      items = {}
    #      if (@locationbase + bundleDir).directory?
    #        (@locationbase + bundleDir).children.sort.each do |bndl|
    #          if (bndl + @location).exist?
    #            verbose("Loading from bundle #{bndl.basename}")
    #            bitems = localitems(bndl + @location)
    #            bitems.map!{|b| b[:bundled] = true; b} # mark items from bundles.
    #            # use synckey for quicker merging.
    #            bitems.each { |b| items[synckey(b)] = b }
    #          end
    #        end
    #      end
    #    end
    #
    def locallist(skip_warn: false)
      items = {}
      if location.exist?
        # Get a list of SyncUpDown::Item's, or a class derived thereof.
        bitems = localitems(location)
        # Check for duplicates first -- two files with the same identity.
        seen = locallist_mark_seen(bitems)
        counts = {}
        bitems.each do |item|
          locallist_add_item(item, items, seen, counts)
        end
      elsif !skip_warn
        locallist_complain_missing
      end
      items.values
    end

    def locallist_mark_seen(bitems)
      seen = {}
      bitems.each do |item|
        skey = synckey(item)
        seen[skey] = seen.key?(skey) && seen[skey] + 1 || 1
      end
      seen
    end

    def locallist_add_item(item, items, seen, counts)
      skey = synckey(item)
      if seen[skey] > 1
        if items[skey].nil?
          items[skey] = item.clone
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

    def locallist_complain_missing
      @missing_complaints = [] unless defined?(@missing_complaints)
      return if @missing_complaints.include?(location)
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

    # Some items are considered "undeletable", meaning if a corresponding
    # file does not exist locally, or if the user deletes such a file, we
    # do not delete it on the server, but instead set it to the empty string.
    # The reverse is also true: if a service script on the platform is empty,
    # we do not need to create a file for it locally.
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
          ignoring.any? { |pattern| ignore?(path, pattern) }
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
          item.compact.map do |itm|
            itm[:local_path] = rpath
            itm
          end
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
  end
end


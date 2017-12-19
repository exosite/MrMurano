# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

require 'open3'
require 'pathname'
require 'tempfile'
require 'MrMurano/verbosing'
require 'MrMurano/hash'

module MrMurano
  module SyncCore
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
      num_synced += syncdown_after(into)

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
            else
              lpath = _matcher_local_path(item)
              _matcher_check_pattern(lpath, pattern)
            end
          end
        end
        item
      end
    end
    private :_matcher

    def _matcher_local_path(item)
      if !defined?(item.local_path) || item.local_path.nil?
        into = location
        tolocalpath(into, item)
      else
        item[:local_path]
      end
    end
    private :_matcher_local_path

    def _matcher_check_pattern(lpath, pattern)
      # If the user quoted their search, do not try globbing it.
      strict = true if pattern =~ /^(['"]).*\1$/
      # Remove the strict quotes, if present.
      pattern = pattern.gsub(/^['"]|['"]$/, '') if strict
      # Note that fnmatch won't match part of the path without *globbing*.
      # E.g., pattern=file won't match /my/mfile, but pattern=*file will.
      return true if lpath.fnmatch? pattern
      return false if strict
      # Be nice and try globbing the start of the path. E.g., if user
      # specifies pattern=relative/path/to/file.rb, we should retry their
      # request as */relative/path/to/file.rb. But don't glob if it looks
      # like the user is already globbing or using absolutes.
      return false if pattern.to_s.start_with?(File::SEPARATOR)
      # See if the pattern includes any '*' that are not \-delimited.
      return false if pattern.to_s =~ /(?<!\\)\*/
      lpath.fnmatch? "*/#{pattern}"
    end
    private :_matcher_check_pattern

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
          if (options[:diff] || local[:phantom] || local[:undeletable]) && mrg[:selected]
            mrg[:diff] = dodiff(mrg.to_h, local, there, options)
            if mrg[:diff].to_s.empty?
              debug %(Clean diff: #{local[:synckey]})
              mrg[:diff] = '<Nothing changed (was timestamp difference)>'
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
      items.select! { |item| item[:selected] }
      items.map do |item|
        item.delete(:selected)
        item
      end
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


# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

require 'abbrev'
require 'cgi'
require 'digest/sha1'
require 'json'
require 'net/http'
require 'pathname'
require 'time'
require 'uri'
require 'yaml'
require 'MrMurano/progress'
require 'MrMurano/Solution'
require 'MrMurano/SyncRoot'

module MrMurano
  ##
  # Things that servers do that is common.
  class ServiceBase < SolutionBase
    def initialize(api_id=nil)
      super
    end

    def mkalias(_remote)
      # :nocov:
      raise 'Needs to be implemented in child'
      # :nocov:
    end

    def mkname(_remote)
      # :nocov:
      raise 'Needs to be implemented in child'
      # :nocov:
    end

    def fetch(name)
      raise 'Missing name!' if name.nil?
      raise 'Empty name!' if name.empty?
      ret = get('/' + CGI.escape(name))
      unless ret.is_a?(Hash) && !ret.key?(:error)
        error "#{UNEXPECTED_TYPE_OR_ERROR_MSG}: #{ret}"
        ret = {}
      end
      if block_given?
        yield (ret[:script] || '')
      else
        ret[:script] || ''
      end
    end

    # ??? remove
    def remove(name)
      return unless remove_item_allowed(name)
      delete('/' + name)
    end

    def remove_lite(_name, item, modify=false)
      # This is a :phantom item, which has a default script, e.g.,
      #   item[:script] => "--#EVENT timer timer\n"
      localpath = tolocalpath(location, item)
      item[:script] = ''
      upload(localpath, item, modify)
    end

    # @param modify Bool: True if item exists already and this is changing it
    def upload(localpath, thereitem, _modify=false)
      localpath = Pathname.new(localpath) unless localpath.is_a?(Pathname)
      if localpath.exist?
        # we assume these are small enough to slurp.
        script = localpath.read
      else
        # I.e., thereitem.phantom, an "undeletable" file that does not
        # exist locally but should not be deleted from server.
        # MAYBE/2017-09-07: Honor options.ignore_errors here?
        raise "no file at #{localpath}" unless thereitem.script
        script = thereitem.script
      end

      script = config_vars_decode(script)

      localpath = Pathname.new(localpath) unless localpath.is_a?(Pathname)
      name = mkname(thereitem)
      pst = thereitem.to_h.merge(
        #solution_id: $cfg[@solntype],
        solution_id: @api_id,
        script: script,
        alias: mkalias(thereitem),
        name: name,
      )
      debug "f: #{localpath} >> #{pst.reject { |k, _| k == :script }.to_json}"
      therealias = mkalias(thereitem)
      upload_script(therealias, name, localpath, pst)
    end

    def upload_script(therealias, name, localpath, pst)
      # Try PUT. If 404, then POST.
      # I.e., PUT if not exists, else POST to create.
      updated_at = nil

      return unless upload_item_allowed(therealias)

      put('/' + therealias, pst) do |request, http|
        response = http.request(request)
        isj, jsn = isJSON(response.body)
        # ORDER: An HTTPNoContent is also a HTTPSuccess, so the latter comes first.
        # EXPLAIN: How come `case response ... when Net:HTTPNoContent` works?
        #   It seems magical, since response is a class and here we use is_a?.
        if response.is_a?(Net::HTTPNoContent)
          # 2017-08-07: When did Murano start returning 204?
          #   This seems to happen when updating an existing service.
          #   Unfortunately, we don't get the latest updated_at, so
          #   a subsequent status will show this module as dirty.
          ret = get('/' + CGI.escape(name))
          if ret.is_a?(Hash) && ret.key?(:updated_at)
            updated_at = ret[:updated_at]
          else
            warning "Failed to verify updated_at: #{ret}"
          end
        elsif response.is_a?(Net::HTTPSuccess)
          # A first upload will see a 200 response and a JSON body.
          # A subsequent upload of the same item sees 204 and no body.
          #return JSON.parse(response.body)
          # MAYBE/EXPLAIN: Spit out error if no JSON, or explain why it's okay.
          updated_at = jsn[:updated_at] unless jsn.nil?
        elsif response == Net::HTTPNotFound
          verbose "Doesn't exist, creating"
          post('/', pst)
        else
          relpath = localpath.sub(File.join(Dir.pwd, ''), '')
          if response.is_a?(Net::HTTPBadRequest) && isj && jsn[:message] == 'Validation errors'
            warning "Validation errors detected in #{relpath}:"
            puts MrMurano::Pretties.makeJsonPretty(jsn[:errors], Struct.new(:pretty).new(true))
          else
            showHttpError(request, response)
          end
          warning "Failed to upload: #{relpath}"
        end
      end
      cache_update_time_for(localpath, updated_at)
    end

    def docmp(item_a, item_b)
      if item_a[:updated_at].nil? && item_a[:local_path]
        ct = cached_update_time_for(item_a[:local_path])
        item_a[:updated_at] = ct unless ct.nil?
        # The item might not exist if it was resurrected (item.phantom).
        if ct.nil? && item_a[:local_path].exist?
          item_a[:updated_at] = item_a[:local_path].mtime.getutc
        end
      elsif item_a[:updated_at].is_a?(String)
        item_a[:updated_at] = Time.parse(item_a[:updated_at]).utc
      end
      if item_b[:updated_at].nil? && item_b[:local_path]
        ct = cached_update_time_for(item_b[:local_path])
        item_b[:updated_at] = ct unless ct.nil?
        if ct.nil? && item_b[:local_path].exist?
          item_b[:updated_at] = item_b[:local_path].mtime.getutc
        end
      elsif item_b[:updated_at].is_a?(String)
        item_b[:updated_at] = Time.parse(item_b[:updated_at]).utc
      end
      return false if item_a[:updated_at].nil? && item_b[:updated_at].nil?
      return true if item_a[:updated_at].nil? && !item_b[:updated_at].nil?
      return true if !item_a[:updated_at].nil? && item_b[:updated_at].nil?
      item_a[:updated_at].to_time.round != item_b[:updated_at].to_time.round
    end

    def dodiff(merged, local, there, asdown=false)
      mrg_diff = super
      if mrg_diff.empty?
        mrg_diff = '<Nothing changed (was timestamp difference)>'
        # FIXME/2017-08-08: This isn't exactly working: setting mtime...
        cache_update_time_for(local.local_path, there.updated_at)
      end
      mrg_diff
    end

    def cache_file_name
      [
        'cache',
        self.class.to_s.gsub(/\W+/, '_'),
        @api_id,
        'yaml',
      ].join('.')
    end

    def cache_update_time_for(local_path, time=nil)
      if time.nil?
        time = Time.now.utc
      elsif time.is_a?(String)
        time = Time.parse(time)
      end
      file_hash = local_path_file_hash(local_path)
      entry = {
        sha1: file_hash,
        updated_at: time.iso8601(3),
      }
      cache_file = $cfg.file_at(cache_file_name)
      if cache_file.file?
        cache_file.open('r+') do |io|
          cache = YAML.load(io)
          cache ||= {}
          io.rewind
          cache[local_path.to_s] = entry
          io << cache.to_yaml
        end
      else
        cache_file.open('w') do |io|
          cache = {}
          cache[local_path.to_s] = entry
          io << cache.to_yaml
        end
      end
      time
    end

    def cached_update_time_for(local_path)
      cksm = local_path_file_hash(local_path)
      cache_file = $cfg.file_at(cache_file_name)
      return nil unless cache_file.file?
      ret = nil
      cache_file.open('r') do |io|
        cache = YAML.load(io)
        return nil unless cache
        if cache.key?(local_path.to_s)
          entry = cache[local_path.to_s]
          debug("For #{local_path}:")
          debug(" cached: #{entry}")
          debug(" cm: #{cksm}")
          if entry.is_a?(Hash)
            if entry[:sha1] == cksm && entry.key?(:updated_at)
              ret = Time.parse(entry[:updated_at])
            end
          end
        end
      end
      ret
    end

    def local_path_file_hash(local_path)
      if local_path.exist?
        Digest::SHA1.file(local_path.to_s).hexdigest
      else
        # For item.phantom. Return the empty string, hashed:
        #   da39a3ee5e6b4b0d3255bfef95601890afd80709
        Digest::SHA1.hexdigest('')
        # MAYBE: Pass in the item and check for item.script?
      end
    end
  end

  # What Murano calls "Modules". Snippets of Lua code.
  class Module < ServiceBase
    # Module Specific details on an Item
    class ModuleItem < Item
      # @return [String] Internal Alias name
      attr_accessor :alias
      # @return [String] Timestamp when this was updated.
      attr_accessor :updated_at
      # @return [String] Timestamp when this was created.
      attr_accessor :created_at
      # @return [String] The application solution's ID.
      attr_accessor :solution_id
    end

    def initialize(api_id=nil)
      @solntype = 'application.id'
      super
      @uriparts << :module
      @itemkey = :alias
      @project_section = :modules
    end

    def self.description
      # MAYBE/2017-07-31: Rename to "Script Modules", per Renaud's suggestion? [lb]
      %(Module)
    end

    def tolocalname(item, _key)
      name = item[:name]
      # Nested Lua support: the platform dot-delimits modules in a require.
      name = File.join(name.split('.')) unless $cfg['modules.no-nesting']
      # NOTE: On syncup, user can specify file extension (or use * glob),
      # but on syncdown, the ".lua" extension is hardcoded (here).
      "#{name}.lua"
    end

    def mkalias(remote)
      raise "Missing parts! #{remote.to_h.to_json}" if remote.name.nil?
      #[$cfg[@solntype], remote[:name]].join('_')
      [@api_id, remote[:name]].join('_')
    end

    def mkname(remote)
      raise "Missing parts! #{remote.to_h.to_json}" if remote.name.nil?
      remote[:name]
    end

    def list
      ret = get
      return [] unless ret.is_a?(Hash) && !ret.key?(:error)
      return [] unless ret.key?(:items)
      ret[:items].map { |i| ModuleItem.new(i) }
      # MAYBE/2017-08-17:
      #   ret[:items].map!
      #   sort_by_name(ret[:items])
    end

    def to_remote_item(root, path)
      if $cfg['modules.no-nesting']
        name = path.basename.to_s.sub(/\..*/, '')
      else
        name = remote_item_nested_name(root, path)
      end
      ModuleItem.new(name: name)
    end

    def remote_item_nested_name(root, path)
      # 2017-07-26: Nested Lua support.
      root = root.expand_path
      if path.basename.sub(/\.lua$/i, '').to_s.include?('.')
        warning(
          "WARNING: Do not use periods in filenames. Rename: #{fancy_ticks(path.basename)}"
        )
      end
      path.dirname.ascend do |ancestor|
        break if ancestor == root
        if ancestor.basename.to_s.include?('.')
          warning(
            "WARNING: Do not use periods in directory names. Rename: #{fancy_ticks(ancestor.basename)}"
          )
        end
      end
      relpath = path.relative_path_from(root).to_s
      # MAYBE: Use ALT_SEPARATOR to support Windows?
      #   ::File::ALT_SEPARATOR || ::File::SEPARATOR
      #relpath.sub(/\..*$/, '').tr(::File::SEPARATOR, '.')
      relpath.sub(/\.lua$/i, '').tr(::File::SEPARATOR, '.')
    end

    def synckey(item)
      item[:name]
    end
  end
  SyncRoot.instance.add('modules', Module, 'M', true)

  # Services aka EventHandlers
  class EventHandler < ServiceBase
    # EventHandler Specific details on an Item
    class EventHandlerItem < Item
      # @return [String] Internal Alias name
      attr_accessor :alias
      # @return [String] Timestamp when this was updated.
      attr_accessor :updated_at
      # @return [String] Timestamp when this was created.
      attr_accessor :created_at
      # @return [String] The soln's product.id or application.id (Murano's api_id).
      attr_accessor :solution_id
      # @return [String] Which service triggers this script.
      attr_accessor :service
      # @return [String] Which event triggers this script.
      attr_accessor :event
      # @return [String] For device2 events, the type of event.
      attr_accessor :type
      # @return [String] Service alias, e.g., "{product.id}"
      attr_accessor :svc_alias
      # @return [Boolean] True if local phantom item via eventhandler.undeletable.
      #                   I.e., the file does not exist locally and is the
      #                   empty string on the server, so locally considered
      #                   empty string, too.
      attr_accessor :phantom
    end

    def initialize(api_id=nil)
      super
      @uriparts << :eventhandler
      @itemkey = :alias
      #@project_section = :services
      raise 'Subclass missing @project_section' unless @project_section
      @match_header = /--#EVENT (?<service>\S+) (?<event>\S+)/
    end

    def mkalias(remote)
      raise "Missing parts! #{remote.to_h.to_json}" if remote.service.nil? || remote.event.nil?
      #[$cfg[@solntype], remote[:service], remote[:event]].join('_')
      [@api_id, remote[:service], remote[:event]].join('_')
    end

    def mkname(remote)
      raise "Missing parts! #{remote.to_h.to_json}" if remote.service.nil? || remote.event.nil?
      [remote[:service], remote[:event]].join('_')
    end

    def synckey(item)
      "#{item[:service]}_#{item[:event]}"
    end

    def list(call=nil, data=nil, &block)
      ret = get(call, data, &block)
      return [] unless ret.is_a?(Hash) && !ret.key?(:error)
      return [] unless ret.key?(:items)
      # eventhandler.skiplist is a list of whitespace separated dot-paired values.
      # fe: service.event service service service.event
      skiplist = ($cfg['eventhandler.skiplist'] || '').split
      items = ret[:items].reject do |item|
        toss = skip?(item, skiplist)
        debug "skiplist excludes: #{item[:service]}.#{item[:event]}" if toss
        toss
      end
      items.map { |item| EventHandlerItem.new(item) }
      # MAYBE/2017-08-17:
      #   items.map! ...
      #   sort_by_name(items)
    end

    def resolve_config_var_usage!(there, local)
      # Substitute '{product.id}' for the actual product.id if a corresponding
      # local file does not exist, or if the local file already uses the alias.
      encode_items = {}
      local.each do |item|
        encode_items[item.service] = {} if encode_items[item.service].nil?
        encode_items[item.service][item.event] = item.svc_alias
      end
      there.map! do |item|
        if (
          !encode_items[item.service].nil? &&
          !encode_items[item.service][item.event].nil?
        )
          svc_alias = encode_items[item.service][item.event]
        else
          # There's no corresponding local item.
          _encoded, svc_alias = encode_config_var(item.service)
        end
        svc_alias = nil if svc_alias == item.service
        unless svc_alias.nil?
          item.svc_alias = svc_alias
          item.name.sub!($cfg[svc_alias], "{#{svc_alias}}")
        end
        item
      end
    end

    def skip?(item, skiplist)
      return false unless item.key?(:service) && item.key?(:event)
      skiplist.any? do |svc_evt|
        cmp_svc_evt(item, svc_evt)
      end
    end

    def cmp_svc_evt(item, svc_evt)
      service, event = svc_evt.split('.', 2)
      svc_match = (
        service == item[:service] ||
        (!item[:svc_alias].to_s.empty? && service == item[:svc_alias])
      )
      if event.nil? || item[:event] == '*'
        svc_match
      else
        # rubocop:disable Style/IfInsideElse
        #svc_evt == "#{item[:service]}.#{item[:event]}"
        if service == '*'
          event == item[:event]
        else
          svc_match && event == item[:event]
        end
      end
    end

    def fetch(name)
      ret = get('/' + CGI.escape(name))
      unless ret.is_a?(Hash) && !ret.key?(:error)
        error "Fetch for #{name} returned nil or error; skipping"
        return ''
      end
      aheader = (ret[:script].lines.first || '').chomp
      dheader = "--#EVENT #{ret[:service]} #{ret[:event]}"
      if block_given?
        yield dheader + "\n" if aheader != dheader
        yield ret[:script]
      else
        # 2017-07-02: Changing shovel operator << to +=
        # to support Ruby 3.0 frozen string literals.
        res = ''
        res += dheader + "\n" if aheader != dheader
        res += ret[:script]
        res
      end
    end

    def default_event_script(service_or_api_id, &block)
      post(
        '/',
        {
          solution_id: @api_id,
          service: service_or_api_id,
          event: 'event',
          script: 'print(event)',
        },
        &block
      )
    end

    def tolocalname(item, _key)
      "#{item[:name]}.lua"
    end

    def to_remote_item(from, path)
      # This allows multiple events to be in the same file. This is a lie.
      # This only finds the last event in a file.
      # :legacy support doesn't allow for that. But that's ok.
      path = Pathname.new(path) unless path.is_a?(Pathname)
      cur = nil
      lineno = 0
      path.readlines.each do |line|
        # @match_header finds a service and an event string, e.g., "--EVENT svc evt\n"
        md = @match_header.match(line)
        if !md.nil?
          service, config_var = decode_config_var(md[:service])
          event_event, event_type = resolve_event_type(service, md[:event])
          # Header line.
          svc_alias = config_var if service != md[:service]
          cur = EventHandlerItem.new(
            #name
            local_path: path,
            #id
            script: line,
            line: lineno,
            #line_end
            #diff
            #selected
            #synckey
            #synctype
            #type
            #updated_at
            #dup_count
            #alias
            #updated_at
            #created_at
            #solution_id
            service: service,
            event: event_event,
            type: event_type,
            #phantom
            svc_alias: svc_alias,
          )
        elsif !cur.nil? && !cur[:script].nil?
          # 2017-07-02: Frozen string literal: change << to +=
          cur[:script] += line
        end
        lineno += 1
      end
      cur[:line_end] = lineno unless cur.nil?

      # If cur is nil here, then we need to do a :legacy check.
      to_remote_item_legacy_check(cur, path, from, lineno)
    end

    def to_remote_item_legacy_check(cur, path, from, lineno)
      return cur unless cur.nil? && $project['services.legacy'].is_a?(Hash)
      spath = path.relative_path_from(from)
      debug "No headers: #{spath}"
      service, event = $project['services.legacy'][spath.to_s]
      debug "Legacy lookup #{spath} => [#{service}, #{event}]"
      unless service.nil? || event.nil?
        warning %(Event in #{spath} missing header, but has legacy support.)
        warning %(Please add the header "--#EVENT #{service} #{event}")
        cur = EventHandlerItem.new(
          service: service,
          event: event,
          type: nil,
          local_path: path,
          line: 0,
          line_end: lineno,
          script: path.read, # FIXME: ick, fix this.
        )
      end
      cur
    end

    def match(item, pattern)
      # Pattern is: #{service}#{event}
      pattern_pattern = /^#(?<service>[^#]*)#(?<event>.*)/i
      md = pattern_pattern.match(pattern)
      return false if md.nil?
      debug "match pattern: '#{md[:service]}' '#{md[:event]}'"
      if (
        !md[:service].empty? &&
        !item[:service].casecmp(md[:service]).zero? &&
        (item[:svc_alias].to_s.empty? || !item[:svc_alias].casecmp(md[:service]).zero?)
      )
        return false
      end
      return false unless md[:event].empty? || item[:event].casecmp(md[:event]).zero?
      true # Both match (or both empty).
    end

    def config_vars_decode(script)
      config_vars_translate(script, method(:decode_config_var))
    end

    def config_vars_encode(script)
      config_vars_translate(script, method(:encode_config_var))
    end

    def config_vars_translate(script, codec)
      new_script = ''
      # Replace the service with a {config.variable} if appropriate.
      script.lines.each do |line|
        # @match_header finds a service and an event string, e.g., "--EVENT svc evt\n"
        md = @match_header.match(line)
        unless md.nil?
          service, _config_var = codec.call(md[:service])
          line = line.gsub(
            /--#EVENT (?<service>\S+) (?<event>\S+)/,
            "--#EVENT #{service} \\k<event>"
          )
        end
        new_script += line
      end
      new_script
    end

    def decode_config_var(term)
      decoded = term
      config_var = nil
      # Try to match svc against a {config.variable}.
      mat = /^\{([^\.}]+)\.([^\.}]+)\}$/.match(term)
      unless mat.nil?
        # User specified a config value, e.g., "--#EVENT {product.id} event".
        config_var = "#{mat[1]}.#{mat[2]}"
        decoded = $cfg[config_var]
        if decoded.nil?
          warning "Config value not found for variable: #{fancy_ticks(term)}"
          # The platform should complain about file not found,
          # and we'll process everything else.
          decoded = term
          config_var = nil
        end
      end
      [decoded, config_var]
    end

    def encode_config_var(term)
      encoded = term
      config_var = nil
      # MEH/2017-08-22: For now, only matching against one config var.
      #   Maybe in the future we'd want to examine all the config vars?
      # MAGIC_STRING: {config.variable} substitution.
      if term == $cfg['product.id']
        encoded = '{product.id}'
        config_var = 'product.id'
      end
      [encoded, config_var]
    end

    def resolve_event_type(service, event)
      # FIXME/2017-08-09: device2.event is now in the skiplist,
      #   but some tests have a "device2 data_in" script, which
      #   gets changed to "device2.event" here and then uploaded
      #   (note that skiplist does not apply to local items).
      #   You can test this code via:
      #     rspec ./spec/cmd_syncdown_spec.rb
      #   which has a fixture with device2.data_in specified.
      #   QUESTION: Does writing device2.event do anything?
      #     You cannot edit that handler from the web UI...
      #     - Should we change the test?
      #     - Should we get rid of this device2 hack?
      if service == 'device2'
        event_event = 'event'
        event_type = event
        # FIXME/CONFIRM/2017-07-02: 'data_in' was the old event name? It's now 'event'?
        #   Want this?:
        #     event_type = 'event' if event_type == 'data_in'
      else
        event_event = event
        event_type = nil
      end
      [event_event, event_type]
    end

    def resurrect_undeletables(localbox, therebox)
      undeletables = ($cfg['eventhandler.undeletable'] || '').split
      (therebox.keys - localbox.keys).each do |key|
        # key exists in therebox but not localbox.
        thereitem = therebox[key]
        next unless undeletable?(thereitem, undeletables)
        debug "Undeletable: #{key}"
        undeletable = EventHandlerItem.new(thereitem)
        undeletable.id = nil
        undeletable.created_at = nil
        undeletable.updated_at = nil
        #undeletable.local_path
        #undeletable.line
        # Even if the user deletes the contents of a script,
        # the platform still sends the magic header.
        #undeletable.script = ''
        undeletable.script = (
          "--#EVENT #{therebox[key].service} #{therebox[key].event}\n"
        )
        undeletable.local_path = Pathname.new(
          File.join(location, tolocalname(thereitem, key))
        )
        undeletable.phantom = true
        localbox[key] = undeletable
      end
      localbox
    end

    def undeletable?(item, undeletables)
      return false if item.service.to_s.empty? || item.event.to_s.empty?
      undeletables.any? do |svc_evt|
        cmp_svc_evt(item, svc_evt)
      end
    end
  end

  PRODUCT_SERVICES = %w[device2 interface].freeze

  class EventHandlerSolnPrd < EventHandler
    def initialize(api_id=nil)
      @solntype = 'product.id'
      # FIXME/2017-06-20: Should we use separate directories for prod vs app?
      #   See also :services in PrfFile and elsewhere;
      #   we could use @@class_var to DRY.
      @project_section = :services
      super
    end

    def self.description
      %(Interface)
    end

    ##
    # Get a list of local items filtered by solution type.
    # @return [Array<Item>] Product solution events found
    def locallist(skip_warn: false)
      llist = super
      # This is a kludge to distinguish between Product services
      # and Application services: assume that Murano only ever
      # identifies Product services as 'device2' || 'interface'.
      # If this weren't always the case, we'd have two obvious options:
      #   1) Store Product and Application eventhandlers in separate
      #      directories (and update the SyncRoot.instance.add()s, below); or,
      #   2) Put the solution type in the Lua script,
      #      e.g., change this:
      #        --#EVENT device2 data_in
      #      to this:
      #        --#EVENT product device2 data_in
      # For now, the @service indicator is sufficient.
      llist.select! { |i| PRODUCT_SERVICES.include? i.service }
      llist
    end
  end

  class EventHandlerSolnApp < EventHandler
    def initialize(api_id=nil)
      @solntype = 'application.id'
      # FIXME/2017-06-20: Should we use separate directories for prod vs app?
      @project_section = :services
      super
    end

    def self.description
      %(Service)
    end

    ##
    # Get a list of local items filtered by solution type.
    # @return [Array<Item>] Application solution events found
    def locallist(skip_warn: false)
      llist = super
      # "Style/InverseMethods: Use reject! instead of inverting select!."
      #llist.select! { |i| !PRODUCT_SERVICES.include? i.service }
      llist.reject! { |i| PRODUCT_SERVICES.include? i.service }
      llist
    end
  end

  # Order here matters, because spec/cmd_init_spec.rb
  # NOTE/2017-08-07: There was one syncable in 2.x for events, but in ADC,
  #   there are different events for Applications and Products.
  #   Except there aren't any product events the user should care about (yet?).
  SyncRoot.instance.add(
    'services', EventHandlerSolnApp, 'S', true, %w[eventhandlers]
  )
  # 2017-08-08: device2 and interface are now part of the skiplist, so no
  # product event handlers will be found, unless the user modifies the skiplist.
  SyncRoot.instance.add(
    'interfaces', EventHandlerSolnPrd, 'I', true, %w[]
  )
end


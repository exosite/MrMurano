# Last Modified: 2017.08.03 /coding: utf-8
# frozen_string_literal: true

# Copyright © 2016-2017 Exosite LLC.
# License: MIT. See LICENSE.txt.
#  vim:tw=0:ts=2:sw=2:et:ai

require 'http/form_data'
require 'json-schema'
require 'net/http'
require 'uri'
require 'MrMurano/hash'
require 'MrMurano/http'
require 'MrMurano/verbosing'
require 'MrMurano/Config'
require 'MrMurano/SolutionId'
require 'MrMurano/SyncRoot'
require 'MrMurano/SyncUpDown'

module MrMurano
  ## The details of talking to the Gateway [Device2] service.
  # This is where interfacing to real hardware happens.
  module Gateway
    class GweBase
      include Http
      include Verbose
      include SolutionId

      def initialize
        @solntype = 'product.id'
        @uriparts_sidex = 1
        init_sid!
        @uriparts = [:service, @sid, :device2]
        @uriparts_sidex = 1
        @itemkey = :id
      end

      ## Generate an endpoint in Murano
      # Uses the uriparts and path
      # @param path String: any additional parts for the URI
      # @return URI: The full URI for this enpoint.
      def endpoint(path='')
        super
        parts = ['https:/', $cfg['net.host'], 'api:1'] + @uriparts
        s = parts.map(&:to_s).join('/')
        URI(s + path.to_s)
      end
      # …
      #include SyncUpDown

      # Get info for this gateway interface.
      def info
        get
      end
    end

    class Settings < GweBase
      # Get the protocol settings
      def protocol
        ret = get
        return {} if ret.nil?
        return {} unless ret.is_a?(Hash)
        return {} unless ret.key?(:protocol)
        return {} unless ret[:protocol].is_a?(Hash)
        ret[:protocol]
      end

      # Set the protocol settings
      def protocol=(x)
        raise 'Not Hash' unless x.is_a?(Hash)
        x.delete_if { |k, _v| !%i[name devmode].include?(k) }
        patch('', protocol: x)
      end

      def identity_format
        ret = get
        return {} if ret.nil?
        return {} unless ret.is_a?(Hash)
        return {} unless ret.key?(:identity_format)
        return {} unless ret[:identity_format].is_a?(Hash)
        ret[:identity_format]
      end

      def identity_format=(x)
        raise 'Not Hash' unless x.is_a?(Hash)
        raise 'Not Hash' if x.key?(:options) && !x[:options].is_a?(Hash)
        x.delete_if { |k, _v| !%i[type prefix options].include?(k) }
        x[:options].delete_if { |k, _v| !%i[casing length].include?(k) }
        patch('', identity_format: x)
      end

      def provisioning
        ret = get
        return {} if ret.nil?
        return {} unless ret.is_a?(Hash)
        return {} unless ret.key?(:provisioning)
        return {} unless ret[:provisioning].is_a?(Hash)
        ret[:provisioning]
      end

      def provisioning=(x)
        raise 'Not Hash' unless x.is_a?(Hash)
        raise 'Not Hash' if x.key?(:ip_whitelisting) && !x[:ip_whitelisting].is_a?(Hash)
        x.delete_if do |k, _v|
          !%i[enabled auth_type generate_identity presenter_identity ip_whitelisting].include?(k)
        end
        x[:ip_whitelisting].delete_if { |k, _v| !%i[enabled allowed].include?(k) }
        patch('', provisioning: x)
      end
    end

    ##############################################################################
    ## Working with the resources on a set of Devices. (Gateway)
    class Resources < GweBase
      include SyncUpDown

      def initialize
        super
        @itemkey = :alias
        @project_section = :resources
      end

      def self.description
        %(Resources)
      end

      def list
        ret = get('')
        return [] unless ret.key? :resources

        # convert hash to array.
        res = []
        ret[:resources].each_pair do |key, value|
          res << value.merge(alias: key.to_s)
        end
        res
      end

      def upload_all(data)
        # convert array to hash
        res = {}
        data.each do |value|
          key = value[:alias]
          res[key] = value.reject { |k, _v| k == :alias }
        end

        patch('', resources: res)
      end

      ###################################################

      def syncup_before
        @there = list
      end

      def remove(itemkey)
        @there.delete_if { |item| item[@itemkey] == itemkey }
      end

      def upload(_local, remote, _modify)
        @there.delete_if { |item| item[@itemkey] == remote[@itemkey] }
        @there << remote.reject { |k, _v| %i[synckey synctype].include? k }
      end

      def syncup_after
        if !@there.empty?
          if !$cfg['tool.dry']
            sync_update_progress('Updating product resources')
            upload_all(@there)
          else
            MrMurano::Verbose.whirly_interject do
              say("--dry: Not updating resources")
            end
          end
        elsif $cfg['tool.verbose']
          MrMurano::Verbose.whirly_interject do
            say('No resources changed')
          end
        end
        @there = nil
      end

      ###################################################

      def syncdown_before
        # FIXME/2017-07-02: Could there be duplicate gateway items?
        #   [lb] just added code to SyncUpDown.locallist and am curious.
        @here = locallist
      end

      def download(_local, item)
        @here = locallist if @here.nil?
        # needs to append/merge with file
        @here.delete_if do |i|
          i[@itemkey] == item[@itemkey]
        end
        @here << item.reject { |k, _v| %i[synckey synctype].include? k }
      end

      def diff_download(tmp_path, merged)
        @there = list if @there.nil?
        items = @there.reject { |item| item[:alias] != merged[:alias] }
        if items.length > 1
          error(
            "Unexpected: more than 1 resource with the same alias: #{merged[:alias]} / #{items}"
          )
        end
        Pathname.new(tmp_path).open('wb') do |io|
          if !items.length.zero?
            diff_item_write(io, merged, nil, items.first)
          else
            io << "\n"
          end
        end
      end

      def removelocal(_local, item)
        # needs to append/merge with file
        key = @itemkey.to_sym
        @here.delete_if do |it|
          it[key] == item[key]
        end
      end

      def syncdown_after(local)
        resources_write(local)
        @here = nil
      end

      def resources_write(file_path)
        # User can blow away specs/ directory if they want; we'll just make
        # a new one. [This code somewhat copy-paste from make_directory.]
        basedir = file_path
        basedir = basedir.dirname unless basedir.extname.empty?
        raise 'Unexpected: bad basedir' if basedir.to_s.empty? || basedir == File::SEPARATOR

        unless basedir.exist?
          if $cfg['tool.dry']
            MrMurano::Verbose.warning(
              "--dry: Not creating default directory: #{basedir}"
            )
          else
            FileUtils.mkdir_p(basedir, noop: $cfg['tool.dry'])
          end
        end

        if $cfg['tool.dry']
          MrMurano::Verbose.warning(
            "--dry: Not writing resources file: #{file_path}"
          )
          return
        end

        file_path.open('wb') do |io|
          # convert array to hash
          res = {}
          @here.each do |value|
            key = value[:alias]
            res[key] = Hash.transform_keys_to_strings(value.reject { |k, _v| k == :alias })
          end
          ohash = ordered_hash(res)
          io.write ohash.to_yaml
        end
      end

      def diff_item_write(io, _merged, local, remote)
        raise 'Unexpected: please specify either local or remote, but not both' if local && remote
        item = local || remote
        raise "Unexpected: :local_path exists: #{item}" unless item[:local_path].to_s.empty?
        res = {}
        key = item[:alias]
        item = item.reject { |k, _v| %i[alias synckey synctype].include? k }
        res[key] = Hash.transform_keys_to_strings(item)
        ohash = ordered_hash(res)
        io << ohash.to_yaml
      end

      ###################################################

      def tolocalpath(into, _item)
        into
      end

      def localitems(from)
        from = Pathname.new(from) unless from.is_a?(Pathname)
        unless from.exist?
          warning "Skipping missing #{from}"
          return []
        end
        unless from.file?
          warning "Cannot read from #{from}"
          return []
        end

        here = {}
        # FIXME/2017-07-02: "Security/YAMLLoad: Prefer using YAML.safe_load over YAML.load."
        from.open { |io| here = YAML.load(io) }
        here = {} if here == false

        # Validate file against schema.
        schema_path = Pathname.new(File.dirname(__FILE__)) + 'schema/resource-v1.0.0.yaml'
        # MAYBE/2017-07-03: Do we care if user duplicates keys in the yaml? See dup_count.
        schema = YAML.load_file(schema_path.to_s)
        begin
          JSON::Validator.validate!(schema, here)
        rescue JSON::Schema::ValidationError => err
          error("There is an error in the config file, #{from}")
          error(%("#{err.message}"))
          exit 1
        end

        res = []
        here.each_pair do |key, value|
          res << Hash.transform_keys_to_symbols(value).merge(alias: key.to_s)
        end
        res
      end

      def docmp(item_a, item_b)
        item_a != item_b
      end
    end
    # 2017-07-18: Against OneP, fetching --resources is expensive, so this
    # call was ignored bydefault (you'd have to add --resources to syncup,
    # syncdown, diff, and status commands). Against Murano, this call seems
    # normal speed, so including by default.
    SyncRoot.instance.add('resources', Resources, 'T', true)

    ##############################################################################
    ##
    # Talking to the devices on a Gateway
    class Device < GweBase
      def initialize
        super
        @uriparts << :identity
      end

      ## All devices (pagination?)
      # @param limit [Number,String] How many devices to return
      # @param before [Number,String] timestamp for something. TODO: want offset.
      def list(limit=nil, before=nil)
        pr = {}
        pr[:limit] = limit unless limit.nil?
        pr[:before] = before unless before.nil?
        pr = nil if pr.empty?
        get('/', pr)
      end

      def query(args)
        # TODO: actually just part of list.
        # ?limit=#
        # ?before=<time stamp in ms>
        # ?status={whitelisted, provisioned, locked, devmode, reprovision}
        # ?identity=<pattern>
        # ?ipaddress=<pattern>
        # ?version=<pattern>
      end

      ## Get one device
      # @param id [String] The identity to fetch
      def fetch(id)
        get("/#{CGI.escape(id.to_s)}")
      end

      ## Create a device with given Identity
      # @param id [String] The new identity
      # @param opts [Hash] Options for the new device
      # @option opts [String] :type One of: certificate, hash, password, signature, token
      # @option opts [String,Pathname,IO] :publickey The certificate, or IO/Pathname to cert file
      # @option opts [String] :privatekey Shared secret for hash, password, token types
      # @option opts [String,Integer] :expire For Cert, when it must be reprovisioned, otherwise when the activation window closes.
      def enable(id, opts=nil)
        if !opts.nil?
          #opts.reject! { |k, _v| !%i[type publickey privatekey expire].include?(k) }
          opts.select! { |k, _v| %i[type publickey privatekey expire].include?(k) }
          if opts.key?(:publickey) && !opts[:publickey].is_a?(String)
            io = opts[:publickey]
            opts[:publickey] = io.read
          end
        else
          opts = {}
        end
        whirly_start('Enabling Device...')
        putted = put("/#{CGI.escape(id.to_s)}", opts)
        whirly_stop
        putted
      end
      alias whitelist enable
      alias create enable

      ## Create a bunch of devices at once
      # @param local [String, Pathname] CSV file of identifiers
      # @param expire [Number] Expire time for all identities (ignored)
      # @return [void]
      def enable_batch(local, _expire=nil)
        # Need to modify @uriparts for just this endpoint call.
        uriparts = @uriparts
        @uriparts[-1] = :identities
        uri = endpoint
        @uriparts = uriparts

        file = HTTP::FormData::File.new(local.to_s, content_type: 'text/csv')
        form = HTTP::FormData.create(identities: file)
        req = Net::HTTP::Post.new(uri)
        set_def_headers(req)
        req.content_type = form.content_type
        req.content_length = form.content_length
        req.body = form.to_s
        whirly_start('Enabling Devices...')
        workit(req)
        whirly_stop
        nil
      end

      ## Delete a device
      # @param identifier [String] Who to delete.
      def remove(identifier)
        delete("/#{CGI.escape(identifier.to_s)}")
      end

      # Call the device Activation URI.
      #
      # Only useful durring debugging of devices.
      #
      # @param identifier [String] Who to activate.
      def activate(identifier)
        info = GweBase.new.info
        raise "Gateway info not found for #{identifier}" if info.nil?
        fqdn = info[:fqdn]
        debug "Found FQDN: #{fqdn}"
        fqdn = "#{@sid}.m2.exosite.io" if fqdn.nil?

        uri = URI("https://#{fqdn}/provision/activate")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.start
        request = Net::HTTP::Post.new(uri)
        request.form_data = {
          vendor: @sid,
          model: @sid,
          sn: identifier,
        }
        request['User-Agent'] = "MrMurano/#{MrMurano::VERSION}"
        request['Authorization'] = nil
        request.content_type = 'application/x-www-form-urlencoded; charset=utf-8'
        curldebug(request)

        whirly_start('Activating Device...')
        response = http.request(request)
        whirly_stop

        case response
        when Net::HTTPSuccess
          return response.body
        when Net::HTTPConflict
          error('The specified device is already activated.')
          exit 1
        else
          showHttpError(request, response)
        end
      end

      # Write the set point for aliases on a device
      # @param identifier [String] The identifier for the device to write.
      # @param values [Hash] Aliases and the values to write.
      def write(identifier, values)
        debug "Will Write: #{values}"
        patch("/#{identifier}/state", values)
      end

      # Read the current state for a device
      # @param identifier [String] The identifier for the device to read.
      def read(identifier)
        get("/#{identifier}/state")
      end
    end
  end
end


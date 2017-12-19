# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

require 'time'
require 'MrMurano/Gateway'
require 'MrMurano/ReCommander'

command :device do |c|
  c.syntax = %(murano device)
  c.summary = %(Interact with a device)
  c.description = %(
Interact with a device.
  ).strip
  c.project_not_required = true
  c.subcmdgrouphelp = true

  c.action do |_args, _options|
    ::Commander::UI.enable_paging unless $cfg['tool.no-page']
    say MrMurano::SubCmdGroupHelp.new(c).get_help
  end
end

command 'device list' do |c|
  c.syntax = %(murano device list [--options])
  c.summary = %(List identifiers for a product)
  c.description = %(
List identifiers for a product.
  ).strip

  c.option '--limit NUMBER', Integer, %(How many devices to return)
  c.option '--before TIMESTAMP', Integer, %(Show devices before timestamp)
  c.option '-l', '--long', %(show everything)
  c.option '-o', '--output FILE', %(Download to file instead of STDOUT)

  c.action do |args, options|
    c.verify_arg_count!(args)
    #options.default limit: 1000

    prd = MrMurano::Gateway::Device.new
    MrMurano::Verbose.whirly_start 'Looking for devices...'
    data = prd.list(options.limit, options.before)
    MrMurano::Verbose.whirly_stop
    exit 1 if data.nil?

    if !data[:devices].empty?
      io = File.open(options.output, 'w') if options.output
      prd.outf(data, io) do |_dd, ios|
        dt = {}
        if options.long
          dt[:headers] = [
            :Identifier,
            :AuthType,
            :Locked,
            :Reprovision,
            'Dev Mode',
            'Last IP',
            'Last Seen',
            :Status,
            :Online,
          ]
          dt[:rows] = data[:devices].map do |row|
            [
              row[:identity],
              (row[:auth] || {})[:type],
              row[:locked],
              row[:reprovision],
              row[:devmode],
              row[:lastip],
              row[:lastseen],
              row[:status],
              row[:online],
            ]
          end
        else
          dt[:headers] = %i[Identifier Status Online]
          dt[:rows] = data[:devices].map do |row|
            [row[:identity], row[:status], row[:online]]
          end
        end
        prd.tabularize(dt, ios)
      end
      io.close unless io.nil?
    else
      prd.warning 'Did not find any devices'
    end
  end
end
alias_command 'devices list', 'device list'

command 'device read' do |c|
  c.syntax = %(murano device read <identifier> [<alias>...] [--options])
  c.summary = %(Read state of a device)
  c.description = %(
Read state of a device.

This reads the latest state values for the resources in a device.
  ).strip

  c.option '-o', '--output FILE', %(Download to file instead of STDOUT)

  c.action do |args, options|
    c.verify_arg_count!(args, nil, ['Missing device identifier'])

    prd = MrMurano::Gateway::Device.new

    snid = args.shift

    # FIXME/2017-06-14: Confirm that whirly is helpful here.
    MrMurano::Verbose.whirly_start 'Fetching device data...'
    data = prd.read(snid)
    MrMurano::Verbose.whirly_stop
    exit 1 if data.nil?

    io = File.open(options.output, 'w') if options.output
    data.select! { |k, _v| args.include? k.to_s } unless args.empty?
    prd.outf(data, io) do |dd, ios|
      rows = []
      dd.each_pair do |k, v|
        rows << [k, v[:reported], v[:set], v[:timestamp]]
      end
      prd.tabularize(
        {
          headers: %i[Alias Reported Set Timestamp],
          rows: rows,
        },
        ios
      )
    end
    io.close unless io.nil?
  end
end

command 'device write' do |c|
  c.syntax = %(murano device write <identifier> <Alias=Value> [<Alias=Value>...])
  c.summary = %(Write to 'set' of aliases on devices)
  c.description = %(
Write to 'set' of aliases on devices.

If an alias is not settable, this will fail.
  ).strip

  c.action do |args, _options|
    c.verify_arg_count!(args, nil, ['Missing device identifier'])

    resources = (MrMurano::Gateway::GweBase.new.info || {})[:resources]

    prd = MrMurano::Gateway::Device.new

    snid = args.shift

    set = Hash[args.map { |i| i.split('=') }]
    set.each_pair do |k, v|
      fmt = ((resources[k.to_sym] || {})[:format] || 'string')
      case fmt
      when 'number'
        if v.to_f.to_i == v.to_i
          set[k] = v.to_i
        else
          set[k] = v.to_f
        end
      when 'string'
        set[k] = '' if v.nil?
      when 'boolean'
        set[k] = %w[1 yes true on].include?(v.downcase)
      end
    end

    ret = prd.write(snid, set)
    # On success, write returns empty curlies {}. So check nil or empty.
    prd.outf(ret) unless ret.nil? || ret.empty?
  end
end

command 'device enable' do |c|
  c.syntax = %(murano device enable (<identifier>|--file <path>) [--options])
  c.summary = %(Enable Identifiers in Murano for real world devices)
  c.description = %(
Enables Identifiers, creating devices, or digital shadows, in Murano.
  ).strip

  c.option '-e', '--expire HOURS', %(Devices that do not activate within HOURS hours will be deleted for security purposes)
  c.option '-f', '--file FILE', %(A file of serial numbers, one per line)
  c.option '--key FILE', %(Path to file containing public TLS key for this device)
  allowed_types = MrMurano::Gateway::Device::DEVICE_AUTH_TYPES.map(&:to_s).sort
  c.option '--auth TYPE', %(Type of credential used to authenticate [#{allowed_types.join('|')}])
  c.option '--cred KEY', %(The credential used to authenticate, e.g., token, password, etc.)

  c.action do |args, options|
    c.verify_arg_count!(args, 1)

    prd = MrMurano::Gateway::Device.new

    if args.count.zero? && options.file.to_s.empty?
      prd.error 'Missing device identifier or --file'
      exit 1
    elsif !args.count.zero? && !options.file.to_s.empty?
      prd.error 'Please specify an identifier or --file but not both'
      exit 1
    end

    if !options.file.nil? && (!options.key.nil? || !options.auth.nil? || !options.cred.nil?)
      prd.error %(Cannot use --file with any of: --key, --auth, or --cred)
      exit 1
    end
    if !options.key.nil? && !options.cred.nil?
      prd.error %(Please use either --cred or --key but not both)
      exit 1
    end
    if options.auth.nil? ^ options.cred.nil?
      prd.error %(Please specify both --auth and --cred or neither)
      exit 1
    end
    options.auth = options.auth.to_sym unless options.auth.nil?
    unless options.key.nil?
      if !options.auth.nil? && options.auth != :certificate
        prd.warning %(You probably mean to use "--auth certificate" with --key)
      else
        options.auth = :certificate
      end
    end

    unless options.expire.nil?
      unless options.expire =~ /^[0-9]+$/
        prd.error %(The --expire value is not a number of hours: #{prd.fancy_ticks(options.expire)})
        exit 1
      end
      # The platform expects the expiration time to be an integer
      # representing microseconds since the epoch, e.g.,
      #    hours * mins/hour * secs/min * msec/sec * μsec/msec
      # or hours * 60        * 60       * 1000     * 1000
      micros_since_epoch = (Time.now.to_f * 1_000_000).to_i
      mircos_until_purge = options.expire.to_i * 60 * 60 * 1000 * 1000
      options.expire = micros_since_epoch + mircos_until_purge
    end

    unless options.auth.nil?
      options.auth = options.auth.to_sym
      unless MrMurano::Gateway::Device::DEVICE_AUTH_TYPES.include?(options.auth)
        MrMurano::Verbose.error("unrecognized --auth: #{options.auth}")
        exit 1
      end
    end

    if !options.file.to_s.empty?
      # Check file for headers.
      begin
        header = File.new(options.file).gets
      rescue Errno::ENOENT => err
        prd.error %(Unable to open file #{prd.fancy_ticks(options.file)}: #{err.message})
        exit 2
      end
      if header.nil?
        prd.error 'Nothing in file!'
        exit 1
      end
      unless header =~ /\s*ID\s*(,SSL Client Certificate\s*)?/
        prd.error %(Missing column headers in file "#{options.file}")
        prd.error %(First line in file should be either "ID" or "ID, SSL Client Certificate")
        exit 2
      end
      prd.enable_batch(options.file, options.expire)
    elsif args.count > 0
      opts = {}
      opts[:expire] = options.expire unless options.expire.nil?
      opts[:type] = options.auth unless options.auth.nil?
      if options.key
        File.open(options.key, 'rb') do |io|
          prd.enable(args[0], **opts, key: io)
        end
      else
        opts[:key] = options.cred unless options.cred.nil?
        prd.enable(args[0], **opts)
      end
    else
      # Impossible path: neither args nor --file; would've exited by now.
      raise 'Impossible'
    end
  end
end

command 'device activate' do |c|
  c.syntax = %(murano device activate <identifier>)
  c.summary = %(Activate a serial number, retriving its CIK)
  c.description = %(
Activate an Identifier.

Generally you should not use this.

Instead, the device should make the activation call itself
and save the CIK token.

But sometimes when building a proof-of-concept it is just
easier to hardcode the CIK.

Note that you can only activate a device once. After that
you cannot retrive the CIK again.
  ).strip

  c.action do |args, _options|
    c.verify_arg_count!(args, nil, ['Missing device identifier'])
    prd = MrMurano::Gateway::Device.new
    prd.outf prd.activate(args.first)
  end
end

command 'device delete' do |c|
  c.syntax = %(murano device delete <identifier>)
  c.summary = %(Delete a device)
  c.description = %(
Delete a device.
  ).strip

  c.action do |args, _options|
    c.verify_arg_count!(args, nil, ['Missing device identifier'])
    prd = MrMurano::Gateway::Device.new
    snid = args.shift
    ret = prd.remove(snid)
    prd.outf ret unless ret.empty?
  end
end

command 'device httpurl' do |c|
  c.syntax = %(murano device httpurl)
  c.summary = %(Get the URL for the HTTP-Data-API for this Project)
  c.description = %(
Get the URL for the HTTP-Data-API for this Project.
  ).strip

  c.action do |args, _options|
    c.verify_arg_count!(args)
    prd = MrMurano::Gateway::GweBase.new
    ret = prd.info
    say "https://#{ret[:fqdn]}/onep:v1/stack/alias"
  end
end

command 'device lock' do |c|
  c.syntax = %(murano device lock <identifier>)
  c.summary = %(Lock a device, not allowing connections to it until unlocked)
  c.description = %(
Lock a device, not allowing connections to it until unlocked.
  ).strip

  c.action do |args, _options|
    c.verify_arg_count!(args, 1, ['Missing device identifier'])
    prd = MrMurano::Gateway::Device.new
    prd.lock(args[0])
  end
end

command 'device unlock' do |c|
  c.syntax = %(murano device unlock <identifier>)
  c.summary = %(Unlock a device, allowing connections to it again)
  c.description = %(
Unlock a device, allowing connections to it again.
  ).strip

  c.action do |args, _options|
    c.verify_arg_count!(args, 1, ['Missing device identifier'])
    prd = MrMurano::Gateway::Device.new
    prd.unlock(args[0])
  end
end

command 'device revoke' do |c|
  c.syntax = %(murano device revoke <identifier>)
  c.summary = %(Force device to reprovision)
  c.description = %(
Force device to reprovision.

This will revoke the device's keys and cause it to temporarily disconnect. The will then reconnect and be provisioned with new keys.
  ).strip

  c.action do |args, _options|
    c.verify_arg_count!(args, 1, ['Missing device identifier'])
    prd = MrMurano::Gateway::Device.new
    # MAYBE/2017-08-23: This command doesn't return an error if the device
    # ID was not found, or if the keys were already revoked. Do we care?
    # At least the lock command fails if the device ID is not found.
    prd.revoke(args[0])
  end
end

alias_command 'product device', 'device'
alias_command 'product device list', 'device list'
alias_command 'product devices list', 'device list'
alias_command 'product device read', 'device read'
alias_command 'product device twee', 'device read'
alias_command 'product device write', 'device write'
alias_command 'product device enable', 'device enable'
alias_command 'product device activate', 'device activate'
alias_command 'product device delete', 'device delete'
alias_command 'product device httpurl', 'device httpurl'
alias_command 'product device lock', 'device lock'
alias_command 'product device unlock', 'device unlock'
alias_command 'product device revoke', 'device revoke'


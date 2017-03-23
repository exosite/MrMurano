require 'MrMurano/Gateway'

command 'device' do |c|
  c.syntax = %{murano device}
  c.summary = %{Interact with a device}
  c.description = %{}

  c.action do |a,o|
    ::Commander::UI.enable_paging
    say MrMurano::SubCmdGroupHelp.new(c).get_help
  end
end

command 'device list' do |c|
  c.syntax = %{murano device list [options]}
  c.summary = %{List identifiers for a product}
  c.description = %{List identifiers for a product

  The API for pagination of devices seems broken.
  }

  c.option '--limit NUMBER', Integer, %{How many devices to return}
  c.option '--before TIMESTAMP', Integer, %{Show devices before timestamp}
  c.option '-l', '--long', %{show everything}
  c.option '-o', '--output FILE', %{Download to file instead of STDOUT}

  c.action do |args,options|
    #options.default :limit=>1000

    prd = MrMurano::Gateway::Device.new
    io=nil
    data = prd.list(options.limit, options.before)
    exit 1 if data.nil?
    io = File.open(options.output, 'w') if options.output
    prd.outf(data, io) do |dd,ios|
      dt={}
      if options.long then
        dt[:headers] = [:Identifier,
                        :AuthType,
                        :Locked,
                        :Reprovision, 'Dev Mode', 'Last IP',
                        'Last Seen',
                        :Status, :Online]
        dt[:rows] = data[:devices].map{|row| [row[:identity],
                                    (row[:auth] or {})[:type],
                                    row[:locked],
                                    row[:reprovision],
                                    row[:devmode],
                                    row[:lastip],
                                    row[:lastseen],
                                    row[:status],
                                    row[:online]]}
      else
        dt[:headers] = [:Identifier, :Status, :Online]
        dt[:rows] = data[:devices].map{|row| [row[:identity], row[:status], row[:online]]}
      end
      prd.tabularize(dt, ios)
    end
    io.close unless io.nil?
  end
end

command 'device read' do |c|
  c.syntax = %{murano device read <identifier> (<alias>...)}
  c.summary = %{Read state of a device}
  c.description = %{Read state of a device

  This reads the latest state values for the resources in a device.
  }
  c.option '-o', '--output FILE', %{Download to file instead of STDOUT}

  c.action do |args,options|
    prd = MrMurano::Gateway::Device.new
    if args.count < 1 then
      prd.error "Identifier missing"
      exit 1
    end
    snid = args.shift

    io=nil
    data = prd.read(snid)
    exit 1 if data.nil?
    io = File.open(options.output, 'w') if options.output
    unless args.empty? then
      data.select!{|k,v| args.include? k.to_s}
    end
    prd.outf(data, io) do |dd,ios|
      rows = []
      dd.each_pair do |k,v|
        rows << [k, v[:reported], v[:set], v[:timestamp]]
      end
      prd.tabularize({
        :headers => [:Alias, :Reported, :Set, :Timestamp],
        :rows => rows,
      }, ios)
    end
    io.close unless io.nil?
  end
end

command 'device write' do |c|
  c.syntax = %{murano device write <identifier> <Alias=Value> [<Alias=Value>...]}
  c.summary = %{Write to 'set' of aliases on devices}
  c.description = %{Write to 'set' of aliases on devices

  If an alias is not settable, this will fail.
  }

  c.action do |args,options|
    resources = (MrMurano::Gateway::Base.new.info or {})[:resources]
    prd = MrMurano::Gateway::Device.new
    if args.count < 1 then
      prd.error "Identifier missing"
      exit 1
    end
    snid = args.shift

    set = Hash[ args.map{|i| i.split('=')} ]
    set.each_pair do |k,v|
      fmt = ((resources[k.to_sym] or {})[:format] or 'string')
      case fmt
      when 'number'
        if v.to_f.to_i == v.to_i then
          set[k] = v.to_i
        else
          set[k] = v.to_f
        end
      when 'string'
        set[k] = '' if v.nil?
      when 'boolean'
        set[k] = ['1', 'yes', 'true', 'on'].include?(v.downcase)
      end
    end

    ret = prd.write(snid, set)
    prd.outf ret unless ret.nil? or ret.empty?
  end
end


command 'device enable' do |c|
  c.syntax = %{murano device enable [<identifier>|--file <identifiers>]}
  c.summary = %{Enable an Identifier; Creates device in Murano}
  c.description = %{Enables identifiers, creating the digial shadow in Murano.
  }
  c.option '-f', '--file FILE', %{A file of serial numbers, one per line}

  c.action do |args,options|
    prd = MrMurano::Gateway::Device.new
    if options.file then
      # Check file for headers.
      header = File.new(options.file).gets
      if header.nil? then
        prd.error "Nothing in file!"
        exit 1
      end
      if not header =~ /\s*ID\s*(,SSL Client Certificate\s*)?/ then
        prd.error "Missing column headers in file \"#{options.file}\""
        prd.error %{First line in file should be either "ID" or "ID, SSL Client Certificate"}
        exit 2
      end
      prd.enable_batch(options.file)
    elsif args.count > 0 then
      prd.enable(args[0])
    else
      prd.error "Missing an identifier to enable"
    end
  end
end

command 'device activate' do |c|
  c.syntax = %{murano device activate <identifier>}
  c.summary = %{Activate a serial number, retriving its CIK}
  c.description = %{Activates an Identifier.

Generally you should not use this.  Instead the device should make the activation
call itself and save the CIK token.  Its just that sometimes when building a
proof-of-concept it is just easier to hardcode the CIK.

Note that you can only activate a device once.  After that you cannot retrive the
CIK again.
}

  c.action do |args,options|
    prd = MrMurano::Gateway::Device.new
    if args.count < 1 then
      prd.error "Identifier missing"
      exit 1
    end

    prd.outf prd.activate(args.first)

  end
end

command 'device delete' do |c|
  c.syntax = %{murano device delete <identifier>}
  c.summary = %{Delete a device}

  c.action do |args,options|
    prd = MrMurano::Gateway::Device.new
    if args.count < 1 then
      prd.error "Identifier missing"
      exit 1
    end
    snid = args.shift

    ret = prd.remove(snid)
    prd.outf ret unless ret.empty?
  end
end

command 'device httpurl' do |c|
  c.syntax = %{murano device httpurl}
  c.summary = %{Get the URL for the HTTP-Data-API for this Project}

  c.action do |args,options|
    prd = MrMurano::Gateway::Base.new
    ret = prd.info()
    say "https://#{ret[:fqdn]}/onep:v1/stack/alias"
  end
end

alias_command 'product device', 'device'
alias_command 'product device activate', 'device activate'
alias_command 'product device enable', 'device enable'
alias_command 'product device list', 'device list'
alias_command 'product device read', 'device read'
alias_command 'product device twee', 'device read'
alias_command 'product device write', 'device write'
alias_command 'product device delete', 'device delete'

#  vim: set ai et sw=2 ts=2 :
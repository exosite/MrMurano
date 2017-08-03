# Last Modified: 2017.07.31 /coding: utf-8
# frozen_string_literal: true

# Copyright © 2016-2017 Exosite LLC.
# License: MIT. See LICENSE.txt.
#  vim:tw=0:ts=2:sw=2:et:ai

require 'MrMurano/Account'
require 'MrMurano/Solution-ServiceConfig'
require 'MrMurano/SolutionId'

command 'link' do |c|
  c.syntax = %(murano link)
  c.summary = %(Use the link commands to manage solution links)
  c.description = %(
Use the link commands to manage solution links.
  ).strip
  c.project_not_required = true

  c.action do |_args, _options|
    ::Commander::UI.enable_paging
    say(MrMurano::SubCmdGroupHelp.new(c).get_help)
  end
end

command 'link list' do |c|
  c.syntax = 'murano link list [options]'
  c.summary = %(List the solutions that are linked)
  c.description = %(
List the solutions that are linked.
  ).strip

  c.option '--idonly', 'Only return the ids'
  c.option '--[no-]all', 'Show all columns'

  c.action do |args, options|
    # List solutions(type=product)
    # List service configs.
    # Display where serviceconfig.service == products.apiId

    c.verify_arg_count!(args)

    MrMurano::Verbose.whirly_start('Fetching product list...')
    biz = MrMurano::Business.new
    products = biz.products
    MrMurano::Verbose.whirly_stop
    pids = products.map(&:apiId)

    # FIXME/2017-07-31: If the user has multiple solutions, won't
    #   this method ask them to specify which application to use?
    appl = solution_find_or_create(biz: biz, type: :application)

    if !appl.nil?
      MrMurano::Verbose.whirly_msg('Fetching application services...')
      sercfg = MrMurano::ServiceConfig.new(appl.sid)
      #scfgs = sercfg.list('?select=service,id,solution_id,script_key,alias')
      scfgs = sercfg.list
      MrMurano::Verbose.whirly_stop
    else
      sercfg = MrMurano::ServiceConfig.new(MrMurano::SolutionId::INVALID_SID)
      scfgs = []
    end

    scfgs.select! { |s| pids.include? s[:service] }

    io = File.open(options.output, 'w') if options.output

    if options.idonly
      headers = [:service]
      scfgs = scfgs.map { |row| [row[:service]] }
    elsif !options.all
      headers = %i[name script_key service]
      scfgs = scfgs.map { |r| headers.map { |h| r[h] } }
    else
      headers = (scfgs.first || {}).keys
      scfgs = scfgs.map { |r| headers.map { |h| r[h] } }
    end

    sercfg.outf(scfgs, io) do |dd, ios|
      if options.idonly
        ios.puts dd.join(' ')
      else
        MrMurano::Verbose.tabularize(
          {
            headers: headers.map(&:to_s),
            rows: dd,
          },
          ios,
        )
      end
    end
    io.close unless io.nil?
  end
end
alias_command 'assign list', 'link list'
alias_command 'links list', 'link list'

command 'link set' do |c|
  c.syntax = 'murano link set'
  c.summary = %(Link a solution to an event handler)
  c.description = %(
Link a solution to an event handler of another solution.
  ).strip

  c.action do |args, _options|
    c.verify_arg_count!(args)
    # For now, link links the one product to the one application.
    # LATER: Users can link any solutions with Interface service.
    # FIXME: Should probably make --product and --application options?
    #appl, prod = get_product_and_application!(skip_verify: true)
    # 2017-07-03: On second thought, do verify, so we fetch the
    # correct solution name to use as "script_key".
    appl, prod = get_product_and_application!(skip_verify: false)
    link_opts = { warn_on_conflict: true }
    link_solutions(appl, prod, link_opts)
  end
end
alias_command 'assign set', 'link set'

command 'link unset' do |c|
  c.syntax = 'murano link unset [product]'
  c.summary = %(Unlink a solution)
  c.description = %(
Unlink a solution.
  ).strip

  c.action do |args, _options|
    c.verify_arg_count!(args)

    #appl, prod = get_product_and_application!(skip_verify: true)
    # 2017-07-03: On second thought, do not skip_verify, so we get the soln name.
    appl, prod = get_product_and_application!(skip_verify: false)

    sercfg = MrMurano::ServiceConfig.new(appl.sid)
    MrMurano::Verbose.whirly_msg 'Fetching services...'
    #scfgs = sercfg.list('?select=service,id,solution_id,script_key,alias')
    scfgs = sercfg.search(prod.sid)
    MrMurano::Verbose.whirly_stop

    if scfgs.length > 1
      sercfg.warning "More than one service configuration found: #{scfgs}"
    elsif scfgs.empty?
      sercfg.warning 'No matching service configurations found; nothing to unlink'
      #exit 1
    end

    sercfg.debug "Found #{scfgs.length} configurations to unlink from the Application"

    scfgs.each do |svc|
      sercfg.debug "Deleting #{svc[:service]} : #{svc[:script_key]} : #{svc[:id]}"
      ret = sercfg.remove(svc[:id])
      if !ret.nil?
        msg = "Unlinked ‘#{svc[:script_key]}’"
        msg += " from #{appl.quoted_name}" unless appl.quoted_name.to_s.empty?
        say(msg)
      else
        sercfg.warning "Failed to unlink ‘#{svc[:id]}’"
      end
    end

    MrMurano::Verbose.whirly_msg 'Fetching handlers...'
    evthlr = MrMurano::EventHandlerSolnApp.new(appl.sid)
    hdlrs = evthlr.search(prod.sid)
    #evt_hlr_exists = hdlrs.any?
    MrMurano::Verbose.whirly_stop

    if hdlrs.length > 1
      sercfg.warning "More than one event handler found: #{hdlrs}"
    elsif hdlrs.empty?
      sercfg.warning 'No matching event handlers found; nothing to delete'
      #exit 1
    end

    hdlrs.each do |evth|
      evthlr.debug "Deleting #{evth[:service]} : #{evth[:alias]} : #{evth[:id]}"
      ret = evthlr.remove(evth[:id])
      if !ret.nil?
        msg = "Removed ‘#{evth[:alias]}’"
        msg += " from #{appl.quoted_name}" unless appl.quoted_name.to_s.empty?
        say(msg)
      else
        MrMurano::Verbose.warning "Failed to remove handler ‘#{svc[:id]}’"
      end
    end
  end
end
alias_command 'assign unset', 'link unset'

def link_solutions(appl, prod, options)
  warn_on_conflict = options[:warn_on_conflict] || false
  verbose = options[:verbose] || false

  if appl.nil? || appl.sid.to_s.empty? || prod.nil? || prod.sid.to_s.empty?
    msg = 'Missing Application and/or Product; nothing to link'
    if warn_on_conflict
      sercfg.warning msg
    else
      say(msg)
    end
    return
  end

  # Get services for application, and look for product service.
  sercfg = MrMurano::ServiceConfig.new(appl.sid)
  MrMurano::Verbose.whirly_msg 'Fetching services...'
  scfgs = sercfg.search(prod.sid)
  svc_cfg_exists = scfgs.any?
  MrMurano::Verbose.whirly_stop

  # Create the service configuration.
  unless svc_cfg_exists
    MrMurano::Verbose.whirly_msg 'Linking solutions...'
    # Call Murano.
    _ret = sercfg.create(prod.sid, prod.name) do |request, http|
      response = http.request(request)
      MrMurano::Verbose.whirly_stop
      if response.is_a?(Net::HTTPSuccess)
        say("Linked #{prod.quoted_name} to #{appl.quoted_name}")
      elsif response.is_a?(Net::HTTPConflict)
        svc_cfg_exists = true
      else
        MrMurano::Verbose.error(
          "Unable to link solutions: ‘#{Rainbow(response.message).underline}’"
        )
        sercfg.showHttpError(request, response)
      end
    end
  end
  if svc_cfg_exists
    msg = 'Solutions already linked'
    if warn_on_conflict
      sercfg.warning msg
    else
      say(msg)
    end
  end
  puts '' if verbose

  # Get event handlers for application, and look for product event handler.
  MrMurano::Verbose.whirly_msg 'Fetching handlers...'
  evthlr = MrMurano::EventHandlerSolnApp.new(appl.sid)
  hdlrs = evthlr.search(prod.sid)
  evt_hlr_exists = hdlrs.any?
  MrMurano::Verbose.whirly_stop

  # Create the event handler, using a simple script,
  # like the web UI does (yeti yeti spaghetti).
  unless evt_hlr_exists
    MrMurano::Verbose.whirly_msg 'Setting default event handler...'
    # Call Murano.
    evthlr.default_event_script(prod.sid) do |request, http|
      response = http.request(request)
      MrMurano::Verbose.whirly_stop
      if response.is_a?(Net::HTTPSuccess)
        say('Created default event handler')
      elsif response.is_a?(Net::HTTPConflict)
        evt_hlr_exists = true
      else
        MrMurano::Verbose.error(
          "Failed to create default event handler: ‘#{Rainbow(response.message).underline}’"
        )
        evthlr.showHttpError(request, response)
      end
    end
  end
  if evt_hlr_exists
    msg = 'Event handler already created'
    if warn_on_conflict
      sercfg.warning msg
    else
      say(msg)
    end
  end
  puts '' if verbose
end


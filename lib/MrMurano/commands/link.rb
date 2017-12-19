# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

require 'MrMurano/Account'
require 'MrMurano/ReCommander'
require 'MrMurano/Solution'
require 'MrMurano/Solution-ServiceConfig'
require 'MrMurano/SolutionId'

MSG_SERVICE_LINKS_NONE_FOUND = 'No service links found' unless defined? MSG_SERVICE_LINKS_NONE_FOUND

command :link do |c|
  c.syntax = %(murano link)
  c.summary = %(Use the link commands to manage solution links)
  c.description = %(
Use the link commands to manage solution links.
  ).strip
  c.project_not_required = true
  c.subcmdgrouphelp = true

  c.action do |_args, _options|
    ::Commander::UI.enable_paging unless $cfg['tool.no-page']
    say(MrMurano::SubCmdGroupHelp.new(c).get_help)
  end
end

command 'link list' do |c|
  c.syntax = 'murano link list [--options]'
  c.summary = %(List the solutions that are linked)
  c.description = %(
List the solutions that are linked.
  ).strip

  # MAYBE: Here and elsewhere: hyphenate, e.g., --id-only
  c.option '--idonly', 'Only return the ids'
  #c.option '--[no-]brief', 'Show fewer fields: only name, key, and service'
  c.option '--[no-]full', 'Show all fields, not just name, key, and service'
  c.option '--[no-]all', 'Show links for all Solutions in Business, not just Project'

  c.action do |args, options|
    c.verify_arg_count!(args)

    MrMurano::Verbose.whirly_start('Fetching product list...')
    biz = MrMurano::Business.new
    products = biz.products
    MrMurano::Verbose.whirly_stop
    pids = products.map(&:api_id)

    sol_opts = { biz: biz, type: :application }
    sol_opts[:match_api_id] = $cfg['application.id'] unless options.all
    appl = solution_find_or_create(**sol_opts)

    if !appl.nil?
      MrMurano::Verbose.whirly_msg('Fetching application services...')
      sercfg = MrMurano::ServiceConfig.new(appl.api_id)
      #scfgs = sercfg.list('?select=service,id,solution_id,script_key,alias')
      scfgs = sercfg.list
      MrMurano::Verbose.whirly_stop
    else
      sercfg = MrMurano::ServiceConfig.new(MrMurano::SolutionId::INVALID_API_ID)
      scfgs = []
    end

    scfgs.select! { |s| pids.include? s[:service] }
    # MAYBE/2017-08-16: filter by $cfg['product.id'] if !options.all

    io = File.open(options.output, 'w') if options.output

    if options.idonly
      headers = [:service]
      scfgs = scfgs.map { |row| [row[:service]] }
    elsif !options.full
      headers = %i[name script_key service]
      scfgs = scfgs.map { |r| headers.map { |h| r[h] } }
    else
      headers = (scfgs.first || {}).keys
      scfgs = scfgs.map { |r| headers.map { |h| r[h] } }
    end

    sercfg.outf(scfgs, io) do |dd, ios|
      if options.idonly
        ios.puts dd.join(' ')
      elsif dd.any?
        MrMurano::Verbose.tabularize(
          {
            headers: headers.map(&:to_s),
            rows: dd,
          },
          ios,
        )
      else
        MrMurano::Verbose.error(MSG_SERVICE_LINKS_NONE_FOUND)
        exit 0
      end
    end
    io.close unless io.nil?
  end
end
alias_command 'assign list', 'link list'
alias_command 'links list', 'link list'

command 'link set' do |c|
  c.syntax = 'murano link set [--options] [<product-id> [<application-id>]]'
  c.summary = %(Link a solution to an event handler)
  c.description = %(
Link a solution to an event handler of another solution.
  ).strip

  # Add soln pickers: --application* and --product*
  cmd_option_application_pickers(c)
  cmd_option_product_pickers(c)

  c.action do |args, options|
    c.verify_arg_count!(args, 2)
    pid = args.shift
    aid = args.shift
    sol_a, sol_b = get_two_solutions!(aid, pid, **options.__hash__, skip_verify: false)
    link_opts = { warn_on_conflict: true }
    link_solutions(sol_a, sol_b, link_opts)
  end
end
alias_command 'assign set', 'link set'

command 'link unset' do |c|
  c.syntax = 'murano link unset [--options] [<product-id> [<application-id>]]'
  c.summary = %(Unlink a solution from an event handler)
  c.description = %(
Unlink a solution from an event handler of another solution.
  ).strip

  # Add soln pickers: --application* and --product*
  cmd_option_application_pickers(c)
  cmd_option_product_pickers(c)

  c.action do |args, options|
    c.verify_arg_count!(args, 2)
    pid = args.shift
    aid = args.shift
    sol_a, sol_b = get_two_solutions!(aid, pid, **options.__hash__, skip_verify: false)
    unlink_solutions(sol_a, sol_b)
  end
end
alias_command 'assign unset', 'link unset'

def link_solutions(sol_a, sol_b, options)
  warn_on_conflict = options[:warn_on_conflict] || false
  verbose = options[:verbose] || false

  if sol_a.nil? || sol_a.api_id.to_s.empty? || sol_b.nil? || sol_b.api_id.to_s.empty?
    msg = 'Missing Solution(s) (Applications or Products): Nothing to link'
    if warn_on_conflict
      sercfg.warning msg
    else
      say(msg)
    end
    return
  end

  if sol_a.is_a?(MrMurano::Product) && sol_b.is_a?(MrMurano::Application)
    # If the order is backwards, Murano will return
    #   Net::HTTPFailedDependency/424 "No such Service XXX"
    tmp = sol_a
    sol_a = sol_b
    sol_b = tmp
    # MAYBE/2017-08-16: Are there plans for linking other types of things?
    #   What about Application to Application, or Product to Product?
  end

  # Get services for solution to which being linked (application),
  # and look for linkee (product) service.
  sercfg = MrMurano::ServiceConfig.new(sol_a.api_id)
  MrMurano::Verbose.whirly_msg 'Fetching services...'
  scfgs = sercfg.search(sol_b.api_id)
  svc_cfg_exists = scfgs.any?
  MrMurano::Verbose.whirly_stop

  # Create the service configuration.
  unless svc_cfg_exists
    MrMurano::Verbose.whirly_msg 'Linking solutions...'
    # Call Murano.
    _ret = sercfg.create(sol_b.api_id, sol_b.name) do |request, http|
      response = http.request(request)
      MrMurano::Verbose.whirly_stop
      if response.is_a?(Net::HTTPSuccess)
        say("Linked #{sol_b.quoted_name} to #{sol_a.quoted_name}")
      elsif response.is_a?(Net::HTTPConflict)
        svc_cfg_exists = true
      else
        resp_msg = MrMurano::Verbose.fancy_ticks(Rainbow(response.message).underline)
        MrMurano::Verbose.error("Unable to link solutions: #{resp_msg}")
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
  evthlr = MrMurano::EventHandlerSolnApp.new(sol_a.api_id)
  hdlrs = evthlr.search(sol_b.api_id)
  evt_hlr_exists = hdlrs.any?
  MrMurano::Verbose.whirly_stop

  # Create the event handler, using a simple script,
  # like the web UI does (yeti yeti spaghetti).
  unless evt_hlr_exists
    MrMurano::Verbose.whirly_msg 'Setting default event handler...'
    # Call Murano.
    evthlr.default_event_script(sol_b.api_id) do |request, http|
      response = http.request(request)
      MrMurano::Verbose.whirly_stop
      if response.is_a?(Net::HTTPSuccess)
        say('Created default event handler')
      elsif response.is_a?(Net::HTTPConflict)
        evt_hlr_exists = true
      else
        resp_msg = MrMurano::Verbose.fancy_ticks(Rainbow(response.message).underline)
        MrMurano::Verbose.error("Failed to create default event handler: #{resp_msg}")
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

def unlink_solutions(sol_a, sol_b)
  sercfg = MrMurano::ServiceConfig.new(sol_a.api_id)
  MrMurano::Verbose.whirly_msg 'Fetching services...'
  #scfgs = sercfg.list('?select=service,id,solution_id,script_key,alias')
  scfgs = sercfg.search(sol_b.api_id)
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
      msg = "Unlinked #{MrMurano::Verbose.fancy_ticks(svc[:script_key])}"
      msg += " from #{sol_a.quoted_name}" unless sol_a.quoted_name.to_s.empty?
      say(msg)
    else
      sercfg.warning "Failed to unlink #{MrMurano::Verbose.fancy_ticks(svc[:id])}"
    end
  end

  MrMurano::Verbose.whirly_msg 'Fetching handlers...'
  evthlr = MrMurano::EventHandlerSolnApp.new(sol_a.api_id)
  hdlrs = evthlr.search(sol_b.api_id)
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
      msg = "Removed #{MrMurano::Verbose.fancy_ticks(evth[:alias])}"
      msg += " from #{sol_a.quoted_name}" unless sol_a.quoted_name.to_s.empty?
      say(msg)
    else
      svc_id = MrMurano::Verbose.fancy_ticks(svc[:id])
      MrMurano::Verbose.warning "Failed to remove handler #{svc_id}"
    end
  end
end


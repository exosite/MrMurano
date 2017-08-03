# Last Modified: 2017.07.26 /coding: utf-8
# frozen_string_literal: true

# Copyright © 2016-2017 Exosite LLC.
# License: MIT. See LICENSE.txt.
#  vim:tw=0:ts=2:sw=2:et:ai

require 'MrMurano/Solution'
require 'MrMurano/commands/solution'

command :domain do |c|
  c.syntax = %(murano domain)
  c.summary = %(Print the domain for this solution)
  c.description = %(
Print the domain for this solution.
  ).strip
  c.option '--[no-]raw', %(Don't add scheme (default with brief))
  c.option '--[no-]brief', %(Show the URL but not the solution ID)

  # Add the flags: --type, --ids, --names, --[no]-header.
  command_add_solution_pickers c

  c.action do |args, options|
    options.default(raw: true) if options.brief

    c.verify_arg_count!(args)

    # Get a list of solutions. Implicitly calls
    # command_defaults_solution_picker to set options defaults.
    solz = must_fetch_solutions!(options)

    domain_s = MrMurano::Verbose.pluralize?('domain', solz.length)
    MrMurano::Verbose.whirly_start("Fetching #{domain_s}...")
    solz.each do |soln|
      # Get the solution info; stores the result in the Solution object.
      _meta = soln.info_safe
    end
    MrMurano::Verbose.whirly_stop

    solz.each do |sol|
      if !options.brief
        say(sol.pretty_desc(add_type: true, raw_url: options.raw))
      elsif options.raw
        say(sol.domain)
      else
        say("https://#{sol.domain}")
      end
    end
  end
end
alias_command 'domain product', 'domain', '--type', 'product'
alias_command 'domain products', 'domain', '--type', 'product'
alias_command 'domain prod', 'domain', '--type', 'product'
alias_command 'domain prods', 'domain', '--type', 'product'
alias_command 'domain application', 'domain', '--type', 'application'
alias_command 'domain applications', 'domain', '--type', 'application'
alias_command 'domain app', 'domain', '--type', 'application'
alias_command 'domain apps', 'domain', '--type', 'application'


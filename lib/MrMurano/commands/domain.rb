# Last Modified: 2017.08.16 /coding: utf-8
# frozen_string_literal: true

# Copyright © 2016-2017 Exosite LLC.
# License: MIT. See LICENSE.txt.
#  vim:tw=0:ts=2:sw=2:et:ai

require 'MrMurano/ReCommander'
require 'MrMurano/Solution'
require 'MrMurano/commands/solution'

command :domain do |c|
  c.syntax = %(murano domain)
  c.summary = %(Print the domain for this solution)
  c.description = %(
Print the domain for this solution.
  ).strip

  c.option '--[no-]raw', %(Don't add scheme (default with brief))
  c.option '--[no-]brief', %(Show fewer fields: only the URL)
  c.option '--[no-]all', 'Show domains for all Solutions in Business, not just Project'

  # Add flag: --type [application|product|all].
  cmd_add_solntype_pickers(c)

  c.action do |args, options|
    c.verify_arg_count!(args)
    options.default(all: false)
    options.default(raw: true) if options.brief
    cmd_defaults_solntype_pickers(options)

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
alias_command 'domain application', 'domain', '--type', 'application'
alias_command 'domain product', 'domain', '--type', 'product'
alias_command 'application domain', 'domain', '--type', 'application'
alias_command 'product domain', 'domain', '--type', 'product'


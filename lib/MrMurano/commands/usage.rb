# Last Modified: 2017.07.26 /coding: utf-8
# frozen_string_literal: true

# Copyright © 2016-2017 Exosite LLC.
# License: MIT. See LICENSE.txt.
#  vim:tw=0:ts=2:sw=2:et:ai

require 'MrMurano/Solution'

command :usage do |c|
  c.syntax = %(murano usage)
  c.summary = %(Get usage info for solution(s))
  c.description = %(
Get usage info for solution(s).
  ).strip
  # Add the flags: --type, --ids, --names, --[no]-header.
  command_add_solution_pickers(c)

  c.action do |args, options|
    c.verify_arg_count!(args)

    # Get a list of solutions. Implicitly calls
    # command_defaults_solution_picker to set options defaults.
    solz = must_fetch_solutions!(options)

    solsages = []
    MrMurano::Verbose.whirly_start('Fetching usage...')
    solz.each do |sol|
      solsages += [[sol, sol.usage]]
    end
    MrMurano::Verbose.whirly_stop

    solsages.each do |sol, usage|
      sol.outf(usage) do |dd, ios|
        ios.puts(sol.pretty_desc(add_type: true)) if options.header
        headers = ['', :Quota, :Daily, :Monthly, :Total]
        rows = []
        dd.each_pair do |key, value|
          quota = value[:quota] || {}
          usage = value[:usage] || {}
          rows << [
            key,
            quota[:daily],
            usage[:calls_daily],
            usage[:calls_monthly],
            usage[:calls_total],
          ]
        end
        sol.tabularize({ headers: headers, rows: rows }, ios)
      end
    end
  end
end
alias_command 'usage product', 'usage', '--type', 'product'
alias_command 'usage products', 'usage', '--type', 'product'
alias_command 'usage prod', 'usage', '--type', 'product'
alias_command 'usage prods', 'usage', '--type', 'product'
alias_command 'usage application', 'usage', '--type', 'application'
alias_command 'usage applications', 'usage', '--type', 'application'
alias_command 'usage app', 'usage', '--type', 'application'
alias_command 'usage apps', 'usage', '--type', 'application'


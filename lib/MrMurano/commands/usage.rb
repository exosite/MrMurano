# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

require 'MrMurano/ReCommander'
require 'MrMurano/Solution'

command :usage do |c|
  c.syntax = %(murano usage)
  c.summary = %(Get usage info for the Application and Product)
  c.description = %(
Get usage info for the Application and Product.
  ).strip
  c.project_not_required = true

  # Add flag: --type [application|product|all].
  cmd_add_solntype_pickers(c)

  c.option '--[no-]all', 'Show usage for all Solutions in Business'
  c.option(
    '--[no-]header', %(Output solution descriptions (default: true))
  )

  c.action do |args, options|
    c.verify_arg_count!(args)
    options.default(all: false, header: true)
    cmd_defaults_solntype_pickers(options)

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
alias_command 'usage application', 'usage', '--type', 'application'
alias_command 'usage product', 'usage', '--type', 'product'
alias_command 'application usage', 'usage', '--type', 'application'
alias_command 'product usage', 'usage', '--type', 'product'


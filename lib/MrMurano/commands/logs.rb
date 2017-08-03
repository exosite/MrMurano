# Last Modified: 2017.07.26 /coding: utf-8
# frozen_string_literal: true

# Copyright © 2016-2017 Exosite LLC.
# License: MIT. See LICENSE.txt.
#  vim:tw=0:ts=2:sw=2:et:ai

require 'MrMurano/makePretty'
require 'MrMurano/Solution'

command :logs do |c|
  c.syntax = %(murano logs [options])
  c.summary = %(Get the logs for a solution)
  c.description = %(
Get the logs for a solution.
  ).strip
  c.option '-f', '--follow', %(Follow logs from server)
  c.option '--[no-]pretty', %(Reformat JSON blobs in logs.)
  c.option '--[no-]localtime', %(Adjust Timestamps to be in local time)
  c.option '--raw', %(Don't do any formating of the log data)
  # FIXME/2017-06-23: It'd be nice to allow :all
  #   But then we'd have to interleave output somehow with --follow,
  #   maybe using separate threads?
  # For now, command_add_solution_pickers adds --type and user must
  # specify either "application" or "product".

  # Add the flags: --type, --ids, --names, --[no]-header.
  command_add_solution_pickers c

  c.action do |args, options|
    c.verify_arg_count!(args)

    command_defaults_solution_picker(options)

    options.default pretty: true, localtime: true, raw: false

    unless options.type && options.type != :all
      MrMurano::Verbose.error 'Please specify the --type of solution'
      exit 1
    end

    if options.type == :application
      sol = MrMurano::Application.new
    elsif options.type == :product
      sol = MrMurano::Product.new
    else
      MrMurano::Verbose.error "Unknown --type specified: #{options.type}"
      exit 1
    end

    if options.follow
      # Open a lasting connection and continually feed makePretty().
      begin
        sol.get('/logs?polling=true') do |request, http|
          request['Accept-Encoding'] = 'None'
          http.request(request) do |response|
            remainder = ''
            response.read_body do |chunk|
              chunk = remainder + chunk unless remainder.empty?

              # For all complete JSON blobs, make them pretty.
              chunk.gsub!(/\{(?>[^}{]+|\g<0>)*\}/m) do |m|
                if options.raw
                  puts m
                else
                  begin
                    js = JSON.parse(
                      m,
                      allow_nan: true,
                      symbolize_names: true,
                      create_additions: false,
                    )
                    puts MrMurano::Pretties.makePretty(js, options)
                  rescue
                    sol.error '=== JSON parse error, showing raw instead ==='
                    puts m
                  end
                end
                '' #remove (we're kinda abusing gsub here.)
              end

              # Is there an incomplete one?
              chunk.match(/(\{.*$)/m) do |mat|
                remainder = mat[1]
              end
            end
          end
        end
      # rubocop:disable Lint/HandleExceptions: Do not suppress exceptions.
      rescue Interrupt => _
      end

    else
      ret = sol.get('/logs')

      if ret.is_a?(Hash) && ret.key?(:items)
        ret[:items].reverse.each do |line|
          if options.raw
            puts line
          else
            puts MrMurano::Pretties.makePretty(line, options)
          end
        end
      else
        sol.error "Couldn't get logs: #{ret}"
        # 2017-06-23: Shouldn't this be exit? What're we breaking out of?
        break
      end

    end
  end
end
alias_command 'product logs', 'logs', '--type', 'product'
alias_command 'application logs', 'logs', '--type', 'application'
# Should we follow suit and do what the murano domain command does?
alias_command 'logs product', 'logs', '--type', 'product'
alias_command 'logs products', 'logs', '--type', 'product'
alias_command 'logs prod', 'logs', '--type', 'product'
alias_command 'logs prods', 'logs', '--type', 'product'
alias_command 'logs application', 'logs', '--type', 'application'
alias_command 'logs applications', 'logs', '--type', 'application'
alias_command 'logs app', 'logs', '--type', 'application'
alias_command 'logs apps', 'logs', '--type', 'application'


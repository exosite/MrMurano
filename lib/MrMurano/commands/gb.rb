# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

require 'pp'

# You don't need this.
# To use this:
# - mkdir -p ~/.murano/plugins
# - ln gb.rb ~/.murano/plugins

command :_gb do |c|
  c.syntax = %(murano _gb <class> <method> (<args>))
  c.summary = %(Call internal class methods directly)
  c.description = %(
Call internal class methods directly.
  ).strip
  c.project_not_required = true

  # Will a plugin need to let user restrict the solution type?
  # Add flag: --type [application|product|all].
  cmd_add_solntype_pickers(c)

  c.action do |args, options|
    # SKIP: c.verify_arg_count!(args)
    cmd_defaults_solntype_pickers(options)

    cls = args[0]
    meth = args[1].to_sym
    args.shift(2)

    begin
      gb = Object.const_get("MrMurano::#{cls}").new
      if gb.respond_to? meth
        ret = gb.__send__(meth, *args)
        gb.outf(ret) { |o, _i| pp o }
      else
        say_error "'#{cls}' doesn't '#{meth}'"
      end
    rescue StandardError => e
      say_error e.message
      pp e
    end
  end
end


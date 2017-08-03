# Last Modified: 2017.07.26 /coding: utf-8
# frozen_string_literal: true

# Copyright © 2016-2017 Exosite LLC.
# License: MIT. See LICENSE.txt.
#  vim:tw=0:ts=2:sw=2:et:ai

require 'MrMurano/verbosing'

module MrMurano
  class Hooked
    include Verbose

    def initialize(section)
      @section = section
    end

    attr_reader :section

    def check_run_pre_hook
      prehook = $cfg["#{section}.pre-hook"]
      return if prehook.nil?
      return if prehook.empty?
      verbose "calling pre-hook: #{prehook}"
      system(prehook)
    end

    def check_run_post_hook
      posthook = $cfg["#{section}.post-hook"]
      return if posthook.nil?
      return if posthook.empty?
      verbose "calling post-hook: #{posthook}"
      system(posthook)
    end
  end
end

module Commander
  class Command
    # A command sets project_not_required if it
    # can run from without a project directory.
    attr_accessor :project_not_required
    # A command sets restrict_to_cur_dir if it
    # should not climb the directory hierarchy
    # in search of a .murano/config file.
    attr_accessor :restrict_to_cur_dir
    # A command sets prompt_if_logged_off if it
    # is okay to ask the user for their password.
    attr_accessor :prompt_if_logged_off

    def verify_arg_count!(args, max_args=0, mandatory=[])
      if max_args.zero?
        if args.count > 0
          MrMurano::Verbose.error('Not expecting any arguments')
          exit 2
        end
      elsif args.count > max_args
        MrMurano::Verbose.error("Not expecting more than #{max_args} arguments")
        exit 2
      elsif args.count < mandatory.length
        (args.count..(mandatory.length - 1)).to_a.each do |ix|
          MrMurano::Verbose.error(mandatory[ix])
        end
        exit 2
      end
    end
  end

  class Runner
    attr_accessor :command_exit

    # run_active_command is called by commander-rb's at_exit hook.
    # We override -- monkey patch -- it to do other stuff.
    alias old_run_active_command run_active_command
    def run_active_command
      exit @command_exit if @command_exit
      section = active_command.name
      hooked = MrMurano::Hooked.new(section)
      hooked.check_run_pre_hook

      begin
        old_run_active_command
      rescue MrMurano::ConfigError => err
        # Clear whirly if it was running.
        MrMurano::Verbose.whirly_stop
        MrMurano::Verbose.error err.message
        exit 1
      rescue LocalJumpError => _err
        # This happens when you `return` from a command, since
        # commands are blocks, and returning from a block would
        # really mean returning from the thing running the block,
        # which would be bad. So Ruby barfs instead.
        return
      rescue StandardError => _err
        raise
      end

      hooked.check_run_post_hook
    end

    alias old_parse_global_options parse_global_options
    def parse_global_options
      defopts = ($cfg["#{active_command.name}.options"] || '').split
      @args.push(*defopts)
      begin
        old_parse_global_options
      rescue OptionParser::MissingArgument => err
        if err.message.start_with?('missing argument:')
          puts err.message
        else
          MrMurano::Verbose.error(
            "There was a problem interpreting the options: ‘#{err.message}’"
          )
        end
        exit 2
      end
    end

    # Weird. --help doesn't work if other flags also specified.
    # E.g., this shows the help for usage:
    #   $ murano --help usage
    # but if a flag is added, the command gets run, e.g.,
    #   $ murano usage --ids 1234 --help
    # ignore the --help and runs the usage command.
    # ([lb] walked the code and it looks like when Commander tries to
    # validate the args, it doesn't like the --ids flag (maybe because
    # the "help" command is being used to validate?). Then it removes
    # the --ids flags (after --help was previously removed) and tries
    # the command *again* (in gems/commander-4.4.3/lib/commander/runner.rb,
    # look for the comment, "Remove the offending args and retry").
    #
    # 2017-06-14: [lb] tried override run! here to show help correctly
    # in this use case, but I could not get it to work. Oh, well... a
    # minor annoyance; just live with it, I guess.
  end
end


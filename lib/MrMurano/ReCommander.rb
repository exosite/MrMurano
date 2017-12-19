# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

require 'optparse'
require 'MrMurano/optparse'
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
    # A command sets subcmdgrouphelp if it's help.
    attr_accessor :subcmdgrouphelp

    def verify_arg_count!(args, max_args=0, mandatory=[])
      if !max_args.nil? && max_args.zero?
        if args.count > 0
          MrMurano::Verbose.error('Not expecting any arguments')
          exit 2
        end
      elsif !max_args.nil? && args.count > max_args
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
      exit @command_exit if defined?(@command_exit) && @command_exit
      section = active_command.name
      hooked = MrMurano::Hooked.new(section)
      hooked.check_run_pre_hook

      begin
        old_run_active_command
      rescue LocalJumpError => _err
        # This happens when you `return` from a command, since
        # commands are blocks, and returning from a block would
        # really mean returning from the thing running the block,
        # which would be bad. So Ruby barfs instead.
        return
      rescue OptionParser::InvalidArgument => err
        MrMurano::Verbose.whirly_stop
        MrMurano::Verbose.error err.message
        exit 1
      rescue OptionParser::InvalidOption => err
        MrMurano::Verbose.whirly_stop
        MrMurano::Verbose.error err.message
        MrMurano::Verbose.error 'invalid command' if section == 'help'
        exit 1
      rescue OptionParser::MissingArgument => err
        MrMurano::Verbose.whirly_stop
        MrMurano::Verbose.error err.message
        exit 1
      rescue OptionParser::NeedlessArgument => err
        MrMurano::Verbose.whirly_stop
        MrMurano::Verbose.error err.message
        pattern = /^needless argument: --(?<arg>[_a-zA-Z0-9]+)=(?<val>.*)/
        md = pattern.match(err.message)
        unless md.nil?
          puts %(Try the option without the equals sign, e.g.,)
          puts %(  --#{md[:arg]} "#{md[:val]}")
        end
        exit 1
      rescue MrMurano::ConfigError => err
        # Clear whirly if it was running.
        MrMurano::Verbose.whirly_stop
        MrMurano::Verbose.error err.message
        exit 1
      rescue StandardError => _err
        raise
      end

      hooked.check_run_post_hook
    end

    alias old_parse_global_options parse_global_options
    def parse_global_options
      # User can specify, e.g., status.options, to set options for specific commands.
      defopts = ($cfg["#{active_command.name}.options"] || '').split
      @args.push(*defopts)
      help_hack
      parse_global_options_real
    end

    def parse_global_options_real
      old_parse_global_options
    rescue OptionParser::MissingArgument => err
      if err.message.start_with?('missing argument:')
        puts err.message
      else
        err_msg = MrMurano::Verbose.fancy_ticks(err.message)
        MrMurano::Verbose.error(
          "There was a problem interpreting the options: #{err_msg}"
        )
      end
      exit 2
    end

    # 2017-08-22: Commander's help infrastructure is either really weak,
    # or we did something elsewhere that seriously cripples it. In any
    # case, this fixes all its quirks.
    def help_hack
      do_help = fix_args
      show_alias_help_maybe! if do_help
    end

    def help_opts
      %w[-h --help help].freeze
    end

    def vers_opts
      %w[-v --version].freeze
    end

    def fix_args
      # If `murano --help` is specified, let rb-commander handle it.
      # But if `murano command --help` is specified, don't let cmdr
      # handle it, otherwise it just shows the command description,
      # but not any of the subcommands (our SubCmdGroupContext code).
      # Note: not checking help_opts here, which includes 'help', because
      #   'help' might really be a command argument (e.g., a solution name).
      # Note: `murano -v`'s active_command is 'help'.
      do_help = (@args & %w[-h --help]).any? || active_command.name == 'help'
      if do_help
        # If there are options in addition to --help, then Commander
        # runs the command! So remove all options.
        #
        # E.g., this shows the help for usage:
        #   $ murano --help usage
        # but if a flag is added, the command gets run, e.g.,
        #   $ murano usage --id 1234 --help
        # runs the usage command.
        #
        # I [lb] walked the code and it looks like when Commander tries to
        # validate the args, it doesn't like the --id flag (maybe because
        # the "help" command is being used to validate, and it does not
        # define any options?). Then it removes the --id switch (after the
        # --help switch was previously removed) and tries the command *again*
        # (in gems/commander-4.4.3/lib/commander/runner.rb, look for the
        # comment, "Remove the offending args and retry"). So in the example
        # given above, `murano usage --id 1234 --help`, both the `--id` flag
        # and `--help` flag are moved from @args, and then `murano usage 1234`
        # is executed (and args are not validated by Commander but merely passed
        # to the command action, so `usage` gets args=['1234']). Whadda wreck.
        reject_next = false
        @args.reject! do |arg|
          reject = false
          if reject_next
            reject = true
            reject_next = false
          elsif arg.start_with?('-') && !help_opts.include?(arg) && !vers_opts.include?(arg)
            reject = true
            # See if the next argument should also be consumed.
            arg_opts = @options.select do |opt|
              if arg =~ /^-[^-]/
                # Single char abbrev: look for exact match.
                opt[:switches].include?(arg)
              else
                # Long switch: Commander matches abbrevs of longs...
                opt[:switches].any? { |oarg| oarg =~ /^#{arg}/ }
              end
            end
            if arg =~ /^--/
              exact = arg_opts.select do |opt|
                opt[:switches].include?(arg) || opt[:switches].any? do |sw|
                  sw.start_with?(arg + ' ')
                end
              end
              arg_opts = exact unless exact.empty?
            end
            if arg_opts.length > 1
              # MAYBE/2017-08-23: Always do this check, not just for help.
              ambig = MrMurano::Verbose.fancy_ticks(arg)
              match = arg_opts.map do |opt|
                opt[:switches].map { |sw| MrMurano::Verbose.fancy_ticks(sw) }.join('|')
              end
              match = match.flatten
              match[-1] = "and #{match[-1]}" if match.length > 1
              match = match.join(', ')
              MrMurano::Verbose.error("Ambiguous option: #{ambig} matches: #{match}")
              exit 2
            elsif arg_opts.length == 1
              if arg_opts.first[:switches].any? { |opt| opt.start_with?('--') && opt.include?(' ') }
                # There's a space in the --long setting, e.g., '--config KEY=VAL',
                # so we know there's an argument following.
                reject_next = true
              end
            end
          end
          reject
        end
      end
      @purargs = @args - help_opts
      return do_help if active_command.name == 'help'
      # Any command other than `murano help` or `murano --help`.
      return do_help if !do_help || active_command.name.include?(' ')
      # This is a single-word command, e.g., 'link', not 'link list',
      #   as in `murano link --help`, not `murano link list --help`.
      # Positional parameters break Commander. E.g.,
      #   $ murano --help config application.id
      #   invalid command. Use --help for more information
      # so remove any remaining --options and use the first term.
      @args -= help_opts
      @args = @args[0..0]
      # Add back in the --help if the command is not a subcommand help.
      @args.push('--help') unless active_command.subcmdgrouphelp
      do_help
    end

    def show_alias_help_maybe!
      return unless alias?(command_name_from_args) || (active_command.name == 'help' && @args.length > 1)
      # Why, oh why, Commander, do you flake out on aliases?
      # E.g.,
      #   $ murano product --help
      #   invalid command. Use --help for more information
      # Though it sometimes work, like with:
      #   $ murano --help product device enable
      # but only because Commander shows help for the 'device' command.
      # I.e., this doesn't work: `murano product push --help`
      # So we'll just roll our own help for aliases!
      @args -= help_opts
      cli_cmd = MrMurano::Verbose.fancy_ticks(@purargs.join(' '))
      if active_command.name == 'help'
        arg_cmd = @args.join(' ')
      else
        arg_cmd = command_name_from_args
      end
      mur_msg = ''
      if @aliases[arg_cmd].nil?
        matches = @aliases.keys.find_all { |key| key.start_with?('arg_cmd') }
        matches = @aliases.keys.find_all { |key| key.start_with?(@args[0]) } if matches.empty?
        unless matches.empty?
          matches = matches.map { |match| MrMurano::Verbose.fancy_ticks(match) }
          matches = matches.sort.join(', ')
          mur_msg = %(The #{cli_cmd} command includes: #{matches})
        end
      else
        mur_cmd = []
        mur_cmd += [active_command.name] if active_command.name != 'help'
        mur_cmd += @aliases[arg_cmd] unless @aliases[arg_cmd].empty?
        mur_cmd = mur_cmd.join(' ')
        #mur_cmd = active_command.name if mur_cmd.empty?
        mur_cmd = MrMurano::Verbose.fancy_ticks(mur_cmd)
        mur_msg = %(The #{cli_cmd} command is really: #{mur_cmd})
      end
      return if mur_msg.empty?
      puts mur_msg
      exit 0
    end
  end
end


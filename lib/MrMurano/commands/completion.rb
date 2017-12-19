# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

require 'erb'
require 'pp'
require 'MrMurano/ReCommander'

# USAGE: See: lib/MrMurano/commands.rb

class CompletionContext < ::Commander::HelpFormatter::Context
end

# rubocop:disable Style/ClassAndModuleChildren
#   "Use nested module/class definitions instead of compact style."
#   except that nested style (class [::]Commander\nclass Runner)
#   does not work.
class ::Commander::Runner
  # Not so sure this should go in Runner, but where else?

  # rubocop:disable Style/MethodName "Use snake_case for method names."

  # The shells for which we have completion templates.
  SHELL_TYPES = %i[bash zsh].freeze

  ##
  # Change the '--[no-]foo' switch into '--no-foo' and '--foo'
  def flatswitches(option)
    # if there is a --[no-]foo format, break that into two switches.
    switches = option[:switches].map do |switch|
      switch = switch.sub(/\s.*$/, '') # drop argument spec if exists.
      if switch =~ /\[no-\]/
        [switch.sub(/\[no-\]/, ''), switch.gsub(/[\[\]]/, '')]
      else
        switch
      end
    end
    switches.flatten
  end

  ##
  # If the switches take an argument, return =
  def takesArg(option, yes='=', no='')
    if option[:switches].select { |switch| switch =~ /\s\S+$/ }.empty?
      no
    else
      yes
    end
  end

  ##
  # truncate the description of an option
  def optionDesc(option)
    option[:description].sub(/\n.*$/, '')
  end

  ##
  # Get a tree of all commands and sub commands
  def cmdTree
    tree = {}
    @commands.sort.each do |name, cmd|
      levels = name.split
      pos = tree
      levels.each do |step|
        pos[step] = {} unless pos.key? step
        pos = pos[step]
      end
      pos["\0cmd"] = cmd
    end
    tree
  end

  ##
  # Get maximum depth of sub-commands.
  def cmdMaxDepth
    depth = 0
    @commands.keys.sort.each do |name|
      levels = name.split
      depth = levels.count if levels.count > depth
    end
    depth
  end

  ##
  # Alternate tree of sub-commands.
  def cmdTreeB
    tree = {}
    @commands.sort.each do |name, cmd|
      levels = name.split
      tree[levels.join(' ')] = { cmd: cmd }

      # load parent.
      left = levels[0..-2]
      right = levels[-1]
      key = left.join(' ')
      tree[key] = {} unless tree.key? key
      if tree[key].key?(:subs)
        tree[key][:subs] << right
      else
        tree[key][:subs] = [right]
      end
    end
    tree
  end
end

command :completion do |c|
  c.syntax = %(murano completion)
  c.summary = %(Generate a completion file)
  c.description = %(
Create a Tab completion file for either the Bash or Z shell.

E.g.,

  eval "$(murano completion)"

or

  murano completion > _murano
  source _murano
  ).strip
  c.project_not_required = true

  c.option '--subs', 'List sub commands'
  #c.option '--opts CMD', 'List options for subcommand'
  #c.option '--gopts', 'List global options'
  c.option(
    '--shell TYPE',
    Commander::Runner::SHELL_TYPES,
    %(Shell flavor of output (default: Bash))
  )

  # Changing direction.
  # Will poop out the file to be included as the completion script.

  c.action do |args, options|
    c.verify_arg_count!(args)
    options.default shell: :bash

    runner = ::Commander::Runner.instance

    if options.gopts
      opts = runner.instance_variable_get(:@options)
      pp opts.first
      pp runner.takesArg(opts.first)
#      opts.each do |o|
#        puts runner.optionLine o, 'GlobalOption'
#      end

    elsif options.subs
      runner.instance_variable_get(:@commands).keys.sort.each do |name|
        #desc = _cmd.instance_variable_get(:@summary) #.lines[0]
        #say "#{name}:'#{desc}'"
        say name.to_s
      end

    elsif options.opts
      cmds = runner.instance_variable_get(:@commands)
      cmd = cmds[options.opts]
      pp cmd.syntax
      # looking at OptionParser to help figure out what kind of params a switch
      # gets. And hopefully derive a completer for it
      # !!!!! OptionParser::Completion  what is this?
      opts = OptionParser.new
      cmds[options.opts].options.each do |o|
        pp opts.make_switch(o[:args])
      end

    else
      case options.shell
      when :bash
        cmpltn_tmplt = 'completion-bash.erb'
      when :zsh
        cmpltn_tmplt = 'completion-zsh.erb'
      else
        MrMurano::Verbose.error "Impossible shell option specified: #{options.shell}"
        exit 2
      end
      tmpl = ERB.new(File.read(File.join(File.dirname(__FILE__), cmpltn_tmplt)), nil, '-<>')

      pc = CompletionContext.new(runner)
      puts tmpl.result(pc.get_binding)
    end
  end
end


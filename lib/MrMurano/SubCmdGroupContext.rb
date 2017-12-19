# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

module MrMurano
  class SubCmdGroupHelp
    attr_reader :description
    attr_reader :name

    def initialize(command)
      @name = command.syntax.to_s
      @description = command.description.to_s
      @runner = ::Commander::Runner.instance
      prefix = /^#{command.name.to_s} /
      cmds = @runner.instance_variable_get(:@commands).select { |n, _| n.to_s =~ prefix }
      @commands = cmds
      als = @runner.instance_variable_get(:@aliases).select { |n, _| n.to_s =~ prefix }
      @aliases = als

      @options = {}
    end

    def program(key)
      case key
      when :name
        @name
      when :description
        @description
      when :help
        nil
      # rubocop:disable Style/EmptyElse: "Redundant else-clause."
      # Rubocop seems incorrect about this one.
      else
        nil
      end
    end

    def alias?(name)
      @aliases.include? name.to_s
    end

    def command(name)
      @commands[name.to_s]
    end

    # rubocop:disable Style/AccessorMethodName
    # "Do not prefix reader method names with get_."
    def get_help
      hf = @runner.program(:help_formatter).new(self)
      pc = Commander::HelpFormatter::ProgramContext.new(self).get_binding
      hf.template(:help).result(pc)
    end
  end
end


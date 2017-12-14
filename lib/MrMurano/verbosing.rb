# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

require 'csv'
require 'highline'
require 'inflecto'
require 'json'
require 'os'
require 'paint'
require 'pp'
require 'terminal-table'
require 'whirly'
require 'yaml'
require 'MrMurano/progress'

module MrMurano
  # Verbose is a mixin for various terminal output features.
  module Verbose
    def verbose(msg)
      MrMurano::Verbose.verbose(msg)
    end

    def self.verbose(msg)
      whirly_interject { say msg } if $cfg['tool.verbose']
    end

    def debug(msg)
      MrMurano::Verbose.debug(msg)
    end

    def self.debug(msg)
      whirly_interject { say msg } if $cfg['tool.debug']
    end

    def warning(msg)
      MrMurano::Verbose.warning(msg)
    end

    def self.warning(msg)
      whirly_interject { warn(HighLine.color(msg, :yellow)) }
    end

    def error(msg)
      MrMurano::Verbose.error(msg)
    end

    def self.error(msg)
      # See also Commander::say_error
      whirly_interject { warn(HighLine.color(msg, :red)) }
    end

    ## Output tabular data
    # +data+:: Data to write. Preferably a Hash with :headers and :rows
    # +ios+:: Output stream to write to, if nil, then use $stdout
    # Output is either a nice visual table or CSV.

    TABULARIZE_DATA_FORMAT_ERROR = 'Unexpected data format: do not know how to tabularize.'

    def tabularize(data, ios=nil)
      MrMurano::Verbose.tabularize(data, ios)
    end

    def self.tabularize(data, ios=nil)
      fmt = $cfg['tool.outformat']
      ios = $stdout if ios.nil?
      cols = nil
      rows = nil
      title = nil
      if data.is_a?(Hash)
        cols = data[:headers] if data.key?(:headers)
        rows = data[:rows] if data.key?(:rows)
        title = data[:title]
      elsif data.is_a?(Array)
        rows = data
      elsif data.respond_to?(:to_a)
        rows = data.to_a
      elsif data.respond_to?(:each)
        rows = []
        # MAYBE/2017-07-02: Does shover operator work on frozen string literals?
        data.each { |i| rows << i }
      else
        error TABULARIZE_DATA_FORMAT_ERROR
        return
      end
      if fmt =~ /csv/i
        cols = [] if cols.nil?
        rows = [[]] if rows.nil?
        CSV(ios, headers: cols, write_headers: !cols.empty?) do |csv|
          # MAYBE/2017-07-02: Does shover operator work on frozen string literals?
          rows.each { |v| csv << v }
        end
      else
        # table.
        table = Terminal::Table.new
        table.title = title unless title.nil?
        table.headings = cols unless cols.nil?
        table.rows = rows unless rows.nil?
        ios.puts table
      end
    end

    ## Format and print the object
    # Handles many of the raw 'unpolished' formats.
    def outf(obj, ios=nil)
      fmt = $cfg['tool.outformat']
      ios = $stdout if ios.nil?
      case fmt
      when /yaml/i
        ios.puts Hash.transform_keys_to_strings(obj).to_yaml
      when /pp/
        pp obj
      when /json/i
        ios.puts obj.to_json
      else # aka best.
        # sometime ‘best’ is only know by the caller, so block.
        if block_given?
          yield obj, ios
        elsif obj.is_a?(Array)
          obj.each { |i| ios.puts i.to_s }
        else
          ios.puts obj.to_s
        end
      end
    end

    def self.ask_yes_no(question, default)
      answer = default
      whirly_interject do
        confirm = ask(question)
        if default
          answer = !%w[n no].include?(confirm.downcase)
        else
          answer = %w[y ye yes].include?(confirm.downcase)
        end
      end
      answer
    end

    def ask_yes_no(question, default)
      MrMurano::Verbose.ask_yes_no(question, default)
    end

    def self.cmd_confirm_delete!(name, auto_yes, exit_msg)
      if auto_yes
        yield true if block_given?
        return true
      end
      confirmed = MrMurano::Verbose.ask_yes_no(
        "Really delete #{MrMurano::Verbose.fancy_ticks(name)}? [y/N] ", false
      )
      MrMurano::Verbose.warning(exit_msg) if !confirmed && exit_msg
      if block_given?
        yield confirmed
      elsif !confirmed
        exit 1
      end
      confirmed
    end

    def cmd_confirm_delete!(name, auto_yes, exit_msg)
      MrMurano::Verbose.cmd_confirm_delete!(name, auto_yes, exit_msg)
    end

    def self.pluralize?(word, count)
      count == 1 && word || Inflecto.pluralize(word)
    end

    def pluralize?(word, count)
      MrMurano::Verbose.pluralize?(word, count)
    end

    def self.fancy_ticks(obj)
      if $cfg.nil? || $cfg['tool.ascii'] || OS.windows?
        "'#{obj}'"
      else
        "‘#{obj}’"
      end
    end

    def fancy_ticks(obj)
      MrMurano::Verbose.fancy_ticks(obj)
    end

    # 2017-07-01: Whirly wrappers. Maybe delete someday
    #   (after replacing all MrMurano::Verbose.whirly_*
    #   with MrMurano::Progress.whirly_*).

    def whirly_start(msg)
      MrMurano::Progress.instance.whirly_start(msg)
    end

    def whirly_stop(force: false)
      MrMurano::Progress.instance.whirly_stop(force: force)
    end

    def whirly_linger
      MrMurano::Progress.instance.whirly_linger
    end

    def whirly_msg(msg)
      MrMurano::Progress.instance.whirly_msg(msg)
    end

    def whirly_pause
      MrMurano::Progress.instance.whirly_pause
    end

    def whirly_unpause
      MrMurano::Progress.instance.whirly_unpause
    end

    def whirly_interject(&block)
      MrMurano::Progress.instance.whirly_interject(&block)
    end

    def self.whirly_start(msg)
      MrMurano::Progress.instance.whirly_start(msg)
    end

    def self.whirly_stop(force: false)
      MrMurano::Progress.instance.whirly_stop(force: force)
    end

    def self.whirly_linger
      MrMurano::Progress.instance.whirly_linger
    end

    def self.whirly_msg(msg)
      MrMurano::Progress.instance.whirly_msg(msg)
    end

    def self.whirly_pause
      MrMurano::Progress.instance.whirly_pause
    end

    def self.whirly_unpause
      MrMurano::Progress.instance.whirly_unpause
    end

    def self.whirly_interject(&block)
      MrMurano::Progress.instance.whirly_interject(&block)
    end
  end
end


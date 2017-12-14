# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

require 'highline'
require 'inflecto'
require 'os'
require 'singleton'
require 'whirly'

module MrMurano
  # Progress is a singleton (evil!) that implements a terminal progress bar.
  class Progress
    include Singleton

    def initialize
      @whirly_msg = ''
      @whirly_time = nil
      @whirly_users = 0
      @whirly_cols = 0
      @whirly_pauses = 0
    end

    EXO_QUADRANTS = [
      '▚',
      '▘',
      '▝',
      '▞',
      '▖',
      '▗',
    ].freeze

    EXO_QUADRANTS_7 = [
      '-',
      '\\',
      '|',
      '/',
    ].freeze

    def whirly_start(msg)
      if $cfg['tool.verbose']
        whirly_pause if @whirly_users > 0
        say msg
        whirly_unpause if @whirly_users > 0
      end
      return if $cfg['tool.no-progress']
      # Count the number of calls to whirly_start, so that the
      # first call to whirly_start is the message that gets
      # printed. This way, methods can define a default message
      # to use, but then callers of those methods can choose to
      # display a different message.
      @whirly_users += 1
      # The first Whirly message is the one we show.
      return if @whirly_users > 1
      @whirly_msg = msg
      whirly_stop
      whirly_show
    end

    def whirly_show
      if $cfg['tool.ascii'] || OS.windows?
        spinner = EXO_QUADRANTS_7
        ansi_escape_mode = 'line'
      else
        spinner = EXO_QUADRANTS
        ansi_escape_mode = 'restore'
      end
      Whirly.start(
        spinner: spinner,
        status: @whirly_msg,
        append_newline: false,
        #remove_after_stop: false,
        #stream: $stderr,
        ansi_escape_mode: ansi_escape_mode,
      )
      @whirly_time = Time.now
      # The whitespace we add ends up getting picked up if you copy
      # from the terminal. [lb] not sure if we can fix that... but
      # we can at least minimize the amount of it to the longest
      # message, rather than the terminal column width.
      #@whirly_cols, _rows = HighLine::SystemExtensions.terminal_size
      # Note that Whirly adds '...', so add its length, too.
      # rubocop:disable Performance/FixedSize
      #   Do not compute the size of statically sized objects.
      @whirly_cols = @whirly_msg.length + '...'.length
    end

    def whirly_stop(force: false)
      return if $cfg['tool.no-progress'] || @whirly_time.nil?
      if force
        @whirly_users = 0
      else
        @whirly_users -= 1
      end
      return unless @whirly_users.zero?
      whirly_linger
      whirly_clear
    end

    def whirly_clear
      Whirly.stop
      # The progress indicator is always overwritten.
      return unless @whirly_cols
      $stdout.print((' ' * @whirly_cols) + "\r")
      $stdout.flush
    end

    def whirly_linger
      return if $cfg['tool.no-progress'] || @whirly_time.nil?
      not_so_fast = 0.55 - (Time.now - @whirly_time)
      @whirly_time = nil
      sleep(not_so_fast) if not_so_fast > 0
    end

    def whirly_msg(msg)
      return if $cfg['tool.no-progress']
      if @whirly_time.nil?
        whirly_start msg
      else
        @whirly_msg = msg
        #self.whirly_linger
        # Clear the line.
        Whirly.configure(status: ' ' * @whirly_cols)
        Whirly.configure(status: @whirly_msg)
        @whirly_cols = @whirly_msg.length + '...'.length
      end
    end

    def whirly_pause
      @whirly_pauses += 1
      return if @whirly_pauses > 1
      return if @whirly_users.zero?
      whirly_clear
    end

    def whirly_unpause
      @whirly_pauses -= 1
      raise 'Whirly unpaused once too many' if @whirly_pauses < 0
      return unless @whirly_pauses == 0
      return if @whirly_users.zero?
      whirly_show
    end

    def whirly_interject
      whirly_pause
      yield
      whirly_unpause
    end
  end
end


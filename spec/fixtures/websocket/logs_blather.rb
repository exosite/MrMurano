# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# frozen_string_literal: true

# License: PROPRIETARY. See LICENSE.txt.
# Unauthorized copying of this file is strictly prohibited.
# vim:tw=0:ts=2:sw=2:et:ai

require 'json'

require 'eventmachine'

require_relative 'simple_connection'
require_relative 'logs_faker'

class LogsBlatherConnection < SimpleWebSocket::SimpleConnection
  include LogsFakerModule
  def conn_on_open(event)
    super(event)
    _timer = EventMachine::PeriodicTimer.new(1) do
      resp = JSON.generate(random_example)
      @driver.text(resp)
      # If we needed to stop the timer:
      #   _timer.cancel
    end
  end
end


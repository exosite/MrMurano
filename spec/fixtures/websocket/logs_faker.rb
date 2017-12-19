# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# frozen_string_literal: true

# License: PROPRIETARY. See LICENSE.txt.
# Unauthorized copying of this file is strictly prohibited.
# vim:tw=0:ts=2:sw=2:et:ai

module LogsFakerModule
  def initialize
    super
    @examples = [
      example_type_script,
      example_type_call,
      example_type_event,
      example_type_config_device_v1,
      example_type_config_null,
      example_type_config_newservice,
      example_severity_build(0),
      example_severity_build(1),
      example_severity_build(2),
      example_severity_build(3),
      example_severity_build(4),
      example_severity_build(5),
      example_severity_build(6),
      example_severity_build(7),
      example_severity_build(8),
    ]
  end

  def random_example
    @examples[Random.rand(@examples.length)]
  end

  # The examples below are from the Service & Script Debug Log RFC:
  #   https://docs.google.com/document/d/1mlLSLXJj0lMDqpblzEwfAew_G8C3e5HCtAgjyyrGaKc/edit#heading=h.nrw8qx9k0clk

  def example_type_script
    {
      type: 'script',
      timestamp: 1_474_489_282_537,
      severity: 6, # info
      message: 'abc from lua',
      tracking_id: '<UUID>',
      service: 'webservice',
      event: 'request',
      data: { # Type specific
        endpoint: 'GET:/index',
        location: 'GET:/index:123',
        elapsed: 10,
      },
    }
  end

  def example_type_call
    {
      type: 'call',
      timestamp: 1_474_489_282_537,
      severity: 3, # error
      message: 'Service Call failed with error: timeout',
      tracking_id: '<UUID>',
      service: 'keystore',
      event: 'get', # The operation id
      data: { # Type specific
        request: '{..}',
        response: '{..}',
        code: 504,
      },
    }
  end

  def example_type_event
    {
      type: 'event',
      timestamp: 1_474_489_282_537,
      severity: 3, # error
      message: 'Event trigger failed with: event handler not found',
      tracking_id: '<UUID>',
      service: 'timer',
      event: 'timer',
      data: { # Type specific
        request: '<incoming payload>',
        response: '<lua response payload>',
        code: 404,
      },
    }
  end

  def example_type_config_device_v1
    {
      type: 'config',
      timestamp: 1_474_489_282_537,
      severity: 4, # warning
      message: "The service 'Device' used by the solution has been deprecated. Refer to the Service documentation for more information.",
      tracking_id: '<UUID>',
      service: 'deviceV1',
      event: nil,
      data: {},
    }
  end

  def example_type_config_null
    {
      type: 'config',
      timestamp: 1_474_489_282_537,
      severity: 5, # notice
      message: 'The module ‘util’ has been updated',
      tracking_id: '<UUID>',
      service: nil, # if eventhandler here fill the service alias
      event: nil, # if eventhandler script here fill the event
      data: {
        module: 'util',
        code: 200,
      },
    }
  end

  def example_type_config_newservice
    {
      type: 'config',
      timestamp: 1_474_489_282_537,
      severity: 5, # notice
      message: 'The service ‘newservice’ has been added to the solution',
      tracking_id: '<UUID>',
      service: 'newservice',
      event: nil,
      data: {
        parameters: {},
        code: 200,
      },
    }
  end

  def example_severity_build(severity)
    {
      type: 'config',
      timestamp: 1_474_489_282_537,
      severity: severity,
      message: 'The service ‘newservice’ has been added to the solution',
      tracking_id: '<UUID>',
      service: 'websocket',
      event: '/api/v1/foo/long/event/name',
      data: {
        parameters: {},
        code: 200,
      },
    }
  end
end

class LogsFaker
  include LogsFakerModule
end


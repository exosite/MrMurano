# Copyright © 2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

require 'json'
require 'open3'
require 'socket'
require 'timeout'
require 'uri'

require 'MrMurano/Config'
require 'cmd_common'
require 'fixtures/websocket/simple_server'
require 'fixtures/websocket/logs_faker'

RSpec.describe 'murano logs', :cmd, :needs_password do
  include_context 'CI_CMD'

  before(:example) do
    @port = SimpleWebSocket::Server::DEFAULT_WS_PORT
    @port_s = @port && ":#{@port}" || ''

    # CI_CMD's before() creates a new Config and calls load().
    #   We just need to add a few things.
    $cfg.set('net.host', "127.0.0.1#{@port_s}", :project)
    $cfg.set('net.protocol', 'http', :project)
    $cfg.set('application.id', 'XYZ', :project)

    @acc = MrMurano::Account.instance
    allow(@acc).to receive(:login_info).and_return(email: 'bob', password: 'v')
  end

  # FIXME: (landonb): MUR-3081: Remove old http code for v3.1.0. Search: LOGS_USE_HTTP.
  def supports_ws?
    runner = ::Commander::Runner.instance
    logs_cmd = runner.command(:logs)
    logs_cmd.options.any? do |opt|
      opt[:args].include? '--http'
    end
  end

  def test_tail_log
    stub_request_token
    spawn_websocket_server
    spawn_logs_stream_test_simple
    run_logs_tail
    wait_websocket_server
    expect_output
  end

  def stub_request_token
    stub_request(:post, "http://127.0.0.1#{@port_s}/api:1/token/")
      .with(
        body: '{"email":"bob","password":"v"}',
        headers: {
          'Accept' => '*/*',
          'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'Content-Type' => 'application/json',
          # 'Host'=>'ABC',
          'Host' => "127.0.0.1#{@port_s}",
          'User-Agent' => 'MrMurano/3.0.7',
        }
      )
      .to_return(
        status: 200, body: { token: 'ABCDEFGHIJKLMNOP' }.to_json, headers: {}
      )
  end

  def spawn_websocket_server
    ws_svr = "#{File.dirname(__FILE__)}/fixtures/websocket/wss-echo.rb"
    @wss_in, @wss_out, @wss_err, @wss_thr = Open3.popen3(ws_svr.to_s)
    @wss_out.close
    @wss_err.close
    await_websocket_server!
  end

  def await_websocket_server!
    # Wait for the server to start, or the logs command will fail to connect.
    ready = false
    5.times do
      begin
        s = TCPSocket.new('127.0.0.1', @port)
        s.close
        ready = true
        break
      # rubocop:disable Lint/HandleExceptions: Do not suppress exceptions.
      rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
        # pass
      end
      sleep 0.2
    end
    raise 'Server never started!' unless ready
  end

  def spawn_logs_stream_test_simple
    Thread.abort_on_exception = true
    @svr_thd = Thread.new { logs_stream_test_simple }
  end

  def logs_stream_test_simple
    sleep 0.1 until EM.reactor_running?
    @blatherer = LogsFaker.new
    sleep 0.1
    @wss_in.puts JSON.generate(@blatherer.example_type_script)
    sleep 0.1
    @wss_in.puts JSON.generate(@blatherer.example_type_call)
    sleep 0.1
    @wss_in.puts JSON.generate(@blatherer.example_type_event)
    sleep 0.1
    @wss_in.puts JSON.generate(@blatherer.example_type_config_device_v1)
    sleep 0.1
    @wss_in.puts JSON.generate(@blatherer.example_type_config_null)
    sleep 0.1
    @wss_in.puts JSON.generate(@blatherer.example_type_config_newservice)
    sleep 0.1
    @wss_in.puts 'EXIT'
    @wss_in.close
  end

  def run_logs_tail
    # For coverage, we have to call the command directly.
    #
    # DEVs: Run this is you want stdout to flow to the terminal
    #       (to make developing easier):
    #
    #   runner = ::Commander::Runner.instance
    #   logs_cmd = runner.command(:logs)
    #   mrcmd = logs_cmd.run('-f')
    #
    # Normally, we instead capture stdout so we can expect() it.
    @cmd_out, @cmd_err = murano_command_run('logs', '-f')
  end

  def wait_websocket_server
    # Block 'til subprocess exits. Receives a Process::Status.
    _proc_status = @wss_thr.value
  end

  def expect_output
    expect(@cmd_err).to eq(%(WebSocket closed [1006]\n))
    expect(@cmd_out).to eq(
      %(
message: #{JSON.generate(@blatherer.example_type_script)}
message: #{JSON.generate(@blatherer.example_type_call)}
message: #{JSON.generate(@blatherer.example_type_event)}
message: #{JSON.generate(@blatherer.example_type_config_device_v1)}
message: #{JSON.generate(@blatherer.example_type_config_null)}
message: #{JSON.generate(@blatherer.example_type_config_newservice)}
      ).strip + "\n"
    )
  end

  context 'when project is setup' do
    it 'tail log' do
      test_tail_log if supports_ws?
    end
  end
end


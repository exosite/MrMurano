# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

require 'tempfile'
require 'yaml'
require 'MrMurano/version'
require 'MrMurano/ProjectFile'
require 'MrMurano/Solution'
require 'MrMurano/SyncRoot'
require '_workspace'

RSpec.describe MrMurano::Solution do
  include_context 'WORKSPACE'
  before(:example) do
    MrMurano::SyncRoot.instance.reset
    $cfg = MrMurano::Config.new
    $cfg.load
    $project = MrMurano::ProjectFile.new
    $project.load
    $cfg['net.host'] = 'bizapi.hosted.exosite.io'
    $cfg['product.id'] = 'XYZ'
    $cfg['application.id'] = 'XYZ'

    # NOTE: This test works on either Product or Application.
    # MAYBE: Add Application to this test.
    @srv = MrMurano::Product.new
    #@srv = MrMurano::Application.new

    allow(@srv).to receive(:token).and_return('TTTTTTTTTT')
  end

  it 'initializes' do
    uri = @srv.endpoint('/')
    expect(uri.to_s).to eq(
      'https://bizapi.hosted.exosite.io/api:1/solution/XYZ/'
    )
  end

  it 'gets info' do
    body = {
      id: 'XYZ',
      label: nil,
      domain: 'ugdemo.apps.exosite.io',
      biz_id: 'ABCDEFG',
      cors: '{"origin":true,"methods":["HEAD","GET","POST","PUT","DELETE","OPTIONS","PATCH"],"headers":["Content-Type","Cookie","Authorization"],"credentials":true}',
    }

    stub_request(
      :get, 'https://bizapi.hosted.exosite.io/api:1/solution/XYZ'
    ).with(
      headers: {
        'Authorization' => 'token TTTTTTTTTT',
        'Content-Type' => 'application/json',
      }
    ).to_return(body: body.to_json)

    ret = @srv.info
    expect(ret).to eq(body)
  end

  it 'lists' do
    body = {
      id: 'XYZ',
      label: nil,
      domain: 'ugdemo.apps.exosite.io',
      biz_id: 'ABCDEFG',
      cors: '{"origin":true,"methods":["HEAD","GET","POST","PUT","DELETE","OPTIONS","PATCH"],"headers":["Content-Type","Cookie","Authorization"],"credentials":true}',
    }

    stub_request(
      :get, 'https://bizapi.hosted.exosite.io/api:1/solution/XYZ/'
    ).with(
      headers: {
        'Authorization' => 'token TTTTTTTTTT',
        'Content-Type' => 'application/json',
      }
    ).to_return(body: body.to_json)

    ret = @srv.list
    expect(ret).to eq(body)
  end

  it 'Gets version' do
    body = { min_cli_version: '0.10' }
    stub_request(
      :get, 'https://bizapi.hosted.exosite.io/api:1/solution/XYZ/version'
    ).with(
      headers: {
        'Authorization' => 'token TTTTTTTTTT',
        'Content-Type' => 'application/json',
      }
    ).to_return(body: body.to_json)

    ret = @srv.version
    expect(ret).to eq(body)
  end

  it 'Gets logs' do
    body = {
      p: [
        {
          type: 'error',
          timestamp: 1_481_746_755,
          subject: 'service call failed',
          data: {
            service_alias: 'user', function_call: 'assignUser',
          },
        },
      ],
      total: 1,
    }
    stub_request(
      :get, 'https://bizapi.hosted.exosite.io/api:1/solution/XYZ/logs'
    ).with(
      headers: {
        'Authorization' => 'token TTTTTTTTTT',
        'Content-Type' => 'application/json',
      }
    ).to_return(body: body.to_json)

    ret = @srv.log
    expect(ret).to eq(body)
  end
end


# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

require 'tempfile'
require 'MrMurano/version'
require 'MrMurano/ProjectFile'
require 'MrMurano/Solution-ServiceConfig'
require 'MrMurano/SyncRoot'
require '_workspace'

RSpec.describe MrMurano::ServiceConfig do
  include_context 'WORKSPACE'
  before(:example) do
    MrMurano::SyncRoot.instance.reset
    $cfg = MrMurano::Config.new
    $cfg.load
    $project = MrMurano::ProjectFile.new
    $project.load
    $cfg['net.host'] = 'bizapi.hosted.exosite.io'
    # serviceconfig works on all solution types.
    $cfg['product.id'] = 'XYZ'
    $cfg['application.id'] = 'XYZ'

    # ServiceConfig needs an api_id, else one could instantiate
    # ServiceConfigApplication or ServiceConfigProduct.
    @srv = MrMurano::ServiceConfig.new('XYZ')
    allow(@srv).to receive(:token).and_return('TTTTTTTTTT')
  end

  it 'initializes' do
    uri = @srv.endpoint('/')
    expect(uri.to_s).to eq('https://bizapi.hosted.exosite.io/api:1/solution/XYZ/serviceconfig/')
  end

  it 'lists' do
    body = {
      items: [
        {
          id: '9K0',
          name: 'debug',
          alias: 'XYZ_debug',
          solution_id: 'XYZ',
          service: 'device',
          status: 'ready',
          created_at: '2016-07-07T19:16:19.479Z',
          updated_at: '2016-09-12T13:26:55.868Z',
          deleted_at: nil,
        },
      ],
      total: 1,
    }
    stub_request(
      :get, 'https://bizapi.hosted.exosite.io/api:1/solution/XYZ/serviceconfig'
    ).with(
      headers: { 'Authorization' => 'token TTTTTTTTTT',
                 'Content-Type' => 'application/json', }
    ).to_return(body: body.to_json)

    ret = @srv.list
    expect(ret).to eq(body[:items])
  end

  it 'fetches' do
    body = {
      id: '9K0',
      name: 'debug',
      alias: 'XYZ_debug',
      solution_id: 'XYZ',
      service: 'device',
      status: 'ready',
      created_at: '2016-07-07T19:16:19.479Z',
      updated_at: '2016-09-12T13:26:55.868Z',
    }
    stub_request(
      :get, 'https://bizapi.hosted.exosite.io/api:1/solution/XYZ/serviceconfig/9K0'
    ).with(headers: { 'Authorization' => 'token TTTTTTTTTT',
                      'Content-Type' => 'application/json', }).to_return(body: body.to_json)

    ret = @srv.fetch('9K0')
    expect(ret).to eq(body)
  end

  it 'creates' do
    body = {
      id: '9K0',
      name: 'debug',
      alias: 'XYZ_debug',
      solution_id: 'XYZ',
      service: 'device',
      status: 'ready',
      created_at: '2016-07-07T19:16:19.479Z',
      updated_at: '2016-09-12T13:26:55.868Z',
    }
    # VERIFY/2017-07-03: Does this POST now need a trailing path delimiter?
    #stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/solution/XYZ/serviceconfig").
    stub_request(
      :post, 'https://bizapi.hosted.exosite.io/api:1/solution/XYZ/serviceconfig/'
    ).with(headers: { 'Authorization' => 'token TTTTTTTTTT',
                      'Content-Type' => 'application/json', }).to_return(body: body.to_json)

    ret = @srv.create('p4q0m2ruyoxierh')
    expect(ret).to eq(body)
  end

  it 'removes' do
    body = {}
    stub_request(
      :delete, 'https://bizapi.hosted.exosite.io/api:1/solution/XYZ/serviceconfig/9K0'
    ).with(headers: { 'Authorization' => 'token TTTTTTTTTT',
                      'Content-Type' => 'application/json', }).to_return(body: body.to_json)

    ret = @srv.remove('9K0')
    expect(ret).to eq(body)
  end

  it 'gets id from service' do
    body = {
      items: [
        {
          id: '9K0',
          name: 'debug',
          alias: 'XYZ_debug',
          solution_id: 'XYZ',
          service: 'device',
          status: 'ready',
          created_at: '2016-07-07T19:16:19.479Z',
          updated_at: '2016-09-12T13:26:55.868Z',
          deleted_at: nil,
        },
      ],
      total: 1,
    }
    stub_request(
      :get, 'https://bizapi.hosted.exosite.io/api:1/solution/XYZ/serviceconfig'
    ).with(headers: { 'Authorization' => 'token TTTTTTTTTT',
                      'Content-Type' => 'application/json', }).to_return(body: body.to_json)

    ret = @srv.scid_for_name('device')
    expect(ret).to eq('9K0')
  end

  it 'gets nil if not there' do
    body = {
      items: [
        {
          id: '9K0',
          name: 'debug',
          alias: 'XYZ_debug',
          solution_id: 'XYZ',
          service: 'device',
          status: 'ready',
          created_at: '2016-07-07T19:16:19.479Z',
          updated_at: '2016-09-12T13:26:55.868Z',
          deleted_at: nil,
        },
      ],
      total: 1,
    }
    stub_request(
      :get, 'https://bizapi.hosted.exosite.io/api:1/solution/XYZ/serviceconfig'
    ).with(headers: { 'Authorization' => 'token TTTTTTTTTT',
                      'Content-Type' => 'application/json', }).to_return(body: body.to_json)

    ret = @srv.scid_for_name('debug')
    expect(ret).to eq(nil)
  end

  it 'gets info' do
    body = { calls: { daily: 0, monthly: 0, total: 0 } }
    stub_request(
      :get, 'https://bizapi.hosted.exosite.io/api:1/solution/XYZ/serviceconfig/9K0/info'
    ).with(headers: { 'Authorization' => 'token TTTTTTTTTT',
                      'Content-Type' => 'application/json', }).to_return(body: body.to_json)

    ret = @srv.info('9K0')
    expect(ret).to eq(body)
  end

  context 'calls' do
    before(:example) do
      allow(@srv).to receive(:scid).and_return('9K0')
    end
    it 'a get' do
      body = { calls: { daily: 0, monthly: 0, total: 0 } }
      stub_request(
        :get, 'https://bizapi.hosted.exosite.io/api:1/solution/XYZ/serviceconfig/9K0/call/info'
      ).with(headers: { 'Authorization' => 'token TTTTTTTTTT',
                        'Content-Type' => 'application/json', }).to_return(body: body.to_json)

      ret = @srv.call(:info)
      expect(ret).to eq(body)
    end

    it 'a get with query' do
      body = { calls: { daily: 0, monthly: 0, total: 0 } }
      stub_request(
        :get, 'https://bizapi.hosted.exosite.io/api:1/solution/XYZ/serviceconfig/9K0/call/ask?q=what'
      ).with(headers: { 'Authorization' => 'token TTTTTTTTTT',
                        'Content-Type' => 'application/json', }).to_return(body: body.to_json)

      ret = @srv.call(:ask, :get, q: 'what')
      expect(ret).to eq(body)
    end

    it 'a post' do
      body = { calls: { daily: 0, monthly: 0, total: 0 } }
      stub_request(
        :post, 'https://bizapi.hosted.exosite.io/api:1/solution/XYZ/serviceconfig/9K0/call/ask'
      ).with(body: JSON.generate(q: 'what'),
             headers: { 'Authorization' => 'token TTTTTTTTTT',
                        'Content-Type' => 'application/json', }).to_return(body: body.to_json)

      ret = @srv.call(:ask, :post, q: 'what')
      expect(ret).to eq(body)
    end

    it 'a post without data' do
      body = { calls: { daily: 0, monthly: 0, total: 0 } }
      stub_request(
        :post, 'https://bizapi.hosted.exosite.io/api:1/solution/XYZ/serviceconfig/9K0/call/ask'
      ).with(body: JSON.generate({}),
             headers: { 'Authorization' => 'token TTTTTTTTTT',
                        'Content-Type' => 'application/json', }).to_return(body: body.to_json)

      ret = @srv.call(:ask, :post)
      expect(ret).to eq(body)
    end

    it 'a put' do
      body = { calls: { daily: 0, monthly: 0, total: 0 } }
      stub_request(
        :put, 'https://bizapi.hosted.exosite.io/api:1/solution/XYZ/serviceconfig/9K0/call/ask'
      ).with(body: JSON.generate(q: 'what'),
             headers: { 'Authorization' => 'token TTTTTTTTTT',
                        'Content-Type' => 'application/json', }).to_return(body: body.to_json)

      ret = @srv.call(:ask, :put, q: 'what')
      expect(ret).to eq(body)
    end

    it 'a put without data' do
      body = { calls: { daily: 0, monthly: 0, total: 0 } }
      stub_request(
        :put, 'https://bizapi.hosted.exosite.io/api:1/solution/XYZ/serviceconfig/9K0/call/ask'
      ).with(body: JSON.generate({}),
             headers: { 'Authorization' => 'token TTTTTTTTTT',
                        'Content-Type' => 'application/json', }).to_return(body: body.to_json)

      ret = @srv.call(:ask, :put)
      expect(ret).to eq(body)
    end

    it 'a delete' do
      body = { calls: { daily: 0, monthly: 0, total: 0 } }
      stub_request(
        :delete, 'https://bizapi.hosted.exosite.io/api:1/solution/XYZ/serviceconfig/9K0/call/gone'
      ).with(headers: { 'Authorization' => 'token TTTTTTTTTT',
                        'Content-Type' => 'application/json', }).to_return(body: body.to_json)

      ret = @srv.call(:gone, :delete)
      expect(ret).to eq(body)
    end
  end
end


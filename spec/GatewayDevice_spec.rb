# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

require 'fileutils'
require 'MrMurano/version'
require 'MrMurano/Gateway'
require 'MrMurano/SyncRoot'
require '_workspace'

RSpec.describe MrMurano::Gateway::Device do
  include_context 'WORKSPACE'
  before(:example) do
    MrMurano::SyncRoot.instance.reset
    $cfg = MrMurano::Config.new
    $cfg.load
    $cfg['net.host'] = 'bizapi.hosted.exosite.io'
    $cfg['product.id'] = 'XYZ'

    @gw = MrMurano::Gateway::Device.new
    allow(@gw).to receive(:token).and_return('TTTTTTTTTT')
  end

  it 'initializes' do
    uri = @gw.endpoint('/')
    expect(uri.to_s).to eq('https://bizapi.hosted.exosite.io/api:1/service/XYZ/device2/identity/')
  end

  context 'listing' do
    it 'lists' do
      body = {
        mayLoadMore: false,
        devices:
        [{ identity: '58',
           auth: { type: 'cik' },
           state: {},
           locked: false,
           reprovision: false,
           devmode: false,
           lastip: '',
           lastseen: 1_487_021_743_864_000,
           status: 'provisioned',
           online: false, },
         { identity: '56',
           auth: { type: 'cik' },
           state: {},
           locked: false,
           reprovision: false,
           devmode: false,
           lastip: '',
           lastseen: 1_487_021_650_584_000,
           status: 'provisioned',
           online: false, },],
      }
      stub_request(
        :get,
        'https://bizapi.hosted.exosite.io/api:1/service/XYZ/device2/identity/'
      ).to_return(body: body.to_json)

      ret = @gw.list
      expect(ret).to eq(body)
    end

    it 'lists with limit' do
      body = {
        mayLoadMore: false,
        devices:
        [{ identity: '58',
           auth: { type: 'cik' },
           state: {},
           locked: false,
           reprovision: false,
           devmode: false,
           lastip: '',
           lastseen: 1_487_021_743_864_000,
           status: 'provisioned',
           online: false, },],
      }
      stub_request(
        :get,
        'https://bizapi.hosted.exosite.io/api:1/service/XYZ/device2/identity/'
      ).with(query: { limit: '1' }).to_return(body: body.to_json)

      ret = @gw.list(1)
      expect(ret).to eq(body)
    end

    it 'lists with before' do
      body = {
        mayLoadMore: false,
        devices:
        [{ identity: '58',
           auth: { type: 'cik' },
           state: {},
           locked: false,
           reprovision: false,
           devmode: false,
           lastip: '',
           lastseen: 1_487_021_743_864_000,
           status: 'provisioned',
           online: false, },],
      }
      stub_request(
        :get,
        'https://bizapi.hosted.exosite.io/api:1/service/XYZ/device2/identity/'
      ).with(query: { limit: '1', before: '1487021743864000' }).to_return(body: body.to_json)

      ret = @gw.list(1, 1_487_021_743_864_000)
      expect(ret).to eq(body)
    end
  end

  it 'fetches one' do
    body = {
      identity: '58',
      auth: { type: 'cik' },
      state: {},
      locked: false,
      reprovision: false,
      devmode: false,
      lastip: '',
      lastseen: 1_487_021_743_864_000,
      status: 'provisioned',
      online: false,
    }
    stub_request(
      :get,
      'https://bizapi.hosted.exosite.io/api:1/service/XYZ/device2/identity/58'
    ).to_return(body: body.to_json)

    ret = @gw.fetch(58)
    expect(ret).to eq(body)
  end

  it 'enables one' do
    body = {
      identity: '58',
      auth: { type: 'cik' },
      state: {},
      locked: false,
      reprovision: false,
      devmode: false,
      lastip: '',
      lastseen: 1_487_021_743_864_000,
      status: 'provisioned',
      online: false,
    }
    stub_request(
      :put,
      'https://bizapi.hosted.exosite.io/api:1/service/XYZ/device2/identity/58'
    ).to_return(body: body.to_json)

    ret = @gw.enable(58)
    expect(ret).to eq(body)
  end

  it 'enables with options' do
    body = {
      identity: '58',
      auth: { type: 'cik' },
      state: {},
      locked: false,
      reprovision: false,
      devmode: false,
      lastip: '',
      lastseen: 1_487_021_743_864_000,
      status: 'provisioned',
      online: false,
    }
    stub_request(
      :put,
      'https://bizapi.hosted.exosite.io/api:1/service/XYZ/device2/identity/58'
    ). with(body: { auth: { expire: 123_456, type: :certificate }, locked: false }.to_json).to_return(body: body.to_json)

    ret = @gw.enable(58, type: :certificate, expire: '123456')
    expect(ret).to eq(body)
  end

  it 'enables with extra options' do
    body = {
      identity: '58',
      auth: { type: 'cik' },
      state: {},
      locked: false,
      reprovision: false,
      devmode: false,
      lastip: '',
      lastseen: 1_487_021_743_864_000,
      status: 'provisioned',
      online: false,
    }
    stub_request(
      :put,
      'https://bizapi.hosted.exosite.io/api:1/service/XYZ/device2/identity/58'
    ).with(body: { auth: { expire: 123_456, type: :certificate }, locked: false }.to_json).to_return(body: body.to_json)

    ret = @gw.enable(58, go: :blueteam, type: :certificate, expire: 123_456, bob: :built)
    expect(ret).to eq(body)
  end

  it 'removes one' do
    body = {
      identity: '58',
      auth: { type: 'cik' },
      state: {},
      locked: false,
      reprovision: false,
      devmode: false,
      lastip: '',
      lastseen: 1_487_021_743_864_000,
      status: 'provisioned',
      online: false,
    }
    stub_request(
      :delete,
      'https://bizapi.hosted.exosite.io/api:1/service/XYZ/device2/identity/58'
    ).to_return(body: body.to_json)

    ret = @gw.remove(58)
    expect(ret).to eq(body)
  end

  context 'activates' do
    before(:example) do
      @bgw = MrMurano::Gateway::GweBase.new
      allow(@bgw).to receive(:token).and_return('TTTTTTTTTT')
      expect(MrMurano::Gateway::GweBase).to receive(:new).and_return(@bgw)
      allow(@gw).to receive(:token).and_return('TTTTTTTTTT')
      stub_request(
        :get,
        'https://bizapi.hosted.exosite.io/api:1/service/XYZ/device2'
      ).to_return(body: { fqdn: 'xxxxx.m2.exosite-staging.io' }.to_json)
    end
    it 'succeeds' do
      stub_request(
        :post,
        'https://xxxxx.m2.exosite-staging.io/provision/activate'
      ).to_return(body: 'XXXXXXXX')

      ret = @gw.activate(58)
      expect(ret).to eq('XXXXXXXX')
    end

    it 'was already activated' do
      stub_request(
        :post,
        'https://xxxxx.m2.exosite-staging.io/provision/activate'
      ).to_return(status: 409)

      saved = $stderr
      $stderr = StringIO.new

      #@gw.activate(58)
      #expect($stderr.string).to eq("\e[31mRequest Failed: 409: nil\e[0m\n")
      expect do
        @gw.activate(58)
      end.to raise_error(SystemExit).and output("\e[31mThe specified device is already activated.\e[0m\n").to_stderr
      $stderr = saved
    end

    it "wasn't enabled" do
      stub_request(
        :post,
        'https://xxxxx.m2.exosite-staging.io/provision/activate'
      ).to_return(status: 404)

      saved = $stderr
      $stderr = StringIO.new

      @gw.activate(58)
      expect($stderr.string).to eq("\e[31mRequest Failed: 404: nil\e[0m\n")
      $stderr = saved
    end
  end

  context 'enables batch' do
    it 'enables from cvs' do
      File.open('ids.csv', 'w') { |io| io << "ID\n1\n2\n3\n4\n5" }
      stub_request(
        :post,
        'https://bizapi.hosted.exosite.io/api:1/service/XYZ/device2/identities'
      ).with(headers: { 'Content-Type' => %r{^multipart/form-data.*} }) do |request|
        request.body.to_s =~ %r{Content-Type: text/csv\r\n\r\nID\r?\n1\r?\n2\r?\n3\r?\n4\r?\n5}
      end
      @gw.enable_batch('ids.csv')
    end

    it 'but file is missing' do
      expect { @gw.enable_batch('ids.csv') }.to raise_error(Errno::ENOENT)
    end

    it 'but file is not text' do
      File.open('ids.csv', 'wb') { |io| io << "\0\0\0\0" }
      stub_request(
        :post,
        'https://bizapi.hosted.exosite.io/api:1/service/XYZ/device2/identities'
      ).to_return(status: 400, body: 'CSV file format invalid')
      saved = $stderr
      $stderr = StringIO.new
      @gw.enable_batch('ids.csv')
      expect($stderr.string).to eq(%(\e[31mRequest Failed: 400: CSV file format invalid\e[0m\n))
      $stderr = saved
    end

    it 'but file is missing header' do
      File.open('ids.csv', 'w') { |io| io << "1\n2\n3\n4\n5" }
      stub_request(
        :post,
        'https://bizapi.hosted.exosite.io/api:1/service/XYZ/device2/identities'
      ).with(headers: { 'Content-Type' => %r{^multipart/form-data.*} }) do |request|
        request.body.to_s =~ %r{Content-Type: text/csv\r\n\r\n1\r?\n2\r?\n3\r?\n4\r?\n5}
      end.to_return(status: 400, body: 'CSV file format invalid')
      saved = $stderr
      $stderr = StringIO.new
      @gw.enable_batch('ids.csv')
      expect($stderr.string).to eq(%(\e[31mRequest Failed: 400: CSV file format invalid\e[0m\n))
      $stderr = saved
    end
  end

  it 'reads state' do
    body = { bob: { reported: '9', set: '9', timestamp: 1_487_021_046_160_363 } }
    stub_request(
      :get,
      'https://bizapi.hosted.exosite.io/api:1/service/XYZ/device2/identity/56/state'
    ).to_return(body: body.to_json)

    ret = @gw.read(56)
    expect(ret).to eq(body)
  end

  context 'writes state' do
    it 'succeeds' do
      body = { bob: 'fuzz' }
      stub_request(
        :patch,
        'https://bizapi.hosted.exosite.io/api:1/service/XYZ/device2/identity/56/state'
      ).with(body: body.to_json)

      @gw.write(56, bob: 'fuzz')
    end

    it 'fails' do
      body = { bob: 'fuzz' }
      stub_request(
        :patch,
        'https://bizapi.hosted.exosite.io/api:1/service/XYZ/device2/identity/56/state'
      ).with(body: body.to_json).to_return(status: 400, body: 'Value is not settable')

      saved = $stderr
      $stderr = StringIO.new

      @gw.write(56, bob: 'fuzz')
      expect($stderr.string).to eq("\e[31mRequest Failed: 400: Value is not settable\e[0m\n")
      $stderr = saved
    end
  end
end


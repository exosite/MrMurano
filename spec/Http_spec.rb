# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

require 'MrMurano/version'
require 'MrMurano/http'
require 'MrMurano/verbosing'
require 'MrMurano/Account'
require '_workspace'

class Tst
  include MrMurano::Verbose
  include MrMurano::Http

  def initialize
    @token = nil
  end
end

RSpec.describe MrMurano::Http do
  include_context 'WORKSPACE'

  before(:example) do
    $cfg = MrMurano::Config.new
    $cfg.load
    @tst = Tst.new
  end

  context 'gets a token' do
    before(:example) do
      @acc = instance_double('MrMurano::Account')
      #allow(MrMurano::Account).to receive(:new).and_return(@acc)
      allow(MrMurano::Account).to receive(:instance).and_return(@acc)
    end

    it 'already has one' do
      @tst.instance_variable_set(:@token, 'ABCDEFG')
      ret = @tst.token
      expect(ret).to eq('ABCDEFG')
    end

    it 'gets one' do
      #expect(@acc).to receive(:adc_compat_check)
      expect(@acc).to receive(:token).and_return('ABCDEFG')
      ret = @tst.token
      expect(ret).to eq('ABCDEFG')
    end

    it 'raises when not logged in' do
      expect(@acc).to receive(:token).and_return(nil)
      # 2017-07-13: The token command used to raise an error, but [lb]
      # doesn't like seeing the "use --trace" message that Ruby spits
      # out. So write to stderr and exit instead. Here, use check that
      # the function exits by expecting it to raise SystemExit.
      expect do
        @tst.token
      end.to raise_error(SystemExit).and output("\e[31mNot logged in!\e[0m\n").to_stderr
    end
  end

  context 'puts curl request' do
    before(:example) do
      @req = Net::HTTP::Get.new URI('https://test.host/this/is/a/test')
      @req.content_type = 'application/json'
      @req['User-Agent'] = 'test'
    end
    it 'puts nothing' do
      $cfg['tool.curldebug'] = false
      $stdout = StringIO.new
      @tst.curldebug(@req)
      expect($stdout.string).to eq('')
    end

    it 'puts something' do
      $cfg['tool.curldebug'] = true
      $cfg.curlfile_f = nil
      $stdout = StringIO.new
      @tst.curldebug(@req)
      expect($stdout.string).to eq(
        %(curl -s -H 'User-Agent: test' -H 'Content-Type: application/json' -X GET 'https://test.host/this/is/a/test'\n)
      )
    end

    it 'puts something with Auth' do
      $cfg['tool.curldebug'] = true
      $cfg.curlfile_f = nil
      $stdout = StringIO.new
      @req['Authorization'] = 'LetMeIn'
      @tst.curldebug(@req)
      expect($stdout.string).to eq(
        %(curl -s -H 'Authorization: LetMeIn' -H 'User-Agent: test' -H 'Content-Type: application/json' -X GET 'https://test.host/this/is/a/test'\n)
      )
    end

    it 'puts something with Body' do
      $cfg['tool.curldebug'] = true
      $cfg.curlfile_f = nil
      $stdout = StringIO.new
      @req.body = 'builder'
      @tst.curldebug(@req)
      expect($stdout.string).to eq(
        %(curl -s -H 'User-Agent: test' -H 'Content-Type: application/json' -X GET 'https://test.host/this/is/a/test' -d 'builder'\n)
      )
    end
  end

  context 'checks if JSON' do
    it 'is JSON' do
      ok, data = @tst.isJSON(%({"one": "two", "three":[1,2,3,4,5,6]}))
      expect(ok).to be true
      expect(data).to eq(one: 'two',
                         three: [1, 2, 3, 4, 5, 6])
    end
    it 'is not JSON' do
      ok, data = @tst.isJSON(%(woeiutepoxam))
      expect(ok).to be false
      expect(data).to eq('woeiutepoxam')
    end
  end

  context 'shows HTTP errors' do
    before(:example) do
      @req = Net::HTTP::Get.new URI('https://test.host/this/is/a/test')
      @req.content_type = 'application/json'
      @req['User-Agent'] = 'test'
      @rsp = Net::HTTPGone.new('1.1', 410, 'ok')
    end

    it 'shows debug details' do
      $cfg['tool.debug'] = true
      $stdout = StringIO.new
      $stderr = StringIO.new

      allow(@rsp).to receive(:body).and_return('ok')
      expect(@tst).to receive(:error).once.with('Request Failed: 410: ok')

      @tst.showHttpError(@req, @rsp)
      expect($stdout.string).to eq(%(Sent GET https://test.host/this/is/a/test
         > Accept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3
         > Accept: */*
         > User-Agent: test
         > Host: test.host
         > Content-Type: application/json
         Got 410 ok
      ).gsub(/^\s+/, ''))
      expect($stderr.string).to eq('')
    end

    it 'shows debug details; has req body' do
      $cfg['tool.debug'] = true
      $stdout = StringIO.new
      $stderr = StringIO.new

      allow(@req).to receive(:body).and_return('this is my body')
      allow(@rsp).to receive(:body).and_return('ok')
      expect(@tst).to receive(:error).once.with('Request Failed: 410: ok')

      @tst.showHttpError(@req, @rsp)
      expect($stdout.string).to eq(%(Sent GET https://test.host/this/is/a/test
         > Accept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3
         > Accept: */*
         > User-Agent: test
         > Host: test.host
         > Content-Type: application/json
         >> this is my body
         Got 410 ok
      ).gsub(/^\s+/, ''))
      expect($stderr.string).to eq('')
    end

    it 'shows debug details; json body' do
      $cfg['tool.debug'] = true
      $stdout = StringIO.new
      $stderr = StringIO.new

      allow(@rsp).to receive(:body).and_return(%({"statusCode": 123, "message": "ok"}))
      expect(@tst).to receive(:error).once.with('Request Failed: 410: [123] ok')

      @tst.showHttpError(@req, @rsp)
      expect($stdout.string).to eq(%(Sent GET https://test.host/this/is/a/test
         > Accept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3
         > Accept: */*
         > User-Agent: test
         > Host: test.host
         > Content-Type: application/json
         Got 410 ok
      ).gsub(/^\s+/, ''))
      expect($stderr.string).to eq('')
    end

    it 'shows full error responses' do
      $cfg['tool.fullerror'] = true
      $stdout = StringIO.new
      $stderr = StringIO.new

      allow(@rsp).to receive(:body).and_return(%({"statusCode": 123, "message": "ok"}))
      expect(@tst).to receive(:error).once.with(
        "Request Failed: 410: {\n  \"statusCode\": 123,\n  \"message\": \"ok\"\n}"
      )

      @tst.showHttpError(@req, @rsp)
      expect($stdout.string).to eq('')
      expect($stderr.string).to eq('')
    end

    it 'calls showHttpError' do
      $stdout = StringIO.new
      $stderr = StringIO.new

      idhttp = instance_double('Net::HTTP')
      expect(idhttp).to receive(:request).once.and_return(@rsp)
      expect(@tst).to receive(:http).once.and_return(idhttp)
      expect(@rsp).to receive(:body).and_return(%({"statusCode": 123, "message": "gone"}))

      @tst.workit(@req)
      expect($stdout.string).to eq('')
      expect($stderr.string).to eq("\e[31mRequest Failed: 410: [123] gone\e[0m\n")
    end
  end
end


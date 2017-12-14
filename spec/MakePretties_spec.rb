# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

require 'MrMurano/version'
require 'MrMurano/makePretty'

RSpec.describe MrMurano::Pretties do
  before(:example) do
    @options = { pretty: true, localtime: false }
    # [lb] not sure how to fix this warning...
    # rubocop:disable Style/MethodMissing
    #   "When using method_missing, define respond_to_missing?"
    def @options.method_missing(mid)
      self[mid]
    end
  end

  it 'makes json pretty with color' do
    data = { type: 'debug', timestamp: 1_476_386_031,
             subject: 'websocket_websocket_info',
             data: 'Script Error: ', }
    str = "\e[35m{\e[0m\n  \"type\": \"debug\",\n  \"timestamp\": 1476386031,\n  \"subject\": \"websocket_websocket_info\",\n  \"data\": \"Script Error: \"\n\e[35m}\e[0m"
    ret = MrMurano::Pretties.makeJsonPretty(data, @options)
    expect(ret).to eq(str)
  end
  it 'makes json pretty without color' do
    data = { type: 'debug', timestamp: 1_476_386_031,
             subject: 'websocket_websocket_info',
             data: 'Script Error: ', }
    str = '{"type":"debug","timestamp":1476386031,"subject":"websocket_websocket_info","data":"Script Error: "}'
    @options[:pretty] = false
    ret = MrMurano::Pretties.makeJsonPretty(data, @options)
    expect(ret).to eq(str)
  end

  it 'makes it pretty.' do
    data = { type: 'debug', timestamp: 1_476_386_031,
             subject: 'websocket_websocket_info',
             data: 'Script Error: ', }
    str = "\e[31m\e[48;5;231mDEBUG \e[0m\e[31m\e[48;5;231m[websocket_websocket_info]\e[0m \e[34m2016-10-13T19:13:51.000+00:00\e[0m:\nScript Error: "
    ret = MrMurano::Pretties.MakePrettyLogsV1(data, @options)
    expect(ret).to eq(str)
  end

  it 'makes it pretty; missing type' do
    data = { timestamp: 1_476_386_031,
             subject: 'websocket_websocket_info',
             data: 'Script Error: ', }
    str = "\e[31m\e[48;5;231m-- \e[0m\e[31m\e[48;5;231m[websocket_websocket_info]\e[0m \e[34m2016-10-13T19:13:51.000+00:00\e[0m:\nScript Error: "
    ret = MrMurano::Pretties.MakePrettyLogsV1(data, @options)
    expect(ret).to eq(str)
  end

  it 'makes it pretty; localtime' do
    data = { type: 'debug', timestamp: 1_476_386_031,
             subject: 'websocket_websocket_info',
             data: 'Script Error: ', }
    ldt = Time.at(1_476_386_031).localtime.to_datetime.iso8601(3)
    str = "\e[31m\e[48;5;231mDEBUG \e[0m\e[31m\e[48;5;231m[websocket_websocket_info]\e[0m \e[34m#{ldt}\e[0m:\nScript Error: "
    @options[:localtime] = true
    ret = MrMurano::Pretties.MakePrettyLogsV1(data, @options)
    @options[:localtime] = false
    expect(ret).to eq(str)
  end

  it 'makes it pretty; missing timestamp' do
    data = { type: 'debug',
             subject: 'websocket_websocket_info',
             data: 'Script Error: ', }
    str = "\e[31m\e[48;5;231mDEBUG \e[0m\e[31m\e[48;5;231m[websocket_websocket_info]\e[0m \e[34m<no timestamp>\e[0m:\nScript Error: "
    ret = MrMurano::Pretties.MakePrettyLogsV1(data, @options)
    expect(ret).to eq(str)
  end

  it 'makes it pretty; missing subject' do
    data = { type: 'debug', timestamp: 1_476_386_031,
             data: 'Script Error: ', }
    str = "\e[31m\e[48;5;231mDEBUG \e[0m\e[31m\e[48;5;231m[]\e[0m \e[34m2016-10-13T19:13:51.000+00:00\e[0m:\nScript Error: "
    ret = MrMurano::Pretties.MakePrettyLogsV1(data, @options)
    expect(ret).to eq(str)
  end

  it 'makes it pretty; missing data' do
    data = { type: 'debug', timestamp: 1_476_386_031,
             subject: 'websocket_websocket_info', }
    str = "\e[31m\e[48;5;231mDEBUG \e[0m\e[31m\e[48;5;231m[websocket_websocket_info]\e[0m \e[34m2016-10-13T19:13:51.000+00:00\e[0m:\n\e[35m{\e[0m\n\e[35m}\e[0m"
    ret = MrMurano::Pretties.MakePrettyLogsV1(data, @options)
    expect(ret).to eq(str)
  end

  it 'makes it pretty; NAN timestamp' do
    data = { type: 'debug', timestamp: 'bob',
             subject: 'websocket_websocket_info',
             data: 'Script Error: ', }
    str = "\e[31m\e[48;5;231mDEBUG \e[0m\e[31m\e[48;5;231m[websocket_websocket_info]\e[0m \e[34mbob\e[0m:\nScript Error: "
    ret = MrMurano::Pretties.MakePrettyLogsV1(data, @options)
    expect(ret).to eq(str)
  end

  it 'makes it pretty; hash data' do
    data = { type: 'debug', timestamp: 1_476_386_031,
             subject: 'websocket_websocket_info',
             data: {
               random: 'junk',
             }, }
    str = "\e[31m\e[48;5;231mDEBUG \e[0m\e[31m\e[48;5;231m[websocket_websocket_info]\e[0m \e[34m2016-10-13T19:13:51.000+00:00\e[0m:\n\e[35m{\e[0m\n  \"random\": \"junk\"\n\e[35m}\e[0m"
    ret = MrMurano::Pretties.MakePrettyLogsV1(data, @options)
    expect(ret).to eq(str)
  end

  it 'makes it pretty; http hash data' do
    data = { type: 'debug', timestamp: 1_476_386_031,
             subject: 'websocket_websocket_info',
             data: {
               request: { method: 'get' },
               response: { status: 200 },
             }, }
    str = %(\e[31m\e[48;5;231mDEBUG \e[0m\e[31m\e[48;5;231m[websocket_websocket_info]\e[0m \e[34m2016-10-13T19:13:51.000+00:00\e[0m:\n---------\nrequest:\e[35m{\e[0m\n  "method\": \"get\"\n\e[35m}\e[0m\n---------\nresponse:\e[35m{\e[0m\n  \"status\": 200\n\e[35m}\e[0m)
    ret = MrMurano::Pretties.MakePrettyLogsV1(data, @options)
    expect(ret).to eq(str)
  end
end


# Last Modified: 2017.07.31 /coding: utf-8

# Copyright © 2016-2017 Exosite LLC.
# License: MIT. See LICENSE.txt.
#  vim:tw=0:ts=2:sw=2:et:ai

require 'highline/import'
require 'MrMurano/version'
require 'MrMurano/Account'
require 'MrMurano/Config'
require 'MrMurano/ProjectFile'
require '_workspace'

RSpec.describe MrMurano::Account, "token" do
  include_context "WORKSPACE"
  before(:example) do
    @saved_cfg = ENV['MURANO_CONFIGFILE']
    ENV['MURANO_CONFIGFILE'] = nil
    $cfg = MrMurano::Config.new
    $cfg.load
    $cfg['net.host'] = 'bizapi.hosted.exosite.io'
    $cfg['business.id'] = 'XYZxyz'
    $cfg['product.id'] = 'XYZ'

    $project = MrMurano::ProjectFile.new
    $project.load

    @acc = MrMurano::Account.instance
  end

  after(:example) do
    @acc.token_reset
    ENV['MURANO_CONFIGFILE'] = @saved_cfg
  end

  context "Get login info" do
    before(:example) do
      @pswd = instance_double("MrMurano::Passwords")
      allow(@pswd).to receive(:load).and_return(nil)
      allow(@pswd).to receive(:save).and_return(nil)
      allow(MrMurano::Passwords).to receive(:new).and_return(@pswd)
    end

    it "Asks for nothing" do
      $cfg['user.name'] = "bob"
      expect(@pswd).to receive(:get).once.and_return("built")

      ret = @acc.login_info
      expect(ret).to eq({
        :email => "bob", :password=>"built"
      })
    end

    it "Asks for user name" do
      $cfg['user.name'] = nil
      expect($terminal).to receive(:ask).once.and_return('bob')
      expect(@acc).to receive(:error).once
      expect($cfg).to receive(:set).with('user.name', 'bob', :user).once.and_call_original
      expect(@pswd).to receive(:get).once.and_return("built")

      ret = @acc.login_info
      expect(ret).to eq({
        :email => "bob", :password=>"built"
      })
    end

    it "Asks for password" do
      $cfg['user.name'] = "bob"
      expect(@pswd).to receive(:get).with('bizapi.hosted.exosite.io', 'bob').once.and_return(nil)
      expect(@acc).to receive(:error).once
      expect($terminal).to receive(:ask).once.and_return('dog')
      expect(@pswd).to receive(:set).once.with('bizapi.hosted.exosite.io','bob','dog')
      # 2017-07-31: login_info may exit unless the command okays prompting for the password.
      #   (If we don't set this, login_info exits, which we'd want to
      #   catch with
      #     expect {@acc.login_info }.to raise_error(SystemExit).and output('...')
      expect($cfg).to receive(:prompt_if_logged_off).and_return(true)

      ret = @acc.login_info
      expect(ret).to eq(email: "bob", password: "dog")
    end
  end

  context "token" do
    before(:example) do
      allow(@acc).to receive(:login_info).and_return({:email=>'bob',:password=>'v'})
    end

    it "gets a token" do
      stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/token/").
        with(:body => {:email=>'bob', :password=>'v'}.to_json).
        to_return(body: {:token=>"ABCDEFGHIJKLMNOP"}.to_json)

      ret = @acc.token
      expect(ret).to eq("ABCDEFGHIJKLMNOP")
    end

    it "gets an error" do
      stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/token/").
        with(:body => {:email=>'bob', :password=>'v'}.to_json).
        to_return(status: 401, body: {}.to_json)

      expect(@acc).to receive(:error).twice.and_return(nil)
      ret = @acc.token
      expect(ret).to be_nil
      # MAYBE/2017-07-13: Change Account.token method to put error and exit,
      # just like Http.token method. ([lb] concerned that MurCLI might keep
      # running without a valid token and then fail unexpectedly later.)
      #expect {
      #  @acc.token
      #}.to raise_error(SystemExit).and output("\e[31mNot logged in!\e[0m\n").to_stderr
    end

    it "uses existing token" do
      @acc.token_reset("quxx")
      ret = @acc.token
      expect(ret).to eq("quxx")
    end

    it "uses existing token, even with new instance" do
      @acc.token_reset("quxx")
      acc = MrMurano::Account.instance
      ret = acc.token
      expect(ret).to eq("quxx")
    end
  end
end

RSpec.describe MrMurano::Account do
  include_context "WORKSPACE"
  before(:example) do
    @saved_cfg = ENV['MURANO_CONFIGFILE']
    ENV['MURANO_CONFIGFILE'] = nil
    $cfg = MrMurano::Config.new
    $cfg.load
    $cfg['net.host'] = 'bizapi.hosted.exosite.io'
    $cfg['business.id'] = 'XYZxyz'
    $cfg['product.id'] = 'XYZ'

    @acc = MrMurano::Account.instance
    allow(@acc).to receive(:token).and_return("TTTTTTTTTT")
  end
  after(:example) do
    ENV['MURANO_CONFIGFILE'] = @saved_cfg
  end

  it "initializes" do
    uri = @acc.endpoint('')
    expect(uri.to_s).to eq("https://bizapi.hosted.exosite.io/api:1/")
  end

  context "lists business" do
    it "for user.name" do
      # http.rb::json_opts() sets :symbolize_names=>true, so use symbols, not strings.
      bizlist = [
        {:bizid=>"XXX",
         :role=>"admin",
         :name=>"MPS",
        },
        {:bizid=>"YYY",
         :role=>"admin",
         :name=>"MAE",
        },
      ]
      stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/user/BoB@place.net/membership/").
        to_return(body: bizlist)

      buslist = []
      buslist << MrMurano::Business.new(bizlist[0])
      buslist << MrMurano::Business.new(bizlist[1])

      $cfg['user.name'] = 'BoB@place.net'
      ret = @acc.businesses
      expect(ret).to eq(buslist)
    end

    it "asks for account when missing" do
      bizlist = [
        {:bizid=>"XXX",
         :role=>"admin",
         :name=>"MPS"},
        {:bizid=>"YYY",
         :role=>"admin",
         :name=>"MAE"},
      ]
      stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/user/BoB@place.net/membership/").
        to_return(body: bizlist)

      buslist = []
      buslist << MrMurano::Business.new(bizlist[0])
      buslist << MrMurano::Business.new(bizlist[1])

      $cfg['user.name'] = nil
      expect(@acc).to receive(:login_info) do |arg|
        $cfg['user.name'] = 'BoB@place.net'
      end

      ret = @acc.businesses
      expect(ret).to eq(buslist)
    end
  end
end


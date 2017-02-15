require 'fileutils'
require 'MrMurano/version'
require 'MrMurano/Gateway'
require '_workspace'

RSpec.describe MrMurano::Gateway::Base do
  include_context "WORKSPACE"
  before(:example) do
    MrMurano::SyncRoot.reset
    $cfg = MrMurano::Config.new
    $cfg.load
    $cfg['net.host'] = 'bizapi.hosted.exosite.io'
    $cfg['project.id'] = 'XYZ'

    @gw = MrMurano::Gateway::Base.new
    allow(@gw).to receive(:token).and_return("TTTTTTTTTT")
  end

  it "initializes" do
    uri = @gw.endPoint('/')
    expect(uri.to_s).to eq("https://bizapi.hosted.exosite.io/api:1/service/XYZ/gateway/")
  end

  it "gets info" do
     stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/service/XYZ/gateway").
       with(:headers => {'Authorization'=>'token TTTTTTTTTT', 'Content-Type'=>'application/json'}).
       to_return(:status => 200, :body => "", :headers => {})

    ret = @gw.info
    expect(ret).to eq({})
  end

end

#  vim: set ai et sw=2 ts=2 :
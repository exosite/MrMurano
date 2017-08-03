require 'fileutils'
require 'MrMurano/version'
require 'MrMurano/Gateway'
require 'MrMurano/SyncRoot'
require '_workspace'

RSpec.describe MrMurano::Gateway::Settings do
  include_context "WORKSPACE"
  before(:example) do
    MrMurano::SyncRoot.instance.reset
    $cfg = MrMurano::Config.new
    $cfg.load
    $cfg['net.host'] = 'bizapi.hosted.exosite.io'
    $cfg['product.id'] = 'XYZ'

    @gw = MrMurano::Gateway::Settings.new
    allow(@gw).to receive(:token).and_return("TTTTTTTTTT")

    @infoblob = {
      :name=>"XXXXXXXX",
      :protocol=>{:name=>"onep", :devmode=>false},
      :description=>"XXXXXXXX",
      :identity_format=> {
        :prefix=>"", :type=>"opaque", :options=>{:casing=>"mixed", :length=>0}},
      :fqdn=>"XXXXXXXX.m2.exosite-staging.io",
      :provisioning=> {
        :auth_type => 'token',
        :enabled=>true,
        :generate_identity=>true,
        :presenter_identity=>true,
        :ip_whitelisting=>{:enabled=>false, :allowed=>[]}},
      :resources=> {
          :bob=>{:format=>"string", :unit=>"c", :settable=>true},
          :fuzz=>{:format=>"string", :unit=>"c", :settable=>true},
          :gruble=>{:format=>"string", :unit=>"bits", :settable=>true}
        }
    }
  end

  it "initializes" do
    uri = @gw.endpoint('/')
    expect(uri.to_s).to eq("https://bizapi.hosted.exosite.io/api:1/service/XYZ/device2/")
  end

  context "protocol" do
    context "reads" do
      it "data" do
        stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/service/XYZ/device2").
          with(:headers => {'Authorization'=>'token TTTTTTTTTT', 'Content-Type'=>'application/json'}).
          to_return(:status => 200, :body => @infoblob.to_json, :headers => {})

        ret = @gw.protocol
        expect(ret).to eq(@infoblob[:protocol])
      end

      it "returns empty if not Hash" do
        stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/service/XYZ/device2").
          with(:headers => {'Authorization'=>'token TTTTTTTTTT', 'Content-Type'=>'application/json'}).
          to_return(:status => 200, :body => ['bob'].to_json, :headers => {})

        ret = @gw.protocol
        expect(ret).to eq({})
      end

      it "returns empty if missing protocol" do
        foo = @infoblob.dup
        foo.delete :protocol
        stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/service/XYZ/device2").
          with(:headers => {'Authorization'=>'token TTTTTTTTTT', 'Content-Type'=>'application/json'}).
          to_return(:status => 200, :body => foo.to_json, :headers => {})

        ret = @gw.protocol
        expect(ret).to eq({})
      end

      it "returns empty if protocol not Hash" do
        foo = @infoblob.dup
        foo[:protocol] = "bob"
        stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/service/XYZ/device2").
          with(:headers => {'Authorization'=>'token TTTTTTTTTT', 'Content-Type'=>'application/json'}).
          to_return(:status => 200, :body => foo.to_json, :headers => {})

        ret = @gw.protocol
        expect(ret).to eq({})
      end
    end
    context "writes" do
      it "data" do
        newvalues = {:name=>'twelve', :devmode=>true}
        stub_request(:patch, "https://bizapi.hosted.exosite.io/api:1/service/XYZ/device2").
          with(:headers => {'Authorization'=>'token TTTTTTTTTT',
                            'Content-Type'=>'application/json'},
               :body => {:protocol=>newvalues}.to_json).
          to_return(:status => 200, :headers => {})

        ret = @gw.protocol=(newvalues)
        expect(ret).to eq(newvalues)
      end

      it "raises when not Hash" do
        expect{ @gw.protocol=('foo') }.to raise_error "Not Hash"
      end

      it "strips extra keys" do
        newvalues = {:name=>'twelve', :devmode=>true, :auth=>"yes", :bob=>:built}
        stub_request(:patch, "https://bizapi.hosted.exosite.io/api:1/service/XYZ/device2").
          with(:headers => {'Authorization'=>'token TTTTTTTTTT',
                            'Content-Type'=>'application/json'},
               :body => {:protocol=>{:name=>'twelve', :devmode=>true}}.to_json).
          to_return(:status => 200, :headers => {})

        ret = @gw.protocol=(newvalues)
        expect(ret).to eq(newvalues)
      end
    end
  end

end

#  vim: set ai et sw=2 ts=2 :

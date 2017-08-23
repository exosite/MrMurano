require 'tempfile'
require 'yaml'
require 'MrMurano/version'
require 'MrMurano/ProjectFile'
require 'MrMurano/SyncRoot'
require 'MrMurano/Webservice-Cors'
require '_workspace'

RSpec.describe MrMurano::Webservice::Settings do
  include_context "WORKSPACE"
  before(:example) do
    MrMurano::SyncRoot.instance.reset
    $cfg = MrMurano::Config.new
    $cfg.load
    $cfg['net.host'] = 'bizapi.hosted.exosite.io'
    $cfg['application.id'] = 'XYZ'

    @srv = MrMurano::Webservice::Settings.new
    allow(@srv).to receive(:token).and_return("TTTTTTTTTT")

    @baseURI = "https://bizapi.hosted.exosite.io/api:1/solution/XYZ/cors"
  end

  it "initializes" do
    uri = @srv.endpoint('/')
    expect(uri.to_s).to eq("#{@baseURI}/")
  end

  context "when server gives string" do
    context "fetches" do
      it "as a hash" do
        cors = {:origin=>true,
                :methods=>["HEAD","GET","POST","PUT","DELETE","OPTIONS","PATCH"],
                :headers=>["Content-Type","Cookie","Authorization"],
                :credentials=>true}
        body = cors
        stub_request(:get, "#{@baseURI}").
          with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                          'Content-Type'=>'application/json'}).
                          to_return(body: body.to_json)

        ret = @srv.cors
        expect(ret).to eq(cors)
      end
    end
  end

  context "when server gives object" do
    context "fetches" do
      it "as a hash" do
        cors = {:origin=>true,
                :methods=>["HEAD","GET","POST","PUT","DELETE","OPTIONS","PATCH"],
                :headers=>["Content-Type","Cookie","Authorization"],
                :credentials=>true}
        body = cors
        stub_request(:get, "#{@baseURI}").
          with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                          'Content-Type'=>'application/json'}).
                          to_return(body: body.to_json)

        ret = @srv.cors
        expect(ret).to eq(cors)
      end
    end
  end

  context "uploads" do
    before(:example) do
      $project = MrMurano::ProjectFile.new
      $project.load
      @cors = {:origin=>true,
               :methods=>["HEAD","GET","POST","PUT","DELETE","OPTIONS","PATCH"],
               :headers=>["Content-Type","Cookie","Authorization"],
               :credentials=>true}
    end
    it "sets" do
      stub_request(:put, "#{@baseURI}").
        with(:body=>@cors.to_json,
             :headers=>{'Authorization'=>'token TTTTTTTTTT',
                        'Content-Type'=>'application/json'}).
                        to_return(body: "")

      ret = @srv.cors=(@cors)
      expect(ret).to eq(@cors)
    end
  end

end
#  vim: set ai et sw=2 ts=2 :

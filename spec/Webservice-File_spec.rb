require 'MrMurano/version'
require 'MrMurano/ProjectFile'
require 'MrMurano/Webservice-File'
require '_workspace'

RSpec.describe MrMurano::Webservice::File do
  include_context "WORKSPACE"
  before(:example) do
    $cfg = MrMurano::Config.new
    $cfg.load
    $project = MrMurano::ProjectFile.new
    $project.load
    $cfg['net.host'] = 'bizapi.hosted.exosite.io'
    $cfg['product.id'] = 'XYZ'
    $cfg['application.id'] = 'XYZ'

    @srv = MrMurano::Webservice::File.new
    allow(@srv).to receive(:token).and_return("TTTTTTTTTT")

    @baseURI = "https://bizapi.hosted.exosite.io/api:1/solution/XYZ/file"
    @fileuploadURI = "https://bizapi.hosted.exosite.io/api:1/solution/XYZ/fileupload"
  end

  it "initializes" do
    uri = @srv.endpoint('/')
    expect(uri.to_s).to eq("#{@baseURI}/")
  end

  it "lists" do
    body = [
      {:path=>"/",
       :mime_type=>"text/html",
       :checksum=>"f535dad52b2877a49717a034b4eee5ff1cdb8a18"},
      {:path=>"/batteryMeter.svg",
       :mime_type=>"image/svg+xml",
       :checksum=>"06a1aab86ba8cb9b3f2913c673d4aa243c553494"},
      {:path=>"/meter.html",
       :mime_type=>"text/html",
       :checksum=>"82e12125c2f1324bbf7bd64bf187f3334416117e"}
    ]
    stub_request(:get, @baseURI).
      with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                      'Content-Type'=>'application/json'}).
                      to_return(body: body.to_json)

    ret = @srv.list()
    expect(ret).to eq(body)
  end

  it "removes" do
    stub_request(:delete, "#{@baseURI}/index.html").
      with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                      'Content-Type'=>'application/json'}).
                      to_return(status: 200)
    ret = @srv.remove('index.html')
    expect(ret).to eq({})
  end

  context "fetches" do
    it "gets an error" do
      stub_request(:get, "#{@baseURI}/bob").
        with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                        'Content-Type'=>'application/json'}).
                        to_return(status: 404, body: "nope")
      saved = $stderr
      $stderr = StringIO.new
      ret = @srv.fetch('/bob')
      expect(ret).to be_nil
      expect($stderr.string).to eq("\e[31mRequest Failed: 404: nope\e[0m\n")
      $stderr = saved
    end

    it "gets $stdout" do
      stub_request(:get, "#{@baseURI}/bob").
        with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                        'Content-Type'=>'application/json'}).
                        to_return(status: 200, body: "nope")
      saved = $stdout
      $stdout = StringIO.new
      ret = @srv.fetch('/bob')
      expect(ret).to be_nil
      expect($stdout.string).to eq("nope")
      $stdout = saved
    end

    it "gets to block" do
      stub_request(:get, "#{@baseURI}/bob").
        with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                        'Content-Type'=>'application/json'}).
                        to_return(status: 200, body: "nope")
      got = ""
      ret = @srv.fetch('/bob') {|chunk| got << chunk}
      expect(ret).to be_nil
      expect(got).to eq("nope")
    end
  end

  context "uploads" do
    before(:example) do
      FileUtils.mkpath(@project_dir + '/files')
      @lp = Pathname.new(@project_dir + '/files/one.text')
      @lp.open('w') {|io| io << %{Just some text}}
      @lp = @lp.realpath
    end

    it "an item" do
      stub_request(:put, "#{@baseURI}upload/one.text").
        with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                        'Content-Type'=>%r{multipart/form-data; boundary=.*}},
            )

      @srv.upload(@lp, {:path=>'/one.text'}, false)
    end

    it "gets an error" do
      stub_request(:put, "#{@baseURI}upload/one.text").
        with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                        'Content-Type'=>%r{multipart/form-data; boundary=.*}},
            ).
        to_return(status: 401, body: "nope")

      saved = $stderr
      $stderr = StringIO.new
      @srv.upload(@lp, {:path=>'/one.text'}, false)
      expect($stderr.string).to eq("\e[31mRequest Failed: 401: nope\e[0m\n")
      $stderr = saved
    end

    it "an item with curl debug" do
      stub_request(:put, "#{@baseURI}upload/one.text").
        with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                        'Content-Type'=>%r{multipart/form-data; boundary=.*}},
            )
      $cfg['tool.curldebug'] = true
      $cfg.curlfile_f = nil
      saved = $stdout
      $stdout = StringIO.new
      @srv.upload(@lp, {:path=>'/one.text'}, false)
      expect($stdout.string).to match(%r{^curl -s -H 'Authorization: token TTTTTTTTTT'.*-X PUT '#{@fileuploadURI}/one.text' -F file=@.*$})
      $stdout = saved
    end
  end

  context "compares" do
    before(:example) do
      @iA = {:path=>"/api/v1/bar",
             :mime_type=>"application/json",
             :checksum=>'12',
             }
      @iB = {:path=>"/api/v1/bar",
             :mime_type=>"application/json",
             :checksum=>'12',
             }
    end
    it "equal" do
      ret = @srv.docmp(@iA, @iB)
      expect(ret).to be false
    end
    it "different mime" do
      iA = @iA.merge({:mime_type=>'text/plain'})
      ret = @srv.docmp(iA, @iB)
      expect(ret).to be true
    end
    it "different checksum" do
      iA = @iA.merge({:checksum=>'4352'})
      ret = @srv.docmp(iA, @iB)
      expect(ret).to be true
    end
  end

  context "Lookup functions" do
    it "gets local name" do
      ret = @srv.tolocalname({:path=>'/one/two/three.html'}, :path)
      expect(ret).to eq('/one/two/three.html')
    end

    it "gets default_page local name" do
      ret = @srv.tolocalname({:path=>'/'}, :path)
      expect(ret).to eq('index.html')
    end

    it "gets synckey" do
      ret = @srv.synckey({:path=>'/one/two/three'})
      expect(ret).to eq("/one/two/three")
    end

    it "gets searchfor" do
      $cfg['files.searchFor'] = %{a b c/**/d/*.bob}
      ret = @srv.searchFor
      expect(ret).to eq(["a", "b", "c/**/d/*.bob"])
    end

    it "gets ignoring" do
      $cfg['files.ignoring'] = %{a b c/**/d/*.bob}
      ret = @srv.ignoring
      expect(ret).to eq(["a", "b", "c/**/d/*.bob"])
    end
  end

  context "to_remote_item" do
    before(:example) do
      FileUtils.mkpath(@project_dir + '/files')
      @lp = Pathname.new(@project_dir + '/files/one.text')
      @lp.open('w') {|io| io << %{Just some text}}
      @lp = @lp.realpath
    end
    it "gets item" do
      prj = Pathname.new(@project_dir).realpath
      ret = @srv.to_remote_item(prj, @lp)
      expect(ret).to eq({
        :path=>"/files/one.text",
        :mime_type=>"text/plain",
        :checksum=>"d1af3dadf08479a1d43b282f95d61dda8efda5e7"
      })
    end
  end
end
#  vim: set ai et sw=2 ts=2 :

require 'tempfile'
require 'MrMurano/hash'
require 'MrMurano/version'
require 'MrMurano/Solution-Users'
require 'MrMurano/SyncRoot'
require '_workspace'

RSpec.describe MrMurano::Role do
  include_context "WORKSPACE"
  before(:example) do
    MrMurano::SyncRoot.instance.reset
    $cfg = MrMurano::Config.new
    $cfg.load
    $cfg['net.host'] = 'bizapi.hosted.exosite.io'
    $cfg['application.id'] = 'XYZ'

    @srv = MrMurano::Role.new
    allow(@srv).to receive(:token).and_return("TTTTTTTTTT")
  end

  it "initializes" do
    uri = @srv.endpoint('/')
    expect(uri.to_s).to eq("https://bizapi.hosted.exosite.io/api:1/solution/XYZ/role/")
  end

  it "lists" do
    body = [{:role_id=>"guest", :parameter=>[{:name=>"did"}]},
            {:role_id=>"admin", :parameter=>[{:name=>"enabled"}]},
            {:role_id=>"owns", :parameter=>[{:name=>"did"}]}]
    stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/solution/XYZ/role").
      with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                      'Content-Type'=>'application/json'}).
                      to_return(body: body.to_json)
    ret = @srv.list
    expect(ret).to eq(body)
  end

  it "fetches" do
    body = {:role_id=>"guest", :parameter=>[{:name=>"did"}]}
    stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/solution/XYZ/role/guest").
      with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                      'Content-Type'=>'application/json'}).
                      to_return(body: body.to_json)
    ret = @srv.fetch('guest')
    expect(ret).to eq(body)
  end

  it "removes" do
    stub_request(:delete, "https://bizapi.hosted.exosite.io/api:1/solution/XYZ/role/guest").
      with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                      'Content-Type'=>'application/json'}).
                      to_return(status: 200, body: "")
    ret = @srv.remove('guest')
    expect(ret).to eq({})
  end

  context "uploads" do
    it "updating" do
      body = {:role_id=>"guest", :parameter=>[{:name=>"did"}]}
      stub_request(:delete, "https://bizapi.hosted.exosite.io/api:1/solution/XYZ/role/guest").
        with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                        'Content-Type'=>'application/json'}).
                        to_return(status: 200, body: "")
      stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/solution/XYZ/role/").
        with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                        'Content-Type'=>'application/json'},
             :body=>body.to_json
            ).
                        to_return(status: 205, body: "")


      @srv.upload(nil, body, true)
    end

    it "creating" do
      body = {:role_id=>"guest", :parameter=>[{:name=>"did"}]}
      stub_request(:delete, "https://bizapi.hosted.exosite.io/api:1/solution/XYZ/role/guest").
        with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                        'Content-Type'=>'application/json'}).
                        to_return(status: 404, body: "")
      stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/solution/XYZ/role/").
        with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                        'Content-Type'=>'application/json'},
             :body=>body.to_json
            ).
                        to_return(status: 205, body: "")


      @srv.upload(nil, body, false)
    end

    it "with delete error" do
      body = {:role_id=>"guest", :parameter=>[{:name=>"did"}]}
      stub_request(:delete, "https://bizapi.hosted.exosite.io/api:1/solution/XYZ/role/guest").
        with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                        'Content-Type'=>'application/json'}).
                        to_return(status: 418, body: "I'm a teapot!")
      stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/solution/XYZ/role/").
        with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                        'Content-Type'=>'application/json'},
             :body=>body.to_json
            ).
                        to_return(status: 205, body: "")

      saved = $stderr
      $stderr = StringIO.new
      @srv.upload(nil, body, false)
      expect($stderr.string).to match(/Request Failed: 418: I'm a teapot/)
      $stderr = saved
    end
  end

  context "downloads" do
    before(:example) do
      @lry = Pathname.new(@project_dir) + 'roles.yaml'
      @grl = {:role_id=>"guest", :parameter=>[{:name=>"could"}]}
    end

    it "creates" do
      @srv.download(@lry, @grl)

      expect(@lry.exist?).to be true
      got = YAML.load(@lry.read)
      expect(got).to include(Hash.transform_keys_to_strings(@grl))
    end

    it "updates" do
      FileUtils.copy(File.join(@testdir, 'spec/fixtures/roles-three.yaml'), @lry.to_path)

      @srv.download(@lry, @grl)
      got = YAML.load(@lry.read)
      expect(got).to include(Hash.transform_keys_to_strings(@grl))
    end
  end

  context "removing local roles" do
    before(:example) do
      @lry = Pathname.new(@project_dir) + 'roles.yaml'
      @grl = {:role_id=>"guest", :parameter=>[{:name=>"could"}]}
    end

    it "when file missing" do
      @srv.removelocal(@lry, @grl)
      expect(@lry.exist?).to be true
      got = YAML.load(@lry.read)
      expect(got).to eq([])
    end

    it "when not there" do
      FileUtils.copy(File.join(@testdir, 'spec/fixtures/roles-three.yaml'), @lry.to_path)
      @srv.removelocal(@lry, {:role_id=>"undertow"})
      got = YAML.load(@lry.read)
      rty = Pathname.new(@testdir) + 'spec/fixtures/roles-three.yaml'
      want = YAML.load(rty.read)
      expect(got).to eq(want)
    end

    it "with matching role" do
      FileUtils.copy(File.join(@testdir, 'spec/fixtures/roles-three.yaml'), @lry.to_path)
      @srv.removelocal(@lry, @grl)
      got = YAML.load(@lry.read)
      expect(got.count).to eq(2)
      expect(got).to contain_exactly(
        a_hash_including('role_id' => 'admin'),
        a_hash_including('role_id' => 'owns')
      )
    end
  end

  it "tolocalpath is into" do
    lry = Pathname.new(@project_dir) + 'roles.yaml'
    ret = @srv.tolocalpath(lry, {:role_id=>"guest", :parameter=>[{:name=>"could"}]})
    expect(ret).to eq(lry)
  end

  context "list local items" do
    before(:example) do
      @lry = Pathname.new(@project_dir) + 'roles.yaml'
    end

    it "when missing" do
      expect(@srv).to receive(:warning).with(/^Skipping missing/)
      ret = @srv.localitems(@lry)
      expect(ret).to eq([])
    end

    it "when not a file" do
      FileUtils.mkpath(@lry.to_path)
      expect(@srv).to receive(:warning).with(/^Cannot read from/)
      ret = @srv.localitems(@lry)
      expect(ret).to eq([])
    end

    it "when empty" do
      FileUtils.touch(@lry.to_path)
      ret = @srv.localitems(@lry)
      expect(ret).to eq([])
    end

    it "with roles" do
      FileUtils.copy(File.join(@testdir, 'spec/fixtures/roles-three.yaml'), @lry.to_path)
      ret = @srv.localitems(@lry)
      expect(ret).to eq([{:role_id=>"guest", :parameter=>[{:name=>"did"}]},
                         {:role_id=>"admin", :parameter=>[{:name=>"enabled"}]},
                         {:role_id=>"owns", :parameter=>[{:name=>"did"}]}])
    end
  end
end
#  vim: set ai et sw=2 ts=2 :

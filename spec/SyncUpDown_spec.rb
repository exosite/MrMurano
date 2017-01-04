require 'MrMurano/version'
require 'MrMurano/verbosing'
require 'MrMurano/Config'
require 'MrMurano/SyncUpDown'
require '_workspace'

class TSUD
  include MrMurano::Verbose
  include MrMurano::SyncUpDown
  def initialize
    @itemkey = :name
    @locationbase = $cfg['location.base']
    @location = 'tsud'
  end
  def fetch(id)
  end
end
RSpec.describe MrMurano::SyncUpDown do
  include_context "WORKSPACE"
  before(:example) do
    $cfg = MrMurano::Config.new
    $cfg.load
    $cfg['net.host'] = 'bizapi.hosted.exosite.io'
    $cfg['solution.id'] = 'XYZ'
  end

  context "status" do
    it "warns with missing directory" do
      t = TSUD.new
      expect(t).to receive(:warning).once.with(/Skipping missing location.*/)
      ret = t.status
      expect(ret).to eq({:toadd=>[], :todel=>[], :tomod=>[], :unchg=>[]})
    end

    it "finds nothing in empty directory" do
      FileUtils.mkpath('tsud')
      t = TSUD.new
      ret = t.status
      expect(ret).to eq({:toadd=>[], :todel=>[], :tomod=>[], :unchg=>[]})
    end

    it "finds things there but not here" do
      FileUtils.mkpath('tsud')
      t = TSUD.new
      expect(t).to receive(:list).once.and_return([
        {:name=>1},{:name=>2},{:name=>3}
      ])
      ret = t.status
      expect(ret).to eq({
        :toadd=>[],
        :todel=>[{:name=>1, :synckey=>1}, {:name=>2, :synckey=>2}, {:name=>3, :synckey=>3}],
        :tomod=>[],
        :unchg=>[]})
    end

    it "finds things there but not here; asdown" do
      FileUtils.mkpath('tsud')
      t = TSUD.new
      expect(t).to receive(:list).once.and_return([
        {:name=>1},{:name=>2},{:name=>3}
      ])
      ret = t.status({:asdown=>true})
      expect(ret).to eq({
        :todel=>[],
        :toadd=>[{:name=>1, :synckey=>1}, {:name=>2, :synckey=>2}, {:name=>3, :synckey=>3}],
        :tomod=>[],
        :unchg=>[]})
    end

    it "finds things here but not there" do
      FileUtils.mkpath('tsud')
      FileUtils.touch('tsud/one.lua')
      FileUtils.touch('tsud/two.lua')
      t = TSUD.new
      ret = t.status
      expect(ret).to eq({
        :toadd=>[
          {:name=>'one.lua', :synckey=>'one.lua',
           :local_path=>Pathname.new(@projectDir + '/tsud/one.lua').realpath},
          {:name=>'two.lua', :synckey=>'two.lua',
           :local_path=>Pathname.new(@projectDir + '/tsud/two.lua').realpath},
        ],
        :todel=>[],
        :tomod=>[],
        :unchg=>[]})
    end

    it "finds things here and there" do
      FileUtils.mkpath('tsud')
      FileUtils.touch('tsud/one.lua')
      FileUtils.touch('tsud/two.lua')
      t = TSUD.new
      expect(t).to receive(:list).once.and_return([
        {:name=>'one.lua'},{:name=>'two.lua'}
      ])
      ret = t.status
      expect(ret).to eq({
        :tomod=>[
          {:name=>'one.lua', :synckey=>'one.lua',
           :local_path=>Pathname.new(@projectDir + '/tsud/one.lua').realpath},
          {:name=>'two.lua', :synckey=>'two.lua',
           :local_path=>Pathname.new(@projectDir + '/tsud/two.lua').realpath},
        ],
        :todel=>[],
        :toadd=>[],
        :unchg=>[]})
    end

    it "finds things here and there; but they're the same" do
      FileUtils.mkpath('tsud')
      FileUtils.touch('tsud/one.lua')
      FileUtils.touch('tsud/two.lua')
      t = TSUD.new
      expect(t).to receive(:list).once.and_return([
        {:name=>'one.lua'},{:name=>'two.lua'}
      ])
      expect(t).to receive(:docmp).twice.and_return(false)
      ret = t.status
      expect(ret).to eq({
        :unchg=>[
          {:name=>'one.lua', :synckey=>'one.lua',
           :local_path=>Pathname.new(@projectDir + '/tsud/one.lua').realpath},
          {:name=>'two.lua', :synckey=>'two.lua',
           :local_path=>Pathname.new(@projectDir + '/tsud/two.lua').realpath},
        ],
        :todel=>[],
        :toadd=>[],
        :tomod=>[]})
    end

    it "calls diff" do
      FileUtils.mkpath('tsud')
      FileUtils.touch('tsud/one.lua')
      t = TSUD.new
      expect(t).to receive(:list).once.and_return([
        {:name=>'one.lua'}
      ])
      expect(t).to receive(:dodiff).once.and_return("diffed output")
      ret = t.status({:diff=>true})
      expect(ret).to eq({
        :tomod=>[
          {:name=>'one.lua', :synckey=>'one.lua',
           :local_path=>Pathname.new(@projectDir + '/tsud/one.lua').realpath,
           :diff=>"diffed output"},
        ],
        :todel=>[],
        :toadd=>[],
        :unchg=>[]})
    end
  end

  it "finds local items" do
    FileUtils.mkpath('tsud')
    FileUtils.touch('tsud/one.lua')
    FileUtils.touch('tsud/two.lua')
    t = TSUD.new
    ret = t.localitems(Pathname.new(@projectDir + '/tsud').realpath)
    expect(ret).to eq([
      {:name=>'one.lua',
       :local_path=>Pathname.new(@projectDir + '/tsud/one.lua').realpath},
      {:name=>'two.lua',
       :local_path=>Pathname.new(@projectDir + '/tsud/two.lua').realpath},
    ])
  end

  context "doing diffs" do
    before(:example) do
      FileUtils.mkpath('tsud')
      @t = TSUD.new
      @scpt = Pathname.new(@projectDir + '/tsud/one.lua')
      @scpt.open('w'){|io| io << %{-- fake lua\nreturn 0\n}}
      @scpt = @scpt.realpath
    end

    it "nothing when same." do
      expect(@t).to receive(:fetch).and_yield(%{-- fake lua\nreturn 0\n})
      ret = @t.dodiff({:name=>'one.lua', :local_path=>@scpt})
      expect(ret).to eq('')
    end

    it "something when different." do
      expect(@t).to receive(:fetch).and_yield(%{-- fake lua\nreturn 2\n})
      ret = @t.dodiff({:name=>'one.lua', :local_path=>@scpt})
      expect(ret).not_to eq('')
    end

    it "uses script in item" do
      script = %{-- fake lua\nreturn 2\n}
      expect(@t).to receive(:fetch).and_yield(script)
      ret = @t.dodiff({:name=>'one.lua', :local_path=>@scpt, :script=>script})
      expect(ret).to eq('')
    end

  end

end
#  vim: set ai et sw=2 ts=2 :
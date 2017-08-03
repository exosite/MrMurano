require 'erb'
require 'tempfile'
require 'MrMurano/version'
require 'MrMurano/Config'
require '_workspace'

RSpec.describe MrMurano::Config do

  context "Basics " do
    include_context "WORKSPACE"
    it "Sets defaults" do
      cfg = MrMurano::Config.new
      cfg.load
      # Don't check for all of them, just a few.
      expect(cfg['files.default_page']).to eq('index.html')
      expect(cfg.get('files.default_page', :defaults)).to eq('index.html')
      expect(cfg['tool.debug']).to eq(false)
      expect(cfg.get('tool.debug', :defaults)).to eq(false)
    end

    it "Sets internal values" do
      cfg = MrMurano::Config.new
      cfg.load

      cfg['bob.test'] = 'twelve'

      expect(cfg['bob.test']).to eq('twelve')
      expect(cfg.get('bob.test', :internal)).to eq('twelve')
    end

    it "Sets tool values" do
      cfg = MrMurano::Config.new
      cfg.load

      cfg['test'] = 'twelve'

      expect(cfg['tool.test']).to eq('twelve')
      expect(cfg.get('tool.test', :internal)).to eq('twelve')
    end

    it "Sets project values" do # This should write
      cfg = MrMurano::Config.new
      cfg.load

      cfg.set('bob.test', 'twelve', :project)

      expect(cfg['bob.test']).to eq('twelve')
      expect(cfg.get('bob.test', :project)).to eq('twelve')

      expect(FileTest.exist?(@project_dir + '.murano/config'))

      #reload
      cfg = MrMurano::Config.new
      cfg.load
      expect(cfg.get('bob.test', :project)).to eq('twelve')
    end

    it "Sets a user value" do
      cfg = MrMurano::Config.new
      cfg.load

      cfg.set('bob.test', 'twelve', :user)

      expect(cfg['bob.test']).to eq('twelve')
      expect(cfg.get('bob.test', :user)).to eq('twelve')

      expect(FileTest.exist?(ENV['HOME'] + '.murano/config'))

      #reload
      cfg = MrMurano::Config.new
      cfg.load
      expect(cfg.get('bob.test', :user)).to eq('twelve')
    end

    it "loads from a specific file" do
      File.open(@project_dir + '/foo.cfg', 'w') do |io|
        io << %{[test]
            bob = test
        }.gsub(/^\s\+/,'')
      end

      cfg = MrMurano::Config.new
      cfg.load
      cfg.load_specific(@project_dir + '/foo.cfg')

      expect(cfg['test.bob']).to eq('test')
    end

    context "returns a path to a file in" do
      it "project mrmurano dir" do
        cfg = MrMurano::Config.new
        cfg.load
        path = cfg.file_at('testfile').realdirpath
        want = Pathname.new(@project_dir + '/.murano/testfile').realdirpath

        expect(path).to eq(want)
      end

      it "user mrmurano dir" do
        cfg = MrMurano::Config.new
        cfg.load
        path = cfg.file_at('testfile', :user).realdirpath
        want = Pathname.new(Dir.home + '/.murano/testfile').realdirpath

        expect(path).to eq(want)
      end

      it "internal" do
        cfg = MrMurano::Config.new
        cfg.load
        path = cfg.file_at('testfile', :internal)

        expect(path).to eq(nil)
      end

      it "specified" do
        cfg = MrMurano::Config.new
        cfg.load
        path = cfg.file_at('testfile', :specified)

        expect(path).to eq(nil)
      end

      it "defaults" do
        cfg = MrMurano::Config.new
        cfg.load
        path = cfg.file_at('testfile', :defaults)

        expect(path).to eq(nil)
      end
    end

    context "ENV['MURANO_CONFIGFILE']" do
      before(:example) do
        @saved_cfg = ENV['MURANO_CONFIGFILE']
      end
      after(:example) do
        ENV['MURANO_CONFIGFILE'] = @saved_cfg
        ENV['MR_CONFIGFILE'] = nil
      end

      it "loads file in env" do
        ENV['MURANO_CONFIGFILE'] = @tmpdir + '/home/test.config'
        File.open(@tmpdir + '/home/test.config', 'w') do |io|
          io << %{[test]
            bob = test
          }.gsub(/^\s\+/,'')
        end

        cfg = MrMurano::Config.new
        cfg.load
        expect(cfg['test.bob']).to eq('test')
      end

      it "will create file at env" do
        ENV['MURANO_CONFIGFILE'] = @tmpdir + '/home/testcreate.config'
        cfg = MrMurano::Config.new
        cfg.load
        cfg.set('coffee.hot', 'yes', :env)

        expect(FileTest.exist?(ENV['MURANO_CONFIGFILE']))

        #reload
        cfg = MrMurano::Config.new
        cfg.load
        expect(cfg['coffee.hot']).to eq('yes')
        expect(cfg.get('coffee.hot', :env)).to eq('yes')
      end

      it "warns about migrating old ENV name" do
        ENV['MURANO_CONFIGFILE'] = nil
        ENV['MR_CONFIGFILE'] = @tmpdir + '/home/testcreate.config'
        expect_any_instance_of(MrMurano::Config).to receive(:warning).once
        MrMurano::Config.new
      end

      it "errors if both are defined" do
        ENV['MURANO_CONFIGFILE'] = @tmpdir + '/home/testcreate.config'
        ENV['MR_CONFIGFILE'] = @tmpdir + '/home/testcreate.config'
        # 2 warnings:
        #   ENV "MR_CONFIGFILE" is no longer supported. Rename it to "MURANO_CONFIGFILE"
        #   Both "MURANO_CONFIGFILE" and "MR_CONFIGFILE" defined,
        #     please remove "MR_CONFIGFILE".
        expect_any_instance_of(MrMurano::Config).to receive(:warning).twice
        #expect_any_instance_of(MrMurano::Config).to receive(:error).once
        MrMurano::Config.new
      end
    end

    it "dumps" do
      @saved_cfg = ENV['MURANO_CONFIGFILE']
      ENV['MURANO_CONFIGFILE'] = nil
      cfg = MrMurano::Config.new
      cfg.load
      cfg['sync.bydefault'] = 'files'
      ret = cfg.dump

      rawwant = IO.read(File.join(@testdir.to_path, 'spec', 'fixtures', 'dumped_config'))
      template = ERB.new(rawwant)
      want = template.result(binding)

      expect(ret).to eq(want)
      ENV['MURANO_CONFIGFILE'] = @saved_cfg
    end

    context "fixing permissions" do
      it "fixes a directory" do
        Dir.mkdir('test')
        cfg = MrMurano::Config.new
        cfg.fix_modes(Pathname.new('test'))
        if Gem.win_platform? then
          expect(FileTest.world_readable? 'test').to eq(493)
          expect(FileTest.world_writable? 'test').to be_nil
        else
          expect(FileTest.world_readable? 'test').to be_nil
          expect(FileTest.world_writable? 'test').to be_nil
        end
      end

      it "fixes a file" do
        FileUtils.touch('test')
        cfg = MrMurano::Config.new
        cfg.fix_modes(Pathname.new('test'))
        if Gem.win_platform? then
          expect(FileTest.world_readable? 'test').to eq(420)
          expect(FileTest.world_writable? 'test').to be_nil
        else
          expect(FileTest.world_readable? 'test').to be_nil
          expect(FileTest.world_writable? 'test').to be_nil
        end
      end
    end
  end

  context "Can find the project directory by .murano/config" do
    before(:example) do
      @tmpdir = Dir.tmpdir
      path = '/home/work/project/some/where'
      @project_dir = @tmpdir + '/home/work/project'
      FileUtils.mkpath(@tmpdir + path)
      FileUtils.mkpath(@project_dir + '/.murano')
      FileUtils.touch(@project_dir + '/.murano/config')

      # Set ENV to override output of Dir.home
      ENV['HOME'] = @tmpdir + '/home'
    end

    after(:example) do
      FileUtils.remove_dir(@tmpdir + '/home', true) if FileTest.exist? @tmpdir
    end

    it "when in project directory" do
      Dir.chdir(@project_dir) do
        cfg = MrMurano::Config.new
        cfg.load
        # Follow symlinks to get the paths comparable.
        locbase = cfg.get('location.base', :defaults).realdirpath
        wkd = Pathname.new(@project_dir).realdirpath
        expect(locbase).to eq(wkd)
      end
    end

    it "when in sub directory" do
      Dir.chdir(@project_dir + '/some/where') do
        cfg = MrMurano::Config.new
        cfg.load
        # Follow symlinks to get the paths comparable.
        locbase = cfg.get('location.base', :defaults).realdirpath
        wkd = Pathname.new(@project_dir).realdirpath
        expect(locbase).to eq(wkd)
      end
    end

    it "when .murano is in both PWD and parent dir" do
      Dir.chdir(@project_dir + '/some') do
        FileUtils.mkpath('.murano')
        FileUtils.touch('.murano/config')
        cfg = MrMurano::Config.new
        cfg.load
        # Follow symlinks to get the paths comparable.
        locbase = cfg.get('location.base', :defaults).realdirpath
        wkd = (Pathname.new(@project_dir) + 'some').realdirpath
        expect(locbase).to eq(wkd)
      end
    end
  end

  context "Can find the project directory by .murano/" do
    before(:example) do
      @tmpdir = Dir.tmpdir
      path = '/home/work/project/some/where'
      @project_dir = @tmpdir + '/home/work/project'
      FileUtils.mkpath(@tmpdir + path)
      FileUtils.mkpath(@project_dir + '/.murano')

      # Set ENV to override output of Dir.home
      ENV['HOME'] = @tmpdir + '/home'
    end

    after(:example) do
      FileUtils.remove_dir(@tmpdir + '/home', true) if FileTest.exist? @tmpdir
    end

    it "when in project directory" do
      Dir.chdir(@project_dir) do
        cfg = MrMurano::Config.new
        cfg.load
        # Follow symlinks to get the paths comparable.
        locbase = cfg.get('location.base', :defaults).realdirpath
        wkd = Pathname.new(@project_dir).realdirpath
        expect(locbase).to eq(wkd)
      end
    end

    it "when in sub directory" do
      Dir.chdir(@project_dir + '/some/where') do
        cfg = MrMurano::Config.new
        cfg.load
        # Follow symlinks to get the paths comparable.
        locbase = cfg.get('location.base', :defaults).realdirpath
        wkd = Pathname.new(@project_dir).realdirpath
        expect(locbase).to eq(wkd)
      end
    end

    it "when .murano is in both PWD and parent dir" do
      Dir.chdir(@project_dir + '/some') do
        FileUtils.mkpath('.murano')
        cfg = MrMurano::Config.new
        cfg.load
        # Follow symlinks to get the paths comparable.
        locbase = cfg.get('location.base', :defaults).realdirpath
        wkd = (Pathname.new(@project_dir) + 'some').realdirpath
        expect(locbase).to eq(wkd)
      end
    end
  end

  context "When pwd is $HOME:" do
    before(:example) do
      @tmpdir = Dir.tmpdir
      @project_dir = @tmpdir + '/home/work/project'
      FileUtils.mkpath(@project_dir)
      # Set ENV to override output of Dir.home
      ENV['HOME'] = @tmpdir + '/home'
    end

    after(:example) do
      FileUtils.remove_dir(@tmpdir + '/home', true) if FileTest.exist? @tmpdir
    end

    it "Sets a user value" do
      Dir.chdir(ENV['HOME']) do
        cfg = MrMurano::Config.new
        cfg.load

        cfg.set('bob.test', 'twelve', :user)

        expect(cfg['bob.test']).to eq('twelve')
        expect(cfg.get('bob.test', :user)).to eq('twelve')

        expect(FileTest.exist?(ENV['HOME'] + '/.murano/config')).to be true

        #reload
        cfg = MrMurano::Config.new
        cfg.load
        expect(cfg.get('bob.test', :user)).to eq('twelve')
      end
    end

    it "Sets project values" do # This should write
      Dir.chdir(ENV['HOME']) do
        cfg = MrMurano::Config.new
        cfg.load

        cfg.set('bob.test', 'twelve', :project)

        expect(cfg['bob.test']).to eq('twelve')
        expect(cfg.get('bob.test', :project)).to eq('twelve')

        expect(FileTest.exist?(ENV['HOME'] + '/.murano/config')).to be true

        #reload
        cfg = MrMurano::Config.new
        cfg.load
        expect(cfg.get('bob.test', :project)).to eq('twelve')
      end
    end

    it "write a project value and reads it as a user value" do
      Dir.chdir(ENV['HOME']) do
        cfg = MrMurano::Config.new
        cfg.load

        cfg.set('bob.test', 'twelve', :project)

        expect(cfg['bob.test']).to eq('twelve')
        # :user won't have the new value until it is loaded again
        expect(cfg.get('bob.test', :project)).to eq('twelve')

        expect(FileTest.exist?(ENV['HOME'] + '/.murano/config')).to be true

        #reload
        cfg = MrMurano::Config.new
        cfg.load
        expect(cfg.get('bob.test', :user)).to eq('twelve')
      end
    end
  end

  context "Warns about migrating old" do
    include_context "WORKSPACE"

    it "config file name" do
      FileUtils.touch(@project_dir + '/.mrmuranorc')
      expect_any_instance_of(MrMurano::Config).to receive(:warning).once
      cfg = MrMurano::Config.new
      cfg.validate_cmd
    end

    it "config directory name" do
      FileUtils.mkpath(@project_dir + '/.mrmurano')
      expect_any_instance_of(MrMurano::Config).to receive(:warning).once
      cfg = MrMurano::Config.new
      cfg.validate_cmd
    end
  end
end

#  vim: set ai et sw=2 ts=2 :

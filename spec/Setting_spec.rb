require 'tempfile'
require 'yaml'
require 'MrMurano/version'
require 'MrMurano/ProjectFile'
require 'MrMurano/Setting'
require 'MrMurano/SyncRoot'
require 'MrMurano/SyncUpDown'
require '_workspace'

module ::MrMurano
  module Testset
    class Settings
      def specific
      end
      def specific=(x)
      end
    end
  end
  module Testsettwo
  end
end

RSpec.describe MrMurano::Setting do
  include_context "WORKSPACE"
  before(:example) do
    MrMurano::SyncRoot.instance.reset
    $cfg = MrMurano::Config.new
    $cfg.load
    $cfg['net.host'] = 'bizapi.hosted.exosite.io'
    $cfg['product.id'] = 'XYZ'

    @srv = MrMurano::Setting.new
  end

  context "maps service name" do
    it "device2 into Gateway" do
      ret = @srv.mapservice('device2')
      expect(ret).to eq('Gateway')
    end

    it "gaTeWaY into Gateway" do
      ret = @srv.mapservice('gaTeWaY')
      expect(ret).to eq('Gateway')
    end

    it "WeBServICe into Webservice" do
      ret = @srv.mapservice('WeBServICe')
      expect(ret).to eq('Webservice')
    end

    it "bob into Bob" do
      ret = @srv.mapservice('bob')
      expect(ret).to eq('Bob')
    end
  end

  context "read" do
    it "displays error when Service doesn't exist" do
      expect(@srv).to receive(:error).with("No Settings on \"Fiddlingsticks\"")
      ret = @srv.read('Fiddlingsticks', 'specific')
      expect(ret).to be_nil
    end

    it "displays error when Service doesn't have any Settings" do
      expect(@srv).to receive(:error).with("No Settings on \"Testsettwo\"")
      ret = @srv.read('Testsettwo', 'specific')
      expect(ret).to be_nil
    end

    it "displays error when Service doesn't have this Setting" do
      expect(@srv).to receive(:error).with("Unknown setting 'flipit' on 'Testset'")
      ret = @srv.read('Testset', 'flipit')
      expect(ret).to be_nil
    end

    it "the settings" do
      expect_any_instance_of(MrMurano::Testset::Settings).to receive(:specific).and_return(4)
      ret = @srv.read('Testset', 'specific')
      expect(ret).to eq(4)
    end
  end

  context "writes" do
    it "displays error when Service doesn't exist" do
      expect(@srv).to receive(:error).with("No Settings on \"Fiddlingsticks\"")
      ret = @srv.write('Fiddlingsticks', 'specific', 4)
      expect(ret).to be_nil
    end

    it "displays error when Service doesn't have any Settings" do
      expect(@srv).to receive(:error).with("No Settings on \"Testsettwo\"")
      ret = @srv.write('Testsettwo', 'specific', 4)
      expect(ret).to be_nil
    end

    it "displays error when Service doesn't have this Setting" do
      expect(@srv).to receive(:error).with("Unknown setting 'flipit' on 'Testset'")
      ret = @srv.write('Testset', 'flipit', 4)
      expect(ret).to be_nil
    end

    it "the settings" do
      expect_any_instance_of(MrMurano::Testset::Settings).to receive(:specific=).with(4).and_return(4)
      ret = @srv.write('Testset', 'specific', 4)
      expect(ret).to eq(4)
    end
  end
end

#  vim: set ai et sw=2 ts=2 :

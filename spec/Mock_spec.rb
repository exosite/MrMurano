require 'tempfile'
require 'MrMurano/Config'
require 'MrMurano/Mock'
require '_workspace'

RSpec.describe MrMurano::Mock, "#mock" do
  include_context "WORKSPACE"
  before(:example) do
    FileUtils.mkpath(@project_dir + '/routes')
    $cfg = MrMurano::Config.new
    $cfg.load

    @mock = MrMurano::Mock.new
  end

  it "can create the testpoint file" do
      uuid = @mock.create_testpoint()
      expect(uuid.length).to be("XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX".length)
      path = @mock.get_testpoint_path()
      testpoint = File.read(path)
      expect(testpoint.include? uuid).to be(true)
  end

  it "can show the UUID from the testpoint file" do
      uuid = @mock.create_testpoint()
      retrieved_uuid = @mock.show()
      expect(uuid).to eq(retrieved_uuid)
  end

  it "can remove the testpoint file" do
      @mock.create_testpoint()
      path = @mock.get_testpoint_path()
      removed = @mock.remove_testpoint()
      expect(removed).to be(true)
      expect(File.exist?(path)).to be(false)
  end

  it "can remove the missing testpoint file" do
      path = @mock.get_testpoint_path()
      removed = @mock.remove_testpoint()
      expect(removed).to be(false)
      expect(File.exist?(path)).to be(false)
  end

  it "cannot show the UUID if there's no testpoint file" do
      @mock.create_testpoint()
      @mock.show()
      @mock.remove_testpoint()
      retrieved_uuid = @mock.show()
      expect(retrieved_uuid).to be(false)
  end
end
#  vim: set ai et sw=2 ts=2 :

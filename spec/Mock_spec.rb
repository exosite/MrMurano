# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

require 'tempfile'
require 'MrMurano/Config'
require 'MrMurano/Mock'
require '_workspace'

RSpec.describe MrMurano::Mock, '#mock' do
  include_context 'WORKSPACE'
  before(:example) do
    FileUtils.mkpath(@project_dir + '/routes')
    $cfg = MrMurano::Config.new
    $cfg.load

    @mock = MrMurano::Mock.new
  end

  it 'can create the testpoint file' do
    uuid = @mock.create_testpoint
    # rubocop:disable Performance/FixedSize
    #   "Do not compute the size of statically sized objects."
    expect(uuid.length).to be('XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX'.length)
    path = @mock.testpoint_path
    testpoint = File.read(path)
    expect(testpoint.include?(uuid)).to be(true)
  end

  it 'can show the UUID from the testpoint file' do
    uuid = @mock.create_testpoint
    retrieved_uuid = @mock.show
    expect(uuid).to eq(retrieved_uuid)
  end

  it 'can remove the testpoint file' do
    @mock.create_testpoint
    path = @mock.testpoint_path
    removed = @mock.remove_testpoint
    expect(removed).to be(true)
    expect(File.exist?(path)).to be(false)
  end

  it 'can remove the missing testpoint file' do
    path = @mock.testpoint_path
    removed = @mock.remove_testpoint
    expect(removed).to be(false)
    expect(File.exist?(path)).to be(false)
  end

  it "cannot show the UUID if there's no testpoint file" do
    @mock.create_testpoint
    @mock.show
    @mock.remove_testpoint
    retrieved_uuid = @mock.show
    expect(retrieved_uuid).to be(false)
  end
end


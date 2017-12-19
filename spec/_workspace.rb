# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

require 'fileutils'
require 'pathname'
require 'tmpdir'

RSpec.shared_context 'WORKSPACE' do
  around(:example) do |ex|
    @testdir = Pathname.new(Dir.pwd).realpath
    Dir.mktmpdir do |hdir|
      @tmpdir = hdir
      saved_home = ENV['HOME']
      # Set ENV to override output of Dir.home
      ENV['HOME'] = File.join(hdir, 'home')
      FileUtils.mkpath(ENV['HOME'])
      Dir.chdir(hdir) do
        @project_dir = File.join(ENV['HOME'], 'work', 'project')
        FileUtils.mkpath(@project_dir)
        Dir.chdir(@project_dir) do
          ex.run
        end
      end
      ENV['HOME'] = saved_home
    end
  end
end


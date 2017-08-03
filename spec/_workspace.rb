require 'fileutils'
require 'pathname'
require 'tmpdir'

RSpec.shared_context "WORKSPACE" do

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

#  vim: set ai et sw=2 ts=2 :

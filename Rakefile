# Last Modified: 2017.08.03 /coding: utf-8
# frozen_string_literal: true

# Copyright © 2016-2017 Exosite LLC.
# License: MIT. See LICENSE.txt.
#  vim:tw=0:ts=2:sw=2:et:ai

require 'bundler/gem_tasks'
require 'shellwords'

task default: %i[test]

tag_name = "v#{Bundler::GemHelper.gemspec.version}"
gem_name = "MuranoCLI-#{Bundler::GemHelper.gemspec.version}.gem"
built_gem = "pkg/#{gem_name}"

desc 'Install gem in user dir'
task :bob do
  sh %(gem install --user-install #{built_gem})
end

desc 'Uninstall from user dir'
task :unbob do
  sh %(gem uninstall --user-install #{built_gem})
end

task :echo do
  puts tag_name
  puts gem_name
  puts built_gem
end

desc 'display remind of how to release'
task :release_reminder do
  puts <<~EOR
    git flow release start <newversion>
    gvim lib/MrMurano/version.rb
    git commit -a -m 'version bump'
    git flow release finish <newversion>
    # When editing message for tag, add release notes.
    #rake git:all
    # Wait for all tests to complete.
    # if all passed: rake gemit
  EOR
end

desc 'Prints a cmd to test this in another directory'
task :testwith do
  pwd = Dir.pwd.sub(Dir.home, '~')
  puts "ruby -I#{pwd}/lib #{pwd}/bin/murano "
end

desc 'Run RSpec'
task :rspec do
  Dir.mkdir('report') unless File.directory?('report')
  rv = RUBY_VERSION.tr('.', '_')
  sh %(rspec --format html --out report/index-#{rv}.html --format documentation)
end
task test: %i[test_clean_up rspec]

desc 'Clean out junk from prior hot tests'
task :test_clean_up do
  unless ENV['MURANO_CONFIGFILE'].nil?
    ids = `ruby -Ilib bin/murano solution list --idonly`.chomp
    unless ids.empty?
      puts "Found solutions #{ids}; deleting"
      ids.split.each do |id|
        sh %(ruby -Ilib bin/murano solution delete #{id})
      end
    end
  end
end

###
# When new tags are pushed to upstream, the CI will kick-in and build the release
#namespace :git do
#    desc 'Push only develop, master, and tags to origin'
#    task :origin do
#        sh %(git push origin develop)
#        sh %(git push origin master)
#        sh %(git push origin --tags)
#    end
#
#    desc 'Push only develop, master, and tags to upstream'
#    task :upstream do
#        sh %(git push upstream develop)
#        sh %(git push upstream master)
#        sh %(git push upstream --tags)
#    end
#
#    desc 'Push to origin and upstream'
#    task all: %i[origin upstream]
#end

desc 'Build, install locally, and push gem'
task :gemit do
  mrt = Bundler::GemHelper.gemspec.version
  sh %(git checkout v#{mrt})
  Rake::Task[:build].invoke
  Rake::Task[:bob].invoke
  Rake::Task['push:gem'].invoke
  sh %(git checkout develop)
end

###########################################
# Tasks below are largly used by CI systems
namespace :push do
  desc 'Push gem up to RubyGems'
  task :gem do
    sh %(gem push #{built_gem})
  end

  namespace :github do
    desc 'Verify that the computed tag exists'
    task :verifyTag do
      r = `git tag -l #{tag_name}`
      raise "Tag doesn't exist (#{tag_name})" if r.empty?
    end

    desc 'Make a release in Github'
    task :makeRelease do
      # ENV['GITHUB_TOKEN'] set by CI.
      # ENV['GITHUB_USER'] set by CI.
      # ENV['GITHUB_REPO'] set by CI
      # Create Release
      sh %(github-release info --tag #{tag_name}) do |ok, _res|
        unless ok
          # if version contains more than #.#.#, mark it as pre-release
          if /v\d+\.\d+\.\d+(.*)/.match(tag_name)[1].nil?
            sh %(github-release release --tag #{tag_name})
          else
            sh %(github-release release --tag #{tag_name} -p)
          end
        end
      end
    end

    desc 'Push gem up to Github Releases'
    task gem: %i[makeRelease build] do
      # ENV['GITHUB_TOKEN'] set by CI.
      # ENV['GITHUB_USER'] set by CI.
      # ENV['GITHUB_REPO'] set by CI
      # upload gem
      sh %(github-release upload --tag #{tag_name} --name #{gem_name} --file #{built_gem})
    end

    desc 'Copy tag commit message into Release Notes'
    task :copyReleaseNotes do
      tag_msg = `git tag -l -n999 #{tag_name}`.lines
      tag_msg.shift
      msg = tag_msg.join.shellescape
      sh %(github-release edit --tag #{tag_name} --description #{msg})
    end
  end
end

file 'ReadMe.txt' => ['README.markdown'] do |t|
  File.open(t.prerequisites.first) do |rio|
    File.open(t.name, 'w') do |wio|
      wio << rio.read.gsub(/\n/, "\r\n")
    end
  end
end

if Gem.win_platform?
  desc 'Build as a single windows exe'
  file 'murano.exe' => Dir['lib/**/*.{rb,erb,yaml}'] do
    # Need to find all dlls, because ocra isn't finding them for some reason.
    # NOTE: $: same as $LOAD_PATH
    shadlls = Dir[*$LOAD_PATH.map { |i| File.join(i, 'digest/sha2.{so,dll}') }]
    gemdir = `gem env gemdir`.chomp
    gemdlls = Dir[File.join(gemdir, 'extensions', '*')]
    data_files = Dir['lib/**/*.{erb,yaml}']
    others = gemdlls + data_files + shadlls
    ENV['RUBYLIB'] = 'lib'
    sh %(ocra bin/murano #{others.join(' ')})
  end
  task wexe: ['murano.exe']

  desc 'Run rspec on cmd tests using murano.exe'
  task murano_exe_test: ['murano.exe'] do
    Dir.mkdir('report') unless File.directory?('report')
    rv = RUBY_VERSION.tr('.', '_')
    ENV['CI_MR_EXE'] = '1'
    sh %(rspec --format html --out report/murano_exe-#{rv}.html --format documentation --tag cmd)
  end
  task test: %i[murano_exe_test]

  installer_name = "Output/MuranoCLI-#{Bundler::GemHelper.gemspec.version}-Setup.exe"

  desc 'Build a Windows installer for MuranoCLI'
  task inno: [installer_name]

  file 'Output/MuranoCLISetup.exe' => ['murano.exe', 'ReadMe.txt'] do
    ENV['MRVERSION'] = Bundler::GemHelper.gemspec.version.to_s
    sh %("C:\\Program Files (x86)\\Inno Setup 5\\iscc.exe" MuranoCLI.iss)
  end
  file installer_name => ['Output/MuranoCLISetup.exe'] do |t|
    FileUtils.move t.prerequisites.first, t.name, verbose: true
  end

  namespace :push do
    namespace :github do
      desc 'Push Windows installer to Github Releases'
      task inno: [:makeRelease, installer_name] do
        # ENV['GITHUB_TOKEN'] set by CI.
        # ENV['GITHUB_USER'] set by CI.
        # ENV['GITHUB_REPO'] set by CI
        iname = File.basename(installer_name)
        sh %(github-release upload --tag #{tag_name} --name #{iname} --file #{installer_name})
      end
    end
  end
end


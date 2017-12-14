# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

require 'commander/import'
require 'dotenv'
require 'English'
require 'highline'
require 'pathname'
#require 'pp'
require 'rainbow'
require 'rubygems'
require 'MrMurano'
require 'MrMurano/Config'
require 'MrMurano/ProjectFile'

# DEVs: Store environs in an .env file that gets loaded here. Alternatively,
#   run a Bash or similar script before you start developing.
Dotenv.load

# Don't drop traces on ^C.
# EXPLAIN/2017-06-30: [lb] not sure what "drop traces" means.
#   What happens if we don't trap Ctrl-C?
# NOTE: The second parameter is either a string, or a command or block to
#   call or run. Ruby honors certain special strings, like 'EXIT':
#   "If the command is “EXIT”, the script will be terminated by the signal."
#   Per https://ruby-doc.org/core-2.2.0/Signal.html
Signal.trap('INT', 'EXIT')

program :version, MrMurano::VERSION

program :description, %(
  Manage Applications and Products in Exosite's Murano
).strip

# If being piped, e.g.,
#   murano command ... | ...
# or
#   VAR=$(murano command ...)
# etc., then do not do progress.
# TEST/2017-08-23: Does this work on Windows?
ARGV.push('--no-progress') unless $stdout.tty? || ARGV.include?('--no-progress')

default_command :help

# Look for plug-ins.
pgds = [
  Pathname.new(Dir.home) + '.mrmurano' + 'plugins',
  Pathname.new(Dir.home) + '.murano' + 'plugins',
]
# Add plugin dirs from configs
# This is run before the command line options are parsed, so need to check old way.
unless ARGV.include? '--skip-plugins'
  pgds << Pathname.new(ENV['MR_MURANO_PLUGIN_DIR']) if ENV.key? 'MR_MURANO_PLUGIN_DIR'
  pgds << Pathname.new(ENV['MURANO_PLUGIN_DIR']) if ENV.key? 'MURANO_PLUGIN_DIR'
  pgds.each do |path|
    next unless path.exist?
    path.each_child do |plugin|
      next if plugin.directory?
      next unless plugin.readable?
      next if plugin.basename.fnmatch('.*') # don't read anything starting with .
      begin
        require plugin.to_s
      #rescue Exception => err
      rescue StandardError => err
        warn "Failed to load plugin at #{plugin} because #{err}"
      end
    end
  end
end

# Look for .murano/config files.
$cfg = MrMurano::Config.new(::Commander::Runner.instance)
$cfg.load
$cfg.validate_cmd

# Look for a (legacy) Solutionfile.json.
$project = MrMurano::ProjectFile.new
$project.load

# The Commander defaults to paged help.
# The user can disable with --no-page, e.g.,
#   alias murano='murano --no-page'
# We define this here and not in globals.rb because
#   `murano --help` does not cause globals.rb to be sourced.
paging = nil
paging = true if ARGV.include?('--page')
paging = false if ARGV.include?('--no-page')
unless paging.nil?
  program :help_paging, paging
  $cfg['tool.no-page'] = !paging
end
# else, commander defaults to paging.


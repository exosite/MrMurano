# Last Modified: 2017.07.31 /coding: utf-8
# frozen_string_literal: true

# Copyright © 2016-2017 Exosite LLC.
# License: MIT. See LICENSE.txt.
#  vim:tw=0:ts=2:sw=2:et:ai

require 'highline'
require 'inifile'
require 'pathname'
require 'rainbow'
require 'MrMurano/verbosing'
require 'MrMurano/SyncRoot'

module MrMurano
  class Config
    include Verbose

    # Config scopes:
    #  :internal    transient this-run-only things (also -c options)
    #  :specified   from --configfile
    #  :env         from ENV['MURANO_CONFIGFILE']
    #  :project     .murano/config at project dir
    #  :user        .murano/config at $HOME
    #  :defaults    Internal hardcoded defaults
    # NOTE: This list is ordered, such that values stored in upper scopes
    #   mask values of the same keys in the lower scopes.
    CFG_SCOPES = %i[internal specified env project user defaults].freeze

    ConfigFile = Struct.new(:kind, :path, :data) do
      def load
        return if kind == :internal
        return if kind == :defaults
        # DEVs: Uncomment if you're trying to figure where settings are coming from.
        #   See also: murano config --locations
        #puts "Loading config at: #{path}"
        self[:path] = Pathname.new(path) unless path.is_a? Pathname
        self[:data] = IniFile.new(filename: path.to_s) if self[:data].nil?
        self[:data].restore
      end

      def write
        return if kind == :internal
        return if kind == :defaults
        if defined?($cfg) && !$cfg.nil? && $cfg['tool.dry']
          # $cfg.nil? when run from spec tests that don't load it with:
          #   include_context "CI_CMD"
          MrMurano::Verbose.warning('--dry: Not writing config file')
          return
        end
        self[:path] = Pathname.new(path) unless path.is_a?(Pathname)
        # Ensure path to the file exists.
        unless path.dirname.exist?
          path.dirname.mkpath
          MrMurano::Config.fix_modes(path.dirname)
        end
        self[:data] = IniFile.new(filename: path.to_s) if self[:data].nil?
        self[:data].save
        path.chmod(0o600)
      end
    end

    attr_reader :paths
    attr_reader :projectDir
    attr_reader :project_exists
    attr_reader :curlfile_f

    CFG_ENV_NAME = %(MURANO_CONFIGFILE)
    CFG_FILE_NAME = %(.murano/config)
    CFG_DIR_NAME = %(.murano)

    CFG_OLD_ENV_NAME = %(MR_CONFIGFILE)
    CFG_OLD_DIR_NAME = %(.mrmurano)
    CFG_OLD_FILE_NAME = %(.mrmuranorc)

    CFG_SOLUTION_ID_KEYS = %w[application.id product.id].freeze

    def migrate_old_env
      return if ENV[CFG_OLD_ENV_NAME].nil?
      warning %(ENV "#{CFG_OLD_ENV_NAME}" is no longer supported. Rename it to "#{CFG_ENV_NAME}")
      unless ENV[CFG_ENV_NAME].nil?
        warning %(Both "#{CFG_ENV_NAME}" and "#{CFG_OLD_ENV_NAME}" defined, please remove "#{CFG_OLD_ENV_NAME}".)
      end
      ENV[CFG_ENV_NAME] = ENV[CFG_OLD_ENV_NAME]
    end

    def migrate_old_config(where)
      # Check for dir.
      if (where + CFG_OLD_DIR_NAME).exist?
        warning %(Moving old directory "#{CFG_OLD_DIR_NAME}" to "#{CFG_DIR_NAME}" in "#{where}")
        (where + CFG_OLD_DIR_NAME).rename(where + CFG_DIR_NAME)
      end

      # Check for cfg.
      # rubocop:disable Style/GuardClause
      if (where + CFG_OLD_FILE_NAME).exist?
        warning %(Moving old config "#{CFG_OLD_FILE_NAME}" to "#{CFG_FILE_NAME}" in "#{where}")
        (where + CFG_DIR_NAME).mkpath
        (where + CFG_OLD_FILE_NAME).rename(where + CFG_FILE_NAME)
      end
    end

    def initialize(cmd_runner)
      @runner = cmd_runner

      @paths = []
      @paths << ConfigFile.new(:internal, nil, IniFile.new)
      # :specified --configfile FILE goes here. (see load_specific)

      migrate_old_env
      unless ENV[CFG_ENV_NAME].nil?
        # if it exists, must be a file
        # if it doesn't exist, that's ok
        ep = Pathname.new(ENV[CFG_ENV_NAME])
        @paths << ConfigFile.new(:env, ep) if ep.file? || !ep.exist?
      end

      @project_dir, @project_exists = find_project_dir
      # For murano init, do not use parent config file as project config.
      if @runner.active_command.restrict_to_cur_dir
        pwd = Pathname.new(Dir.pwd).realpath
        if @project_dir != pwd
          @project_dir = pwd
          @project_exists = false
        end
      end
      @paths << ConfigFile.new(:project, @project_dir + CFG_FILE_NAME)

      @paths << ConfigFile.new(:user, Pathname.new(Dir.home) + CFG_FILE_NAME)

      @paths << ConfigFile.new(:defaults, nil, IniFile.new)

      # The user can exclude certain scopes.
      @exclude_scopes = []

      # All these set()'s are against the :defaults config.
      # So no disk writing ensues. And these serve as defaults
      # unless, say, a SolutionFile says otherwise.

      set('tool.verbose', false, :defaults)
      set('tool.debug', false, :defaults)
      set('tool.dry', false, :defaults)
      set('tool.fullerror', false, :defaults)
      set('tool.outformat', 'best', :defaults)

      set('net.host', 'bizapi.hosted.exosite.io', :defaults)

      set('location.base', @project_dir, :defaults) unless @project_dir.nil?
      set('location.files', 'files', :defaults)
      set('location.endpoints', 'routes', :defaults)
      set('location.modules', 'modules', :defaults)
      set('location.eventhandlers', 'services', :defaults)
      set('location.resources', 'specs/resources.yaml', :defaults)
      set('location.cors', 'cors.yaml', :defaults)

      set('sync.bydefault', SyncRoot.instance.bydefault.join(' '), :defaults) if defined? SyncRoot

      set('files.default_page', 'index.html', :defaults)
      set('files.searchFor', '**/*', :defaults)
      set('files.ignoring', '', :defaults)

      set('endpoints.searchFor', '{,../endpoints}/*.lua {,../endpoints}s/*/*.lua', :defaults)
      set('endpoints.ignoring', '*_test.lua *_spec.lua .*', :defaults)

      set(
        'eventhandler.searchFor',
        '*.lua */*.lua {../eventhandlers,../event_handler}/*.lua {../eventhandlers,../event_handler}/*/*.lua',
        :defaults,
      )
      set('eventhandler.ignoring', '*_test.lua *_spec.lua .*', :defaults)
      set('eventhandler.skiplist', 'websocket webservice device.service_call interface device2.event', :defaults)

      set('modules.searchFor', '*.lua **/*.lua', :defaults)
      set('modules.ignoring', '*_test.lua *_spec.lua .*', :defaults)

      if Gem.win_platform?
        set('diff.cmd', 'fc', :defaults)
      else
        set('diff.cmd', 'diff -u', :defaults)
      end
    end

    ## Find the root of this project Directory.
    #
    # The Project dir is the directory between PWD and HOME
    # that has one of (in order of preference):
    # - .murano/config
    # - .mrmuranorc
    # - .murano/
    # - .mrmurano/
    def find_project_dir
      file_names = [CFG_FILE_NAME, CFG_OLD_FILE_NAME]
      dir_names = [CFG_DIR_NAME, CFG_OLD_DIR_NAME]
      home = Pathname.new(Dir.home).realpath
      pwd = Pathname.new(Dir.pwd).realpath
      # The home directory contains the user ~/.murano/config,
      # so we cannot also have a project .murano/ directory.
      return home, false if home == pwd
      pwd.ascend do |path|
        # Don't bother with home or looking above it.
        break if path == home
        file_names.each do |fname|
          return path, true if (path + fname).exist?
        end
        dir_names.each do |dname|
          return path, true if (path + dname).directory?
        end
      end
      # Now if nothing found, assume it will live in pwd.
      result = Pathname.new(Dir.pwd)
      [result, false]
    end
    private :find_project_dir

    def validate_cmd
      # Most commands should be run from within a Murano project (sub-)directory.
      # If user is running a project command not within a project directory,
      # we'll print a message now and exit the app from run_active_command later.
      the_cmd = @runner.active_command
      unless the_cmd.name == 'help' || the_cmd.project_not_required || @project_exists
        error %(The "#{the_cmd.name}" command only works in a Murano project.)
        say %(Please change to a project directory, or run `murano init` to create a new project.)
        # Note that commnander-rb uses an at_exit hook, which we hack around.
        @runner.command_exit = 1
        return
      end

      migrate_old_config(@project_dir)
      migrate_old_config(Pathname.new(Dir.home))
    end

    def self.fix_modes(path)
      if path.directory?
        path.chmod(0o700)
      elsif path.file?
        path.chmod(0o600)
      end
    end

    def fix_modes(path)
      MrMurano::Config.fix_modes(path)
    end

    def file_at(name, scope=:project)
      case scope
      when :internal
        root = nil
      when :specified
        root = nil
      when :project
        root = @project_dir + CFG_DIR_NAME
      when :user
        root = Pathname.new(Dir.home) + CFG_DIR_NAME
      when :defaults
        root = nil
      end
      return nil if root.nil?
      root.mkpath
      root + name
    end

    ## Load all of the potential config files
    def load
      # - read/write config file in [Project, User, System] (all are optional)
      @paths.each(&:load)
      # If user wants curl commands dumped to a file, open that file.
      init_curl_file
    end

    ## Load specified file into the config stack
    # This can be called multiple times and each will get loaded into the config
    def load_specific(file)
      spc = ConfigFile.new(:specified, Pathname.new(file))
      spc.load
      @paths.insert(1, spc)
    end

    ## Get a value for key, looking at the specified scopes
    # key is <section>.<key>
    def get(key, scope=CFG_SCOPES)
      scope = [scope] unless scope.is_a? Array
      paths = @paths.select { |p| scope.include? p.kind }
      paths = paths.reject { |p| @exclude_scopes.include? p.kind }

      section, ikey = key.split('.')
      paths.each do |path|
        next unless path.data.has_section?(section)
        sec = path.data[section]
        return sec if ikey.nil?
        return sec[ikey] if sec.key?(ikey)
      end
      nil
    end

    def set(key, value, scope=:project)
      section, ikey = key.split('.', 2)
      raise 'Invalid key' if section.nil?
      if ikey.nil?
        # If key isn't dotted, then assume the tool section.
        ikey = section
        section = 'tool'
      end

      paths = @paths.select { |p| scope == p.kind }
      raise "Unknown scope ‘#{scope}’" if paths.empty?
      raise "Too many scopes ‘#{scope}’" if paths.length > 1

      cfg = paths.first
      data = cfg.data
      tomod = data[section]
      tomod[ikey] = value unless value.nil?
      tomod.delete(ikey) if value.nil?
      data[section] = tomod
      # Remove empty sections to make test results more predictable.
      # Interesting: IniFile.each only returns sections with key-vals,
      #              so call IniFile.each_section instead, which includes
      #              empty empty section. Here's what "each" looks like:
      #                 data.each do |sectn, param, val|
      #                   puts "#{param} = #{val} [in section: #{sectn}]"
      data.each_section do |sectn|
        data.delete_section(sectn) if data[sectn].empty?
      end

      cfg.write
    end

    # key is <section>.<key>
    def [](key)
      get(key)
    end

    # For setting internal, this-run-only values.
    def []=(key, value)
      set(key, value, :internal)
    end

    def exclude_scopes=(skip_scopes)
      @exclude_scopes = skip_scopes
    end

    ## Dump out a combined config
    def dump
      # have a fake, merge all into it, then dump it.
      base = IniFile.new
      @paths.reverse.each do |ini|
        base.merge! ini.data
      end
      base.to_s
    end

    ## Dump out locations of all known configs
    def locations
      locats = ''
      first = true
      puts ''
      CFG_SCOPES.each do |scope|
        locats += "\n" unless first
        first = false

        cfg_paths = @paths.select { |p| p.kind == scope }

        msg = "Scope: ‘#{scope}’\n\n"
        locats += Rainbow(msg).bright.underline

        if !cfg_paths.empty?
          cfg = cfg_paths.first

          if !cfg.path.nil? && cfg.path.exist?
            path = "Path: #{cfg.path}\n"
          elsif %i[internal defaults].include? cfg.kind
            # cfg.path is nil.
            path = "Path: ‘#{scope}’ config is not saved.\n"
          else
            path = "Path: ‘#{scope}’ config does not exist.\n"
          end
          #locats += Rainbow(path).bright
          locats += path
          locats += "\n"

          skip_content = false
          if scope == :env
            locats += "Use the environment variable, MURANO_CONFIGFILE, to specify this config file.\n"
            skip_content = !cfg.path.exist?
          end
          next if skip_content
          locats += "\n" if scope == :env

          base = IniFile.new
          base.merge! cfg.data
          content = base.to_s
          if !content.empty?
            locats += "Config:\n\n"
            #locats += base.to_s
            base.to_s.split("\n").each do |line|
              locats += '  ' + line + "\n"
            end
          else
            msg = "Config: Empty INI file.\n"
            #locats += Rainbow(msg).aqua.bright
            locats += msg
          end
        else
          msg = "No config found for ‘#{scope}’.\n"
          if scope != :specified
            locats += Rainbow(msg).red.bright
          else
            locats += "Path: ‘#{scope}’ config does not exist.\n\n"
            locats += "Use --configfile to specify this config file.\n"
          end
        end
      end
      locats
    end

    # To capture curl calls when running rspec, write to a file.
    def init_curl_file
      if self['tool.curldebug'] && !self['tool.curlfile'].to_s.strip.empty?
        if @curlfile_f.nil?
          @curlfile_f = File.open(self['tool.curlfile'], 'a')
          # MEH: Call @curlfile_f.close() at some point? Or let Ruby do on exit.
          @curlfile_f << Time.now.to_s + "\n"
          @curlfile_f << "murano #{ARGV.join(' ')}\n"
          @curlfile_f.flush
        end
      elsif !@curlfile_f.nil?
        @curlfile_f.close
        @curlfile_f = nil
      end
    end
  end

  class ConfigError < StandardError
  end
end


# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

require 'erb'
require 'pathname'
require 'rainbow'
require 'MrMurano/verbosing'
require 'MrMurano/Account'
require 'MrMurano/Business'
require 'MrMurano/Config'
require 'MrMurano/Config-Migrate'
require 'MrMurano/ReCommander'
require 'MrMurano/Solution-Services'
require 'MrMurano/SyncRoot'
require 'MrMurano/commands/business'
require 'MrMurano/commands/solution'
require 'MrMurano/commands/sync'

def init_cmd_description
  %(

The init command helps you create a new Murano project
======================================================

Example
-------

  Create a new project in a new directory:

    #{MrMurano::EXE_NAME} init my-new-app

Example
-------

  Create a project in the current directory, or rewrite an existing project:

    cd project/path
    #{MrMurano::EXE_NAME} init

Solutions
---------

The init command configures two new Solutions for your new Murano project:

  1. An Application

     The Application is what users see.

     Use the Application to control, monitor, and consume values from products.

  2. A Product

     A Product is something that captures data and reports it to the Application.

     A Product can be a physical device connected to the Internet. It can be
     a simulator running on your local network. It can be anything that
     triggers events or supplies input data to the Application.

How it Works
------------

You will be asked to log on to your Business account.

  - To create a new Murano business account, visit:

    #{MrMurano::SIGN_UP_URL}

  - Once logged on, you can choose to store your logon token so you
    can skip this step when using Murano CLI.

After logon, name your Application, and then name your Product.

  - Please choose names that contain only lowercase letters and numbers.

    The names are used as variable names in scripts, and as domain names,
    so they cannot contain underscores, dashes, or other punctuation.

After creating the two Solutions, they will be linked.

  - Linking Solutions allows data and events to flow between the two.

    For example, a Product device generates data that will be consumed
    or processed by the Application.

The init command will pull down Product and Application services
that you can edit.

  - The services, or event handlers, let you control how data is
    processed and how your application behaves.

    Take a look at the new directories and files created in your
    Project after running init to see what services are available.

    There are many other resources that are not downloaded that
    you can also create and edit. Visit our docs site for more!

    http://docs.exosite.com/

  ).strip
end

command :init do |c|
  c.syntax = %(murano init)
  c.summary = %(The easy way to start a project)
  c.description = init_cmd_description

  c.example %(
    Initialize Murano project using specific Business and Solutions
  ).strip, 'murano init --business-id 12345 --product-name myprod --application-name myapp'

  # Let user specify existing business and/or solution IDs and/or names.
  cmd_option_business_pickers(c)
  cmd_option_application_pickers(c)
  cmd_option_product_pickers(c)

  c.option('--refresh', %(Ignore Business and Solution IDs found in the config))
  c.option('--purge', %(Remove Project directories and files, and recreate anew))
  c.option('--[no-]sync', %(Pull down existing remote files (generally a good thing) (default: true)))
  c.option('--[no-]mkdirs', %(Create default directories))

  # This command can be run without a project config.
  c.project_not_required = true
  # This command should not walk up the directory tree
  # looking for a .murano/config project config file.
  c.restrict_to_cur_dir = true
  # Ask for user password if not found.
  c.prompt_if_logged_off = true

  c.action do |args, options|
    c.verify_arg_count!(args, 1)
    options.default(refresh: false, purge: false, sync: true, mkdirs: true)

    acc = MrMurano::Account.instance
    validate_dir!(acc, args, options)

    puts('')
    if $cfg.project_exists
      verbage = 'Rebasing'
    else
      verbage = 'Creating'
    end
    say("#{verbage} project at #{Rainbow($cfg['location.base'].to_s).underline}")

    puts('')

    # Try to import a .Solutionfile.secret.
    # NOTE/2017-06-29: .Solutionfile.secret and SolutionFile (see ProjectFile.rb)
    # are old MurCLI constructs; here we just try to migrate from the old format
    # to the new format (where config goes in .murano/config and there's an
    # explicit directory structure; the user cannot specify a different file
    # hierarchy).
    MrMurano::ConfigMigrate.new.import_secret

    # See if the config already specifies a Business ID. If not, see if the
    # config contains a username and password; otherwise, ask for them. With
    # a username and password, get the list of businesses from Murano; if
    # just one found, use that; if more than one found, ask user which one
    # to use; else, if no businesses found, spit out the new-account URL
    # and tell the user to use their browser to create a new Business.
    unless $cfg['user.name'].to_s.empty?
      say("Found User #{Rainbow($cfg['user.name']).underline}")
      puts('')
    end

    # Find and verify Business by ID (from $cfg) or by name (from --business),
    # or ask user which business to use. If user has not logged on, they will
    # be asked for their username and/or password first.
    biz = business_find_or_ask!(acc, options)
    # Save the 'business.id' and 'business.name' to the project config.
    # ([lb] guessing biz guaranteed to be not nil, but checking anyway.)
    biz.write unless biz.nil?

    # Verify or ask user to create Solutions.
    sol_opts = {
      create_ok: true,
      update_cfg: true,
      ignore_cfg: options.refresh,
      verbose: true,
    }
    # Get/Create Application ID
    sol_opts[:match_api_id] = options.application_id
    sol_opts[:match_name] = options.application_name
    sol_opts[:match_fuzzy] = options.application
    appl = solution_find_or_create(biz: biz, type: :application, **sol_opts)
    # Get/Create Product ID
    sol_opts[:match_api_id] = options.product_id
    sol_opts[:match_name] = options.product_name
    sol_opts[:match_fuzzy] = options.product
    prod = solution_find_or_create(biz: biz, type: :product, **sol_opts)

    # Automatically link solutions.
    link_opts = { verbose: true }
    link_solutions(appl, prod, link_opts)

    # If no ProjectFile, then write a ProjectFile.
    write_project_file

    if options.mkdirs
      # Make the directory structure.
      make_directories(purge: options.purge)

      # For new solutions, Murano creates a few empty and example event handlers.
      # For existing solutions, the user might already have created some files.
      # Grab them now.
      syncdown_new_and_existing if options.sync
    end

    blather_success
  end

  def highlight_id(id)
    Rainbow(id).aliceblue.bright.underline
  end

  def validate_dir!(acc, args, options)
    # 2017-06-21: You can run init --dry and not have any files touched or
    # any Murano elements changed. But there's not much utility in that.
    # So maybe we should just not let users run a --dry init.
    #if $cfg['tool.dry']
    #  acc.error 'Cannot run a --dry init.'
    #  exit 2
    #end

    if args.count > 1
      acc.error('Please only specify 1 path')
      exit(2)
    end

    if args.empty?
      target_dir = Pathname.new(Dir.pwd)
    else
      target_dir = Pathname.new(args[0])
      unless Dir.exist?(target_dir.to_path)
        if target_dir.exist?
          acc.error("Target exists but is not a directory: #{target_dir.to_path}")
          exit 1
        end
        # FIXME/2017-07-02: Add test for this
        target_dir.mkpath
      end
      Dir.chdir target_dir
    end

    # The home directory already has its own .murano/ folder,
    # so we cannot create a project therein.
    if Pathname.new(Dir.pwd).realpath == Pathname.new(Dir.home).realpath
      acc.error('Cannot init a project in your HOME directory.')
      exit(2)
    end
    # Might as well block root path, too.
    if Pathname.new(Dir.pwd).realpath == File::SEPARATOR
      acc.error('Cannot init a project in your root directory.')
      exit(2)
    end

    # Only create a new project in an empty directory,
    # or a recognized Murano CLI project.
    unless $cfg.project_exists || options.refresh
      # Get a list of files, ignoring the dot meta entries.
      files = Dir.entries(target_dir.to_path)
      files -= %w[. ..]
      # If there are files (and it's not just .byebug_history which
      # gets created when you develop with byebug), then ask to proceed.
      unless files.empty? || (files.length == 1 && files[0] == '.byebug_history')
        # Check for a .murano/ directory. It might be empty, which
        # is why $cfg.project_exists might have been false.
        unless files.include?(MrMurano::Config::CFG_DIR_NAME)
          acc.warning 'The project directory contains unknown files.'
          confirmed = acc.ask_yes_no('Really init project? [y/N] ', false)
          unless confirmed
            acc.warning('abort!')
            exit 1
          end
        end
      end
    end

    target_dir
  end

  def write_project_file
    return if $project.using_projectfile
    tmpl = File.read(
      File.join(
        File.dirname(__FILE__), '..', 'template', 'projectFile.murano.erb'
      )
    )
    tmpl = ERB.new(tmpl)
    res = tmpl.result($project.data_binding)
    pr_file = $project['info.name'] + '.murano'
    say("Writing Project file to #{pr_file}")
    puts('')
    File.open(pr_file, 'w') { |io| io << res }
  end

  def make_directories(purge: false)
    base = $cfg['location.base']
    base = Pathname.new(base) unless base.is_a?(Pathname)
    num_locats = 0
    num_mkpaths = 0
    num_rmpaths = 0
    %w[
      location.files
      location.endpoints
      location.modules
      location.eventhandlers
      location.resources
    ].each do |cfgi|
      num_locats += 1
      n_mkdirs, n_rmdirs = make_directory(cfgi, base, purge)
      num_mkpaths += n_mkdirs
      num_rmpaths += n_rmdirs
    end
    if num_rmpaths > 0
      say('Removed existing directories')
      puts('')
    end
    if num_mkpaths > 0
      if num_mkpaths == num_locats
        say('Created default directories')
      else
        say('Created some default directories')
      end
    else
      say('Default directories already exist')
    end
    puts('')
  end

  def make_directory(cfgi, base, purge)
    path = $cfg[cfgi]
    path = Pathname.new(path) unless path.is_a?(Pathname)
    path = base + path
    # The path is generally a directory, but sometimes
    # it's a file (e.g., spec/resources.yaml).
    basedir = path
    basedir = basedir.dirname unless basedir.extname.empty?
    raise 'Unexpected: bad basedir' if basedir.to_s.empty? || basedir == File::SEPARATOR
    found_basedir = false
    basedir.ascend do |ancestor|
      if ancestor == base
        found_basedir = true
        break
      end
    end
    unless found_basedir
      say("Please fix your config: location.* values should be a subdir of location.base (#{base})")
      exit 1
    end
    dry = $cfg['tool.dry']
    num_rmdir = 0
    if purge
      MrMurano::Verbose.warning("--dry: Not purging existing directory: #{basedir}") if dry
      files = Dir.glob("#{basedir}/*")
      FileUtils.rm_rf(files, noop: dry)
      FileUtils.rmdir(basedir, noop: dry)
      MrMurano::Verbose.verbose("Removed #{basedir}")
      num_rmdir += 1
    end
    return 0, num_rmdir if path.exist?
    MrMurano::Verbose.warning("--dry: Not creating default directory: #{basedir}") if dry
    FileUtils.mkdir_p(basedir, noop: dry)
    FileUtils.touch(path, noop: dry) if path != basedir
    [1, num_rmdir]
  end

  def syncdown_new_and_existing
    # If the user already has an existing project, grab its files.
    #
    # If Murano creates any default eventhandlers, grab those
    # (e.g., the timer event, tsdb exportJob, and user account
    # are all created by the platform; and our own method,
    # link_solutions, creates a boilerplate event handler that
    # yeti-ui expects to find (you'll have issues in the web UI
    # if this script doesn't exist)).
    #
    # See:
    #   sphinx-api/src/views/interface/productService.swagger.json
    num_synced = syncdown_files(delete: false, create: true, update: false)
    if num_synced > 0
      inflection = MrMurano::Verbose.pluralize?('item', num_synced)
      say("Synced #{num_synced} #{inflection}")
    else
      say('Items already synced')
    end
    puts('')
  end

  def blather_success
    say('Success!')
    puts('')
    id_postfix = ' ID'
    important_ids = %w[business application product].freeze
    importantest_width = important_ids.map do |id_name|
      cfg_key = id_name + '.id'
      $cfg[cfg_key].length + id_postfix.length
    end.max # Max the map; get the length of the longest ID.
    important_ids.each do |id_name|
      # cfg_key is, e.g., 'business.id', 'product.id', 'application.id'
      cfg_key = id_name + '.id'
      next if $cfg[cfg_key].nil?
      #say "#{id_name.capitalize} ID: #{highlight_id($cfg[cfg_key])}"
      # Right-aligned:
      tmpl = format('%%%ds: %%s', importantest_width)
      # Left-aligned:
      #tmpl = format('%%-%ds: %%s', importantest_width)
      say(format(tmpl, id_name.capitalize + id_postfix, highlight_id($cfg[cfg_key])))
    end
    puts('')
  end
end

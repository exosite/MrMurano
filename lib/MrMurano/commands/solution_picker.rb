# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

require 'MrMurano/verbosing'
require 'MrMurano/Business'
require 'MrMurano/Config'
require 'MrMurano/Solution'

MSG_SOLUTIONS_NONE_FOUND = 'No solutions found' unless defined? MSG_SOLUTIONS_NONE_FOUND

# *** For some commands: let user restrict to specific solution --type.
# ---------------------------------------------------------------------

def cmd_add_solntype_pickers(c, exclude_all: false)
  # 2017-07-26: HA! The --type option can get masked by aliases.
  # For instance, if the option is required ("--type TYPE"), then
  #   murano domain --type product
  # fails, because the "domain product" alias steals the --type argument,
  # so the parser exits, complaining that --type is missing an argument!
  # This, however, works:
  #   murano domain --type=product
  # as does
  #   murano domain -t product
  # To work around this, make the argument optional ("--type [TYPE]") and
  # then do some extra processing later to check for this special case.
  allowed_types = MrMurano::Business::ALLOWED_TYPES.dup
  allowed_types += [:all] unless exclude_all
  allowed_types.map!(&:to_s).sort!
  default = exclude_all && 'application' || 'all'
  c.option(
    '--type [TYPE]',
    allowed_types,
    %(Apply to solution(s) of type [#{allowed_types.join('|')}] (default: #{default}))
  )
end

def cmd_defaults_solntype_pickers(options, default=:all)
  cmd_defaults_type_kludge(options)

  if options.type.to_s.empty?
    options.type = default.to_sym
  else
    options.type = options.type.to_sym
  end
end

def cmd_defaults_type_kludge(options)
  # KLUDGE/2017-07-26: Work around rb-commander peculiarity.
  # The alias_command steals the --type parameter, e.g.,
  #   murano domain --type product
  # is interpreted using the "domain product" alias,
  # so the command that's parsed is actually
  #   murano domain --type product --type
  # and the latter --type wins [which is something that [lb]
  # really dislikes about rb-commander, is that it does not
  # support more than one of the same options, taking only the
  # last one's argument].
  next_posit = 1
  ARGV.each do |arg|
    if arg.casecmp('--type').zero?
      if ARGV.length == next_posit
        MrMurano::Verbose.error('missing argument: --type')
        exit 1
      else
        # NOTE: Commander treats arguments case sensitively, but not --options.
        possible_type = ARGV[next_posit].to_sym
        if MrMurano::Business::ALLOWED_TYPES.include?(possible_type)
          options.type = possible_type
        else
          MrMurano::Verbose.error("unrecognized --type: #{possible_type}")
          exit 1
        end
        break
      end
    end
    next_posit += 1
  end
  return unless options.type == true
  MrMurano::Verbose.error('missing argument: --type')
  exit 1
end

# Get a list of solutions under the business.
# - Optionally filter by --type: in the command block, call
#   cmd_add_solntype_pickers, and then in the action block, call
#   cmd_defaults_solntype_pickers, and then call this method.
# - Optional restrict to just solutions in the current project.
def must_fetch_solutions!(options, args=[], biz=nil)
  solz = []

  if biz.nil?
    biz = MrMurano::Business.new
    biz.must_business_id!
  end
  if args.any?
    #raise 'Cannot use options.all and solution pickers' unless options.all.nil?
    flattened = args.map { |cell| cell.split(',') }.flatten
    api_id = []
    name = []
    fuzzy = []
    if options.id
      api_id = flattened
    elsif options.name
      name = flattened
    else
      fuzzy = flattened
    end
    solz += solution_get_solutions(
      biz, options.type, api_id: api_id, name: name, fuzzy: fuzzy
    )
  end

  if any_solution_pickers!(options)
    #raise 'Cannot use options.all and solution pickers' unless options.all.nil?
    #
    # MAYBE: DRY this code. Rather than copy-paste-find-replace block of code.
    #   See also: any_business_pickers?
    #
    api_id = []
    name = []
    fuzzy = []
    if options.application_id
      api_id = [options.application_id]
    elsif options.application_name
      name = [options.application_name]
    elsif options.application
      fuzzy = [options.application]
    end
    if !api_id.empty? || !name.empty? || !fuzzy.empty?
      solz += solution_get_solutions(
        biz, :application, api_id: api_id, name: name, fuzzy: fuzzy
      )
    end
    #
    api_id = []
    name = []
    fuzzy = []
    if options.product_id
      api_id = [options.product_id]
    elsif options.product_name
      name = [options.product_name]
    elsif options.product
      fuzzy = [options.product]
    end
    if !api_id.empty? || !name.empty? || !fuzzy.empty?
      solz += solution_get_solutions(
        biz, :product, api_id: api_id, name: name, fuzzy: fuzzy
      )
    end
    #
  end

  if args.none? && !any_solution_pickers!(options)
    if !options.all
      if %i[all application].include?(options.type) && $cfg['application.id']
        solz += solution_get_solutions(
          biz, :application, api_id: $cfg['application.id']
        )
      end
      if %i[all product].include?(options.type) && $cfg['product.id']
        solz += solution_get_solutions(
          biz, :product, api_id: $cfg['product.id']
        )
      end
    else
      solz += solution_get_solutions(biz, options.type)
    end
  end

  culled = {}
  solz.select! do |sol|
    if culled[sol.api_id]
      false
    else
      culled[sol.api_id] = true
      true
    end
  end

  if solz.empty?
    MrMurano::Verbose.error(MSG_SOLUTIONS_NONE_FOUND)
    exit 0
  end

  biz.sort_solutions!(solz)

  solz
end

# *** For murano init: specify --business, --application, and/or --product.
# -------------------------------------------------------------------------

def cmd_option_application_pickers(c)
  c.option('--application-id ID', String, %(ID of Application to use))
  c.option('--application-name NAME', String, %(Name of Application to use))
  c.option('--application APPLICATION', String, %(Name or ID of Application to use))
end

def cmd_option_product_pickers(c)
  c.option('--product-id ID', String, %(ID of Product to use))
  c.option('--product-name NAME', String, %(Name of Product to use))
  c.option('--product PRODUCT', String, %(Name or ID of Product to use))
end

def any_solution_pickers!(options)
  any_application_pickers!(options) || any_product_pickers!(options)
end

def any_application_pickers!(options)
  num_ways = 0
  num_ways += 1 unless options.application_id.to_s.empty?
  num_ways += 1 unless options.application_name.to_s.empty?
  num_ways += 1 unless options.application.to_s.empty?
  #if num_ways > 1
  #  MrMurano::Verbose.error(
  #    'Please specify only one of: --application, --application-id, or --application-name'
  #  )
  #  exit 1
  #end
  num_ways > 0
end

def any_product_pickers!(options)
  num_ways = 0
  num_ways += 1 unless options.product_id.to_s.empty?
  num_ways += 1 unless options.product_name.to_s.empty?
  num_ways += 1 unless options.product.to_s.empty?
  #if num_ways > 1
  #  MrMurano::Verbose.error(
  #    'Please specify only one of: --product, --product-id, or --product-name'
  #  )
  #  exit 1
  #end
  num_ways > 0
end

def solution_get_solutions(biz, type, api_id: nil, name: nil, fuzzy: nil)
  if type == :all
    inflection = 'solutions'
  else
    inflection = MrMurano::Verbose.pluralize?(type.to_s, 0)
  end
  MrMurano::Verbose.whirly_start("Fetching #{inflection}...")
  solz = biz.solutions(
    type: type, api_id: api_id, name: name, fuzzy: fuzzy, invalidate: false
  )
  MrMurano::Verbose.whirly_stop
  solz
end

def solution_ask_for_name(sol)
  asking = true
  while asking
    solname = ask("Please enter the #{sol.type_name} name: ")
    puts ''
    if solname == ''
      confirmed = ask("\nReally skip the #{sol.type_name}? [Y/n] ", true)
      if confirmed
        puts ''
        return '', '', false
      end
    else
      #unless sol.name.match(sol.name_validate_regex) { say ... }
      begin
        sol.set_name!(solname)
        break
      rescue MrMurano::ConfigError => _err
        say(sol.name_validate_help)
        # keep looping
      end
    end
  end
  sol.name
rescue EOFError
  # E.g., the user pressed Ctrl-D.
  #   "error: The input stream is exhausted."
  MrMurano::Verbose.error('murano out!')
  exit 2
end

# *** Interact with the user to identify the solution.
# ----------------------------------------------------

# For more on the ** doublesplat, and the **_ starsnake, see:
#  https://flushentitypacket.github.io/ruby/2015/03/31/ruby-keyword-arguments-the-double-splat-and-starsnake.html
# "Basically, _ is Ruby’s variable name for storing values you don’t need."
# Ruby 2.0 and above. I don't think we support 1.x...

def get_two_solutions!(sol_a_id=nil, sol_b_id=nil, **options)
  app_srchs = []
  prd_srchs = []

  #app_srchs += [[:application, :api_id, sol_a_id]] unless sol_a_id.to_s.empty?
  #prd_srchs += [[:product, :api_id, sol_b_id]] unless sol_b_id.to_s.empty?
  app_srchs += [[nil, :api_id, sol_a_id]] unless sol_a_id.to_s.empty?
  prd_srchs += [[nil, :api_id, sol_b_id]] unless sol_b_id.to_s.empty?

  app_srchs += get_soln_searches(:application, options)
  prd_srchs += get_soln_searches(:product, options)

  if app_srchs.length.zero? && prd_srchs.length < 2
    # TEST/2017-08-16: Clear application.id and test.
    app_srchs = [[:application, :api_id, $cfg['application.id']]]
  end
  if prd_srchs.length.zero? && app_srchs.length < 2
    # TEST/2017-08-16: Clear product.id and test.
    prd_srchs = [[:product, :api_id, $cfg['product.id']]]
  end

  sol_srchs = app_srchs + prd_srchs

  if sol_srchs.length > 2
    MrMurano::Verbose.error('too many solutions specified: specify 2 solutions')
    exit 1
  end

  biz = MrMurano::Business.new
  solz = []
  sol_srchs.each do |type, desc, value|
    sol_opts = {}
    case desc
    when :api_id
      sol_opts[:match_api_id] = value
    when :name
      sol_opts[:match_name] = value
    when :term
      sol_opts[:match_fuzzy] = value
    else
      raise false
    end
    sol = solution_find_or_create(**sol_opts, biz: biz, type: type)
    solz += [sol]
  end

  solz
end

def get_soln_searches(sol_type, options)
  sol_type = sol_type.to_sym
  sol_srchs = []
  # E.g., :application_id
  if options["#{sol_type}_id".to_sym]
    app_ids = options["#{sol_type}_id".to_sym].split(',')
    app_ids.each { |api_id| sol_srchs += [[sol_type, :api_id, api_id]] }
  end
  # E.g., :application_name
  if options["#{sol_type}_name".to_sym]
    app_names = options["#{sol_type}_name".to_sym].split(',')
    app_names.each { |name| sol_srchs += [[sol_type, :name, name]] }
  end
  # E.g., :application
  if options[sol_type]
    app_finds = options[sol_type].split(',')
    app_finds.each { |term| sol_srchs += [[sol_type, :term, term]] }
  end
  sol_srchs
end

def solution_find_or_create(biz: nil, type: nil, **options)
  type = options[:type] if type.nil?
  raise 'You mush specify the :type of solution' if type.nil? && options[:create_ok]
  options[:match_enable] = true if options[:match_enable].nil?
  finder = MrMurano::InteractiveSolutionFinder.new(options)
  model = biz.solution_from_type!(type)
  finder.find_or_create(model)
end

module MrMurano
  # A class for finding solutions, either automatically or interactively.
  class InteractiveSolutionFinder
    def initialize(
      skip_verify: false,
      create_ok: false,
      update_cfg: false,
      ignore_cfg: false,
      verbose: false,
      match_enable: false,
      match_api_id: nil,
      match_name: nil,
      match_fuzzy: nil
    )
      @skip_verify = skip_verify
      @create_ok = create_ok
      @update_cfg = update_cfg
      @ignore_cfg = ignore_cfg
      @verbose = verbose
      @match_enable = match_enable
      @match_api_id = match_api_id
      @match_name = match_name
      @match_fuzzy = match_fuzzy
      @match_api_id = nil if @match_api_id.to_s.empty?
      @match_name = nil if @match_name.to_s.empty?
      @match_fuzzy = nil if @match_fuzzy.to_s.empty?
      @searching = @match_enable && (@match_api_id || @match_name || @match_fuzzy)
    end

    def find_or_create(model)
      # First, try to find the solution by solution ID.
      sol = solution_find_by_api_id(model)
      # If not found, search existing solutions, and maybe ask user.
      if sol.nil?
        if @searching
          sol = solution_search_by_term(model)
          sol = solution_create_new_solution(model) if sol.nil? && @create_ok && @match_api_id.nil?
        else
          sol = solution_lookup_or_ask(model)
        end
      end
      # Finally, if asked, update the config.
      if @update_cfg && !sol.nil?
        # Update the config in memory and on disk/file.
        $cfg.set(sol.cfg_key_id, sol.api_id, :project)
        $cfg.set(sol.cfg_key_name, sol.name, :project)
      end
      sol
    end

    def solution_find_by_api_id(sol)
      exists = false
      if @searching || @ignore_cfg
        sol.api_id = @match_api_id || @match_fuzzy
      else
        # Note that we verify the solution ID we find in the config,
        # since the user could've, e.g., deleted it via the web UI.
        # LATER: This only works so long as there's only one Product
        #  or one Application. Eventually we'll add support for more.
        sol.api_id = $cfg[sol.cfg_key_id].to_s
        return sol if @skip_verify
      end
      if sol.api_id?
        tried_api_id = sol.api_id
        if @searching
          whirly_msg = "Searching #{sol.type_name} by ID..."
        else
          whirly_msg = "Verifying #{sol.type_name}..."
        end
        MrMurano::Verbose.whirly_start(whirly_msg)
        sol.info_safe
        if sol.valid_api_id
          exists = true
          # Convert from Solution to proper subclass, perhaps.
          sol = solution_factory_reset(sol)
        else
          sol.api_id = nil
        end
        MrMurano::Verbose.whirly_stop
        # Spit out some messages, maybe.
        if @verbose
          if exists
            say "Found #{sol.type_name} #{sol.pretty_desc}"
          elsif !@searching
            # The solution ID in the config was not found for this business.
            tried_api_id = MrMurano::Verbose.fancy_ticks(tried_api_id)
            say "The #{sol.type_name} ID #{tried_api_id} from the config was not found"
          end
          puts ''
        end
      end
      (exists && sol) || nil
    end

    def solution_lookup_or_ask(sol)
      solz = solution_get_solutions(sol.biz, sol.type)
      if solz.count == 1
        sol = solz.first
        #say "This business has one #{sol.type_name}. Using #{Rainbow(sol.domain).underline}"
        say "This business has one #{sol.type_name}. Using #{sol.pretty_desc}" if @verbose
        puts '' if @verbose
      elsif solz.count.zero?
        if @create_ok
          sol = solution_create_new_solution(sol)
        else
          sol.error("No #{Inflecto.pluralize(sol.type.to_s)} found")
          sol = nil
        end
      else
        sol = solution_choose_solution(solz, sol.type_name)
      end
      sol
    end

    def solution_create_new_solution(sol)
      # See if user specified name using a switch option.
      solname = nil
      solname = @match_name if solname.nil?
      solname = @match_fuzzy if solname.nil?
      if solname.nil?
        #say "You do not have any #{type}s. Let's create one."
        if @verbose
          say("This business does not have any #{Inflecto.pluralize(sol.type.to_s)}. Let's create one")
          puts ''
        end
        solution_ask_for_name(sol)
      else
        sol.set_name!(solname)
      end
      # MAYBE/2017-07-20: Detect if Business is ADC enabled. If not,
      # creating a solution fails, e.g.,
      #   Request Failed: 409: [409] upgrade
      sol = sol.biz.new_solution!(sol.name, sol.type) unless sol.name.to_s.empty?
      say "Created new #{sol.pretty_desc(add_type: true)}" if @verbose
      puts '' if @verbose
      sol
    end

    def solution_choose_solution(solz, type_name)
      sol = nil
      choose do |menu|
        menu.prompt = "Select which #{type_name} to use:"
        menu.flow = :columns_across
        # NOTE: There are 2 human friendly identifiers, :name and :domain.
        solz.sort_by(&:domain).each do |option|
          menu.choice(option.domain.sub(/\..*$/, '')) do
            sol = option
          end
        end
      end
      sol
    end

    def solution_search_by_term(sol)
      solz = solution_get_solutions(
        sol.biz, sol.type, api_id: @match_api_id, name: @match_name, fuzzy: @match_fuzzy
      )
      if solz.length > 1
        sol.error("More than one matching #{sol.type_name} found. Please be more specific")
        sol = nil
        # MAYBE/2017-07-01: Show interactive menu.
        # For now, if we didn't exit, weird behavior might occur, e.g., if
        # user calls `murano init --application foo` and 2 matches are found,
        # if we returned nil, the code would create a new application.
        exit 1
      elsif solz.length.zero?
        inflection = MrMurano::Verbose.pluralize?(sol.type_name, 0)
        # Only blather an error if we're not about to create a new solution.
        sol.error("No matching #{inflection} found.") unless @create_ok
        sol = nil
        # It's okay not to exit. If `murano init` was called, a new
        # solution will be created; otherwise, the command will exit.
      else
        sol = solz.first
        say "Found one matching #{sol.type_name}. Using #{sol.pretty_desc}" if @verbose
        puts '' if @verbose
      end
      sol
    end
  end
end


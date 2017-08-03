# Last Modified: 2017.07.26 /coding: utf-8
# frozen_string_literal: true

# Copyright © 2016-2017 Exosite LLC.
# License: MIT. See LICENSE.txt.
#  vim:tw=0:ts=2:sw=2:et:ai

global_option('-V', '--verbose', %(Be chatty)) do
  $cfg['tool.verbose'] = true
end

global_option('-n', '--dry', %(Don't run actions that make changes)) do
  $cfg['tool.dry'] = true
  # Running dry implies verbose.
  $cfg['tool.verbose'] = true
end

global_option('-L', '--curl', %(Print out a curl command for each network call)) do
  $cfg['tool.curldebug'] = true
end

global_option '--skip-plugins', %(Don't load plugins. Good for when one goes bad) do
  # no-op
end

global_option('-C', '--configfile FILE', %(Load additional configuration file)) do |file|
  # This is called after all of the top level code in this file.
  $cfg.load_specific(file)
end

global_option('-c', '--config KEY=VALUE', %(Set a single config key)) do |param|
  key, value = param.split('=', 2)
  # a=b :> ["a", "b"]
  # a= :> ["a", ""]
  # a :> ["a"]
  raise "Bad config '#{param}'" if key.nil?
  if value.nil?
    $cfg[key] = 'true'
  else
    $cfg[key] = value
  end
end

global_option('--[no-]color', %(Disable fancy output)) do |value|
  HighLine.use_color = value
  Rainbow.enabled = value
end

global_option('--[no-]progress', %(Disable spinner and progress message)) do |value|
  $cfg['tool.no-progress'] = !value
end

exclude_help = %(
Except config values from the specified scope(s).
        SCOPES can be 1 scope or comma-separated list of
        #{MrMurano::Config::CFG_SCOPES.map(&:to_s)}
).strip
global_option('--exclude-scopes SCOPES', Array, exclude_help) do |value|
  $cfg.exclude_scopes = value.map(&:to_sym)
end

# 2017-06-30: Being more flexible. And more consistent. Some commands
# just use the IDs found in config, but some commands allow the user
# to pass solution names or IDs as arguments to the command, and some
# commands should be able to work without being run from inside a project
# directory.

# The user can indicate the business, application, and product via command line.
# If not specified, we'll look in the config. Or, if the user is running the
# init command, we'll interact with the user.

global_option('--business BUSINESS', String, %(Name or ID of Murano Business to use)) do |business_mark|
  $cfg['business.id'] = nil
  $cfg['business.name'] = nil
  $cfg['business.mark'] = business_mark
end
global_option('--business-name NAME', String, %(Name of Murano Business to use)) do |business_name|
  $cfg['business.id'] = nil
  $cfg['business.name'] = business_name
  $cfg['business.mark'] = nil
end
global_option('--business-id ID', String, %(ID of Murano Business to use)) do |business_id|
  $cfg['business.id'] = business_id
  $cfg['business.name'] = nil
  $cfg['business.mark'] = nil
end

global_option('--application[=APPLICATION]', String, %(Name or ID of Application to use)) do |application_mark|
  # NOTE: If user does not specify an argument,
  #         e.g., `murano domain --application`,
  #       then this block *is not* called.
  $cfg['application.id'] = nil
  $cfg['application.name'] = nil
  $cfg['application.mark'] = application_mark
end
global_option('--application-name NAME', String, %(Name of Application to use)) do |application_name|
  $cfg['application.id'] = nil
  $cfg['application.name'] = application_name
  $cfg['application.mark'] = nil
end
global_option('--application-id ID', String, %(ID of Application to use)) do |application_id|
  $cfg['application.id'] = application_id
  $cfg['application.name'] = nil
  $cfg['application.mark'] = nil
end

global_option('--product[=PRODUCT]', String, %(Name or ID of Product to use)) do |product_mark|
  $cfg['product.id'] = nil
  $cfg['product.name'] = nil
  $cfg['product.mark'] = product_mark
end
global_option('--product-name NAME', String, %(Name of Product to use)) do |product_name|
  $cfg['product.id'] = nil
  $cfg['product.name'] = product_name
  $cfg['product.mark'] = nil
end
global_option('--product-id ID', String, %(ID of Product to use)) do |product_id|
  $cfg['product.id'] = product_id
  $cfg['product.name'] = nil
  $cfg['product.mark'] = nil
end


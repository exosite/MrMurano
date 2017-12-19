# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

require 'MrMurano/verbosing'
require 'MrMurano/Business'
require 'MrMurano/ReCommander'
require 'MrMurano/Solution'

command :show do |c|
  c.syntax = %(murano show)
  c.summary = %(Show readable information about the current configuration)
  c.description = %(
Show readable information about the current configuration.
  ).strip
  c.project_not_required = true

  c.option '--[no-]ids', 'Show IDs'

  c.action do |args, options|
    c.verify_arg_count!(args)

    acc = MrMurano::Account.instance
    biz = MrMurano::Business.new

    selected_business = nil
    selected_business_id = $cfg['business.id']
    unless selected_business_id.to_s.empty?
      acc.businesses.each do |sol|
        selected_business = sol if sol.bizid == selected_business_id
      end
    end

    selected_application = nil
    selected_application_id = $cfg['application.id']
    unless selected_application_id.to_s.empty?
      MrMurano::Verbose.whirly_start('Fetching Applications...')
      biz.applications.each do |sol|
        next unless sol.api_id == selected_application_id
        #next unless [sol.api_id, sol.sid].include?(selected_application_id)
        selected_application = sol
        break
      end
      MrMurano::Verbose.whirly_stop
    end

    selected_product = nil
    selected_product_id = $cfg['product.id']
    unless selected_product_id.to_s.empty?
      MrMurano::Verbose.whirly_start('Fetching Products...')
      biz.products.each do |sol|
        next unless sol.api_id == selected_product_id
        #next unless [sol.api_id, sol.sid].include?(selected_product_id)
        selected_product = sol
        break
      end
      MrMurano::Verbose.whirly_stop
    end

    if $cfg['user.name']
      puts %(user: #{$cfg['user.name']})
    else
      puts 'no user selected'
    end

    if selected_business
      biz_info = %(business: #{selected_business.name})
      biz_info += %( <#{selected_business.bid}>) if options.ids
      puts biz_info
    else
      #puts 'no business selected'
      MrMurano::Verbose.error MrMurano::Business.missing_business_id_msg
    end

    id_not_in_biz = false

    # E.g., {:bizid=>"ABC", :type=>"application", :api_id=>"XXX", :sid=>"XXX",
    #        :name=>"ABC", :domain=>"ABC.apps.exosite.io" }
    if selected_application
      sol_info = %(application: https://#{selected_application.domain})
      sol_info += %( <#{selected_application.api_id}>) if options.ids
      puts sol_info
    elsif selected_application_id
      #puts 'selected application not in business'
      puts "application ID from config is not in business (#{selected_application_id})"
      id_not_in_biz = true
    elsif !selected_business
      puts 'application ID depends on business ID'
    else
      #puts 'no application selected'
      puts 'application ID not found in config'
    end

    # E.g., {:bizid=>"ABC", :type=>"product", :api_id=>"XXX", :sid=>"XXX",
    #        :name=>"ABC", :domain=>"ABC.m2.exosite.io" }
    if selected_product
      sol_info = %(product: #{selected_product.name})
      sol_info += %( <#{selected_product.api_id}>) if options.ids
      puts sol_info
    elsif selected_product_id
      #puts 'selected product not in business'
      puts "product ID from config is not in business (#{selected_product_id})"
      id_not_in_biz = true
    elsif !selected_business
      puts 'product ID depends on business ID'
    else
      #puts 'no product selected'
      puts 'product ID not found in config'
    end

    MrMurano::SolutionBase.warn_configfile_env_maybe if id_not_in_biz
  end
end

command 'show location' do |c|
  c.syntax = %(murano show location)
  c.summary = %(Show readable location information)
  c.description = %(
Show readable information about the current configuration.
  ).strip
  c.project_not_required = true

  c.action do |args, _options|
    c.verify_arg_count!(args)
    puts %(base: #{$cfg['location.base']})
    $cfg['location'].each { |key, value| puts %(#{key}: #{$cfg['location.base']}/#{value}) }
  end
end


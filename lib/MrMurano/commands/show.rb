# Last Modified: 2017.08.02 /coding: utf-8
# frozen_string_literal: true

# Copyright © 2016-2017 Exosite LLC.
# License: MIT. See LICENSE.txt.
#  vim:tw=0:ts=2:sw=2:et:ai

require 'MrMurano/Business'
require 'MrMurano/verbosing'

command 'show' do |c|
  c.syntax = %(murano show)
  c.summary = %(Show readable information about the current configuration)
  c.description = %(
Show readable information about the current configuration.
  ).strip
  c.project_not_required = true

  c.action do |args, _options|
    if args.include?('help')
      ::Commander::UI.enable_paging
      say MrMurano::SubCmdGroupHelp.new(c).get_help
    else
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
          selected_application = sol if sol.apiId == selected_application_id
        end
        MrMurano::Verbose.whirly_stop
      end

      selected_product = nil
      selected_product_id = $cfg['product.id']
      unless selected_product_id.to_s.empty?
        MrMurano::Verbose.whirly_start('Fetching Products...')
        biz.products.each do |sol|
          selected_product = sol if sol.apiId == selected_product_id
        end
        MrMurano::Verbose.whirly_stop
      end

      if $cfg['user.name']
        puts %(user: #{$cfg['user.name']})
      else
        puts 'no user selected'
      end

      if selected_business
        puts %(business: #{selected_business.name})
      else
        #puts 'no business selected'
        MrMurano::Verbose.error MrMurano::Business.missing_business_id_msg
      end

      # E.g., {:bizid=>"AAAAAAAAAAAAAAAA", :type=>"application",
      #   :apiId=>"CCCCCCCCCCCCCCCCC", :sid=>"CCCCCCCCCCCCCCCCC",
      #   :domain=>"AAAAAAAAAAAAAAAA.apps.exosite.io", :name=>"AAAAAAAAAAAAAAAA"}
      if selected_application
        puts %(application: https://#{selected_application.domain})
      elsif selected_application_id
        #puts 'selected application not in business'
        puts "application ID from config is not in business (#{selected_application_id})"
      elsif !selected_business
        puts 'application ID depends on business ID'
      else
        #puts 'no application selected'
        puts 'application ID not found in config'
      end

      # E.g., {:bizid=>"AAAAAAAAAAAAAAAA", :type=>"product",
      #   :apiId=>"BBBBBBBBBBBBBBBBB", :sid=>"BBBBBBBBBBBBBBBBB",
      #   :domain=>"BBBBBBBBBBBBBBBBB.m2.exosite.io", :name=>"AAAAAAAAAAAAAAAA"}
      if selected_product
        puts %(product: #{selected_product.name})
      elsif selected_product_id
        #puts 'selected product not in business'
        puts "product ID from config is not in business (#{selected_product_id})"
      elsif !selected_business
        puts 'product ID depends on business ID'
      else
        #puts 'no product selected'
        puts 'product ID not found in config'
      end
    end
  end
end

command 'show location' do |c|
  c.syntax = %(murano show location)
  c.summary = %(Show readable location information)
  c.description = %(
Show readable information about the current configuration.
  ).strip
  c.project_not_required = true

  c.action do |_args, _options|
    puts %(base: #{$cfg['location.base']})
    $cfg['location'].each { |key, value| puts %(#{key}: #{$cfg['location.base']}/#{value}) }
  end
end


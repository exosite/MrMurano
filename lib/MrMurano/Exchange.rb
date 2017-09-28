# Last Modified: 2017.09.27 /coding: utf-8
# frozen_string_literal: true

# Copyright © 2016-2017 Exosite LLC.
# License: MIT. See LICENSE.txt.
#  vim:tw=0:ts=2:sw=2:et:ai

require 'MrMurano/Exchange-Element'

module MrMurano
  # The Exchange class represents an end user's Murano IoT Exchange Elements.
  class Exchange < Business
    include Http
    include Verbose

    def get(path='', query=nil, &block)
      super
    end

    def element(element_id)
      ret = get('exchange/' + bid + '/element/' + element_id)
      return nil unless ret.is_a?(Hash) && !ret.key?(:error)
      ret
    end

    def fetch_type(part)
      # [lb] not super happy about mixing presentation with other logic
      # but this is quick and dirty.
      case part
      when '/element/'
        qualifier = 'All'
      when '/purchase/'
        qualifier = 'Purchased'
      else
        raise 'Unexpected error'
      end
      whirly_start("Fetching #{qualifier} Elements...")

      # FIXME/2017-09-27: Support Pagination. BizAPI accepts four settings:
      #                     type, offset, limit, and select.
      #                   <bizapi>/lib/api/route/exchange/schemas/element.js
      ret = get('exchange/' + bid + part) do |request, http|
        response = http.request(request)
        case response
        when Net::HTTPSuccess
          workit_response(response)
        else
          showHttpError(request, response)
        end
      end
      whirly_stop
      return [] unless ret.is_a?(Hash) && !ret.key?(:error)
      return [] unless ret.key?(:items)
      unless ret[:count] == ret[:items].length
        warning(
          'Unexpected: ret[:count] != ret[:items].length: ' \
          "#{ret[:count]} != #{ret[:items].length}"
        )
      end
      ret[:items]
    end

    def elements(**opts)
      lookp = {}
      # Get the user's Business metadata, including their Business tier.
      overview if @ometa.nil?
      elems = fetch_elements(lookp)
      fetch_purchased(lookp)
      prepare_elements(elems, **opts)
    end

    def fetch_elements(lookp)
      # Fetch the list of Elements, including Added, Available, and Upgradeable.
      items = fetch_type('/element/')
      # Prepare a lookup of the Elements.
      items.map do |meta|
        elem = MrMurano::ExchangeElement.new(meta)
        lookp[elem.elementId] = elem
        elem
      end
    end

    def fetch_purchased(lookp)
      # Fetch the list of Purchased elements.
      items = fetch_type('/purchase/')
      # Update the list of all Elements to indicate which have been purchased.
      items.each do |meta|
        elem = lookp[meta[:elementId]]
        if !elem.nil?
          elem.purchaseId = meta[:purchaseId]
          # Sanity check.
          meta[:element].each do |key, val|
            next if verify_purchase_vs_element(elem, key, val)
            verbose(
              'Unexpected: Exchange Purchase element meta differs: ' \
              "key: #{key} / elem: #{elem.send(key)} / purchase: #{val}"
            )
          end
        else
          warning("Unexpected: No Element found for Exchange Purchase: elementId: #{meta[:elementId]}")
        end
      end
    end

    def verify_purchase_vs_element(elem, key, val)
      elem.send(key) == val
    rescue NoMethodError
      verbose("Unexpected: Exchange Element missing key found in Purchase Element: #{key}")
      true
    end

    def prepare_elements(elems, filter_id: nil, filter_name: nil, filter_fuzzy: nil)
      if filter_id || filter_name || filter_fuzzy
        elems.select! do |elem|
          if (
            (filter_id && elem.elementId == filter_id) || \
            (filter_name && elem.name == filter_name) || \
            (filter_fuzzy &&
              (
                elem.elementId =~ /#{Regexp.escape(filter_fuzzy)}/i || \
                elem.name =~ /#{Regexp.escape(filter_fuzzy)}/i
              )
            )
          )
            true
          else
            false
          end
        end
      end

      available = []
      purchased = []
      elems.sort_by(&:name)
      elems.each do |elem|
        if elem.purchaseId.nil?
          available.push(elem)
          if !@ometa[:tier].nil? && elem.tiers.include?(@ometa[:tier][:id])
            elem.statusable = :available
          else
            elem.statusable = :upgrade
          end
        else
          purchased.push(elem)
          elem.statusable = :added
        end
        #@ometa[:status] = elem.status
      end

      [elems, available, purchased]
    end

    def purchase(element_id)
      whirly_start('Purchasing Element...')
      ret = post(
        'exchange/' + bid + '/purchase/',
        elementId: element_id,
      )
      # Returns, e.g.,
      #  { bizid: "XXX", elementId: "YYY", purchaseId: "ZZZ" }
      whirly_stop
      ret
    end
  end
end


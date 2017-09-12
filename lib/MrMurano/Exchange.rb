# Last Modified: 2017.08.31 /coding: utf-8
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
      whirly_start('Fetching Elements...')
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
      # Fetch the list of Elements, including Added, Available, and Upgradeable.
      items = fetch_type('/element/')
      # Prepare a lookup of the Elements.
      elems = items.map do |meta|
        elem = MrMurano::ExchangeElement.new(meta)
        lookp[elem.elementId] = elem
        elem
      end
      # Fetch the list of Purchased elements.
      items = fetch_type('/purchase/')
      # Update the list of all Elements to indicate which have been purchased.
      items.each do |meta|
        elem = lookp[meta[:elementId]]
        if !elem.nil?
          elem.purchaseId = meta[:purchaseId]
          # Sanity check.
          meta[:element].each do |key, val|
            next if elem.send(key) == val
            warning(
              'Unexpected: Exchange Purchase element meta differs: ' \
              "key: #{key} / elem: #{elem.send(key)} / purchase: #{val}"
            )
          end
        else
          warning("Unexpected: No Element found for Exchange Purchase: elementId: #{meta[:elementId]}")
        end
      end
      prepare_elements(elems, **opts)
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


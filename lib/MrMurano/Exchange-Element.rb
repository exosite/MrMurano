# Last Modified: 2017.09.27 /coding: utf-8
# frozen_string_literal: true

# Copyright © 2016-2017 Exosite LLC.
# License: MIT. See LICENSE.txt.
#  vim:tw=0:ts=2:sw=2:et:ai

module MrMurano
  class ExchangeElement
    include HashInit

    # *** BizAPI members.

    # These members are a copy of and ordered according to
    # (the moving target known as) BizAPI. See:
    #
    #   <bizapi>/lib/api/route/exchange/schemas/element.js::elementWithoutId
    #
    # But really what's returned is what's in the Mongo store, ha!

    # The Exchange Element's Element ID.
    # [lb] tempted to say :element_id, but keep it matchy, in spite of #linter.
    attr_accessor :elementId

    # The Exchange Element's Business ID context.
    attr_accessor :bizid

    # The type is one of: download | product | application | contactSales
    #   though BizAPI 'list' command also accepts: service
    attr_accessor :type

    # The friendly, descriptive name of the Exchange Element.
    attr_accessor :name

    # The image associated with the Exchange Element; not used by the CLI.
    attr_accessor :image
    # Contains ancestors:
    #   :thumbnail
    #     :url
    #     :filename
    #     :color
    #     :type
    #     :size
    #   :detail
    #     :url
    #     :filename
    #     :color
    #     :type
    #     :size

    # The short description describing the Exchange Element.
    attr_accessor :description

    # The long description describing the Exchange Element.
    attr_accessor :markdown

    # The source associated with the Exchange Element; not currently used.
    attr_accessor :source
    # Contains ancestors:
    #   :from
    #     - One of: service | github | attachment | url
    #   :name
    #   :url
    #   :token

    # Array of tags used to describe the Exchange Element.
    attr_accessor :tags

    # The attachment associated with 'attachment' sources; not currently used.
    attr_accessor :attachment
    # Contains ancestors:
    #   :download
    #     :url
    #     :filename
    #     :type
    #     :size

    # The contact the user wrote for with the Exchange Element; not currently used.
    attr_accessor :contact

    # The specs the user wrote for the Exchange Element; not currently used.
    attr_accessor :specs

    # The active value is boolean; not currently used.
    attr_accessor :active

    # The access associated with the Exchange Element; not currently used.
    #   One of: public | private | network.
    attr_accessor :access

    # "approval" is not really documented. Code shows values: pending | approved.
    attr_accessor :approval

    # *** Values returned from BizAPI but defined specially.

    # The Purchase ID is nil unless the user has added/purchased this element.
    attr_accessor :purchaseId
    #attr_accessor :purchase_id

    # The <bizId>/exchange/ endpoint returns a list of flat dictionaries.
    # The <bizId>/purchase/ endpoint, on the other hand, puts the remaining
    #   items in an object under an "element" key.

    # FIXME/EXPLAIN: Is this what the Lua code calls the service?
    attr_accessor :apiServiceName

    # The Murano business tiers to which this element applies.
    # Zero or more of: ["free", "developer", "professional", "enterprise"]
    # NOTE: The 'tiers' values appears to be returned directly from Mongo DB.
    #   Specifically, BizAPI sets tiers = [] on new elements, but for global
    #   elements (in bootstrap/db/element.json), tiers is non-empty. [lb]
    attr_accessor :tiers

    # Actions associated with the Exchange Element.
    attr_accessor :actions
    # The actions is an array with one dict element with:
    #  'url', 'type' (e.g., 'download), and 'primary' (bool).

    # *** Internal Murano CLI variables (i.e., not in BizAPI).

    # The meta is the Hash of the Exchange Element returned from the platform.
    attr_reader :meta

    # Based on purchaseId and tiers, state of Element in Business. One of:
    #   :available | :upgrade | :added
    attr_accessor :statusable

    ELEM_KEY_TRANSLATE = {
      #type: :action_type,
      #elementId: :element_id,
    }.freeze

    def initialize(*hash)
      @show_errors = $cfg['tool.verbose']
      hash = [hash] unless hash.is_a? Array
      camel_cased = {}
      hash.first.each do |key, val|
        if ELEM_KEY_TRANSLATE[key].nil?
          camel_cased[key] = val
        else
          camel_cased[ELEM_KEY_TRANSLATE[key]] = val
        end
      end
      super camel_cased
      @meta = hash.first
      #@meta = camel_cased
    end

    def status
      case statusable
      when :available
        'available'
      when :upgrade
        'available*'
      when :added
        'added'
      else
        statusable.to_s
      end
    end
  end
end


# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

require 'MrMurano/Solution-ServiceConfig'

module MrMurano
  class Keystore < ServiceConfig
    def initialize(api_id=nil)
      # FIXME/2017-07-03: Do products have a keystore service? What about other soln types?
      @solntype = 'application.id'
      super
      @service_name = 'keystore'
    end

    def keyinfo
      call(:info)
    end

    def listkeys
      ret = call(:list)
      ret[:keys]
    end

    def getkey(key)
      ret = call(:get, :post, key: key)
      ret[:value]
    end

    def setkey(key, value)
      call(:set, :post, key: key, value: value)
    end

    def delkey(key)
      call(:delete, :post, key: key)
    end

    def command(key, cmd, args)
      call(:command, :post, key: key, command: cmd, args: args)
    end

    def clearall
      call(:clear, :post, {})
    end
  end
end


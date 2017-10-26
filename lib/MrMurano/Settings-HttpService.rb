# frozen_string_literal: true

require 'MrMurano/Solution-ServiceConfig'
require 'json'

module MrMurano
  module Httpservice
    class Base < ServiceConfig
      def initialize(api_id=nil)
        @solntype = 'application.id'
        super
        @uriparts << :http
      end

      def info
        get
      end
    end

    # For things on ServiceConfig, they always have a parameters…
    class Settings < Base
      def credentials
        ret = get
        astr = ((ret[:parameters] || {})[:credentials]) || ''
        JSON.parse(astr, json_opts)
      end

      def credentials=(x)
        raise 'Not Hash' unless x.is_a? Hash
        put(
          '',
          parameters: {
            credentials: x.to_json,
          }
        )
      end
    end
  end
end

#  vim: set ai et sw=2 ts=2 :

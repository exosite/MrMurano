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

    class Settings < Base
      def credentials
        ret = get
        astr = (ret[:parameters] or {})[:credentials] or ''
        JSON.parse(astr, json_opts)
      end
      def credentials=(x)
        raise 'Not Hash' unless x.is_a? Hash
        put('', {
          :solution_id => '',
          :service => 'http',
          :parameters => {
            :credentials => x.to_json
          }
        })
      end

    end
  end
end

#  vim: set ai et sw=2 ts=2 :

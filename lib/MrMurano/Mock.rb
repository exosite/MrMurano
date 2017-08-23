# Last Modified: 2017.08.20 /coding: utf-8
# frozen_string_literal: true

# Copyright © 2016-2017 Exosite LLC.
# License: MIT. See LICENSE.txt.
#  vim:tw=0:ts=2:sw=2:et:ai

require 'erb'
require 'securerandom'

module MrMurano
  class Mock
    attr_accessor :uuid, :testpoint_file

    def initialize
    end

    def show
      file = Pathname.new(testpoint_path)
      if file.exist?
        authorization = %(if request.headers["authorization"] == ")
        file.open('rb') do |io|
          io.each_line do |line|
            auth_line = line.include?(authorization)
            if auth_line
              capture = /\=\= "(.*)"/.match(line)
              return capture.captures[0]
            end
          end
        end
      end
      false
    end

    def mock_template
      path = mock_template_path
      ::File.read(path)
    end

    def testpoint_path
      file_name = 'testpoint.post.lua'
      path = %(#{$cfg['location.endpoints']}/#{file_name})
      path
    end

    def mock_template_path
      ::File.join(::File.dirname(__FILE__), 'template', 'mock.erb')
    end

    def create_testpoint
      uuid = SecureRandom.uuid
      template = ERB.new(mock_template)
      endpoint = template.result(binding)

      Pathname.new(testpoint_path).open('wb') do |io|
        io << endpoint
      end
      uuid
    end

    def remove_testpoint
      file = Pathname.new(testpoint_path)
      if file.exist?
        file.unlink
        return true
      end
      false
    end
  end
end


# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

require 'fileutils'
require 'pathname'
require 'yaml'
require 'MrMurano/verbosing'
require 'MrMurano/Account'
require 'MrMurano/Config'

module MrMurano
  class ConfigMigrate
    include Verbose

    def import_secret
      solsecret = Pathname.new($cfg['location.base']) + '.Solutionfile.secret'
      return unless solsecret.exist?
      # Is in JSON, which as a subset of YAML, so use YAML parser
      solsecret.open do |io|
        ss = YAML.load(io)

        pff = $cfg.file_at('passwords', :user)
        pwd = MrMurano::Passwords.new(pff)
        pwd.load
        ps = pwd.get($cfg['net.host'], ss['email'])
        if ps.nil?
          pwd.set($cfg['net.host'], ss['email'], ss['password'])
          pwd.save
        elsif ps != ss['password']
          y = ask('A different password for this account already exists. Overwrite? N/y')
          if y =~ /^y/i
            pwd.set($cfg['net.host'], ss['email'], ss['password'])
            pwd.save
          end
        # else, already set, nothing to do.
        end

        $cfg.set('user.name', ss['email'])
        $project.refresh_user_name

        $cfg.set('application.id', ss['solution_id']) if ss.key? 'solution_id'
        $cfg.set('product.id', ss['product_id']) if ss.key? 'product_id'
      end
    end
  end
end


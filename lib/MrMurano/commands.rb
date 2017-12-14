# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

# DEVs: If you want to generate a completion file, uncomment this.
#   Then run, from the base of the project, e.g.,
#     rake install:user
#     murano completion > docs/completions/murano_completion-bash
#require 'MrMurano/commands/completion'

require 'MrMurano/commands/business'
require 'MrMurano/commands/config'
require 'MrMurano/commands/content'
require 'MrMurano/commands/cors'
require 'MrMurano/commands/devices'
require 'MrMurano/commands/domain'
require 'MrMurano/commands/exchange'
require 'MrMurano/commands/globals'
require 'MrMurano/commands/keystore'
require 'MrMurano/commands/init'
require 'MrMurano/commands/link'
require 'MrMurano/commands/login'
require 'MrMurano/commands/logs'
require 'MrMurano/commands/mock'
require 'MrMurano/commands/postgresql'
require 'MrMurano/commands/password'
require 'MrMurano/commands/settings'
require 'MrMurano/commands/show'
require 'MrMurano/commands/solution'
require 'MrMurano/commands/status'
require 'MrMurano/commands/sync'
require 'MrMurano/commands/tsdb'
require 'MrMurano/commands/usage'


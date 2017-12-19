# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

# 2017-07-01: This ordered list hacks around having
# individual files include all the files they need.

require 'MrMurano/version'

require 'MrMurano/hash'
require 'MrMurano/http'
require 'MrMurano/makePretty'
#require 'MrMurano/optparse'
require 'MrMurano/progress'
require 'MrMurano/verbosing'

require 'MrMurano/Config'
require 'MrMurano/Config-Migrate'
require 'MrMurano/ProjectFile'

require 'MrMurano/Account'
require 'MrMurano/Business'
require 'MrMurano/Exchange'
require 'MrMurano/Exchange-Element'
require 'MrMurano/Passwords'

require 'MrMurano/Content'
require 'MrMurano/Gateway'
require 'MrMurano/Keystore'
require 'MrMurano/Logs'
require 'MrMurano/Mock'
require 'MrMurano/Setting'
require 'MrMurano/Settings-HttpService'
require 'MrMurano/SolutionId'
require 'MrMurano/Solution'
require 'MrMurano/Solution-Services'
require 'MrMurano/Solution-ServiceConfig'
require 'MrMurano/Solution-Users'
require 'MrMurano/Webservice'
require 'MrMurano/Webservice-Cors'
require 'MrMurano/Webservice-Endpoint'
require 'MrMurano/Webservice-File'

require 'MrMurano/SyncAllowed'
require 'MrMurano/SyncRoot'
require 'MrMurano/SyncUpDown'
require 'MrMurano/SyncUpDown-Core'
require 'MrMurano/SyncUpDown-Item'

require 'MrMurano/SubCmdGroupContext'
require 'MrMurano/ReCommander'
require 'MrMurano/commands'

# LATER/2017-09-12: See MRMUR-160 and MRMUR-161:
#   Windows build fails unless `rake` is packaged.
require 'rake'


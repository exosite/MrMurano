# Last Modified: 2017.09.28 /coding: utf-8
# frozen_string_literal: true

# Copyright © 2016-2017 Exosite LLC.
# License: MIT. See LICENSE.txt.
#  vim:tw=0:ts=2:sw=2:et:ai

module MrMurano
  # USAGE: Use 'beta.' and 'pre.' to label beta releases and dev builds.
  #   For example, the first beta for a 3.0.0 release would be:
  #     3.0.0.beta.1
  #   After the beta release, developers would want to use a pre-build:
  #     3.0.0.beta.2.pre.1
  #   And then the next beta release drops the 'pre'-postfix:
  #     3.0.0.beta.2
  #   And finally the general release drops the 'beta'-postfix:
  #     3.0.0
  #   This works because of how versions are ordered, e.g.,
  #     3.0.0.beta.1 < 3.0.0.beta.2.pre.1 < 3.0.0.beta.2 < 3.0.0
  #
  #   Note that we cannot follow the Semantic Version guidelines
  #   from http://semver.org/. The guidelines say to use a dash to
  #   separate the pre-release version, and a plus to separate the
  #   build metadata, e.g., '3.0.0-beta.2+1'. However, the `rake build`
  #   task replaces a dash in the version with the text, 'pre.', e.g.,
  #     '3.0.0-beta.2' is changed to '3.0.0.pre.beta.2'
  #   which breaks our build (which expects the version to match herein).
  #   So stick to using the '.pre.X' syntax, which ruby/gems knows.
  VERSION = '3.0.5'
  EXE_NAME = File.basename($PROGRAM_NAME)
  SIGN_UP_URL = 'https://exosite.com/signup/'
end


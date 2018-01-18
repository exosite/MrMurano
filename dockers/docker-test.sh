#!/bin/bash

# This script is called by the Jenkins Build step Execute Shell command,
# via `docker exec`.
#
# This script is run in a Docker container as user 'jenkins'. If Dockerfile
# did not set up the user first, you'd permissions issues, and you'd see
# weird behavior, such as:
#
#   $ whoami
#   sudo: unknown uid 1001: who are you?
#   $ sudo whoami
#   whoami: cannot find name for user ID 1001
#   whoami:
#   $ echo ${USER}
#   jenkins
#   $ users
#   $ groups
#   cannot find name for group ID 1001
#   1001
#
# To work around this, the Dockerfile calls `useradd ... jenkins`,
# and the Jenkins Build Environment "User group" is set to 'root'.
# (This

# Jenkins runs the Build step Execute Shell command from the
# ${WORKSPACE} directory, e.g.,
#
#   /tmp/jenkins-ff750fb5/workspace/MuranoCLI/MrMurano Tests
#
# which is actually outside the Docker container (on the host).
#
# We use the advanced Docker option, Volumes, to wire our container to
# the host. Specifically, Dockerfile wires /app/report and /app/coverage
# to ${WORKSPACE}/report and ${WORKSPACE}/coverage, respectively.

# The Dockerfile uses ENV to change the encoding from ASCII, which
# we cannot do from within the container. You should see UTF-8.
#
#   $ echo ${LANG}
#   en_US.UTF-8

# Jenkins sets a few environs, like ${WORKSPACE}, and we pull in a few
# more from the Jenkins Environment Injector Plugin.

[[ -z ${WORKSPACE} ]] && echo "ERROR: Expected WORKSPACE to be set" && exit 1

export MURANO_USERNAME="${LANDON_USERNAME}"
export MURANO_PASSWORD="${LANDON_PASSWORD}"

[[ -z ${MURANO_USERNAME} ]] && echo "ERROR: Please set MURANO_USERNAME" && exit 1
[[ -z ${MURANO_PASSWORD} ]] && echo "ERROR: Please set MURANO_PASSWORD" && exit 1

# Create a basic Murano CLI config indicating the Murano account credentials.

cat > "${WORKSPACE}/test.run.muranocfg" <<-EOCFB
[user]
  name = landonbouma+jenkins-nix@exosite.com
[business]
  id = hd7opcgbyjfqd7vi
[net]
  host = bizapi.hosted.exosite.io
EOCFB
export MURANO_CONFIGFILE="${WORKSPACE}/test.run.muranocfg"

# Switch to the project directory and run tests.

cd /app

# Instead of `rake test_clean_up -t`, call CLI with additional --options.

echo "Removing existing solutions from Murano account."

ruby -Ilib bin/murano solutions expunge -y --no-progress --no-color --ascii

# Fix the PATH to avoid the error:
#
#   /tmp/jenkins8459777890102160498.sh: line 81: rspec: command not found
PATH=${PATH}:/usr/local/bundle/bin

# The host drive directories are mounted as root:root with 2755 permissions.
# Fix this, lest the tests bomb on Errno::EACCES: Permission denied. Note
# that Dockerfile gave the 'jenkins' user auto-sudo on the chmod command.
chmod 2777 /app/report
chmod 2777 /app/coverage

echo "#####################################################################"
echo "Testing \"$(murano -v)\" on \"$(ruby -v)\""
echo "#####################################################################"

/bin/ls -la /app
/bin/ls -la /app/report
/bin/ls -la /app/coverage

# Hint: Add --example "<...>" to limit the test suite.

rspec \
  --format html \
  --out /app/report/index-${RVERS}.html \
  --format documentation

#rspec --format html --out /app/report/index-${RVERS}.html --format documentation --example 'murano link with project unlinks'


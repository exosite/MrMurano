#!/bin/bash
# Last Modified: 2017.08.02
# vim:tw=0:ts=2:sw=2:et:norl:spell

# WHAT: A Continuous Integration (CI) script for kicking the build
#       whenever a ruby file within the project is saved.
#
#       It's Async-safe!

# USAGE: If you have Vim, check out the Dubsacks Vim plugin:
#
#          https://github.com/landonb/dubs_edit_juice
#
#        which automatically looks for a .trustme.vim above
#        any file you load into a buffer.
#
#        You can install the plugin or just copy the BufEnter
#        autocmd that loads for the .trustme.vim file, from:
#
#          plugin/dubs_edit_juice.vim
#
#        Or, if you're not using Vim, wire this shell script
#        to be called on file save however you are able to
#        do that.
#
#          Maybe check out inotifywait:
#
#            https://linux.die.net/man/1/inotifywait
#
# NOTE: On Vim, if you're using the project.vim plugin, you'll need
#       to add a reference to the script from the directory entry.
#       Otherwise, when you double-click files in the project window
#       to open them, the BufEnter event doesn't trigger properly.
#       E.g.,
#
#         MURANO_CLI=/exo/clients/exosite/MuranoCLI filter=".* *" in=".trustme.vim" {
#           .agignore
#           # ...
#         }
#
# MONITOR: All script output gets writ to a file. Use a terminal to tail it:
#
#            tail -F .rake_build.out

# MEH: Need to enable errexit?
#set +x

OUT_FILE=".rake_build.out"

#local DONE_FILE=".trustme.done"
LOCK_DIR=".trustme.lock"
PID_FILE="${LOCK_DIR}/.build.pid"
LOCK_KILL=".trustme.kill"

trap death SIGINT

function annoucement() {
  echo >> ${OUT_FILE}
  echo "###################################################################" >> ${OUT_FILE}
  echo $1 >> ${OUT_FILE}
  echo "###################################################################" >> ${OUT_FILE}
  echo >> ${OUT_FILE}
}

function death() {
  echo "death!" >> ${OUT_FILE}
  annoucement "DEATH! ☠☠☠"
  exit 1
}

function lock_kill_or_die() {
  local build_it=false
  # mkdir is atomic. Isn't that nice.
  if $(mkdir ${LOCK_DIR} 2> /dev/null); then
    # The first, or only instance to be running. Run the build.
    echo "first one here!" >> ${OUT_FILE}
  elif [[ -d ${LOCK_DIR} ]]; then
    # There's a build going on. Should we kill it?
    if $(mkdir ${LOCK_KILL} 2> /dev/null); then
      if [[ -f ${PID_FILE} ]]; then
        local build_pid=$(cat ${PID_FILE})
        if [[ ${build_pid} != '' ]]; then
          echo "build locked, but not the kill! time for mischiefs" >> ${OUT_FILE}
          # Yeah! We get to kill a process!
          annoucement "Killing it!"
          kill -s SIGINT ${build_pid} &>> ${OUT_FILE}
          if [[ $? -ne 0 ]]; then
            echo "Kill failed! on pid ‘${build_pid}’" >> ${OUT_FILE}
            # So, what happened? Did the build complete?
            # Should we just move along? Probably...
            # Get the name of the process. If it still exists, die.
            if [[ $(ps -p ${build_pid} -o comm=) != '' ]]; then
              echo "WARNING: but process still exists!"
              exit
            fi
          fi
        else
          echo "build locked, but not kill. but no pid? whatever, we'll take it!"
        fi
      else
        echo "build locked, but not kill. but builder has not started, bye" >> ${OUT_FILE}
        exit
      fi
    else
      echo "all locked, party over, man!" >> ${OUT_FILE}
      exit
    fi
  else
    echo "WARNING: could not mkdir ‘${LOCK_DIR}’ and it does not exist, later!" >> ${OUT_FILE}
    exit
  fi
}
lock_kill_or_die

function prepare_to_build() {
  echo "$$" > ${PID_FILE}
  [[ -d ${LOCK_KILL} ]] && rmdir ${LOCK_KILL}

  #/bin/rm ${DONE_FILE}
  #/bin/rm ${OUT_FILE}
  touch ${OUT_FILE}
#  truncate -s 0 ${OUT_FILE}
}
prepare_to_build

time_0=$(date +%s.%N)
echo "Build started at $(date '+%Y-%m-%d_%H-%M-%S')" >> ${OUT_FILE}
echo "cwd: $(pwd)" >> ${OUT_FILE}

function build_it() {
  annoucement "BUILD IT"
  rake build &>> ${OUT_FILE} && \
      gem install -i $(ruby -rubygems -e 'puts Gem.dir') \
          pkg/MuranoCLI-$(ruby -e 'require "/exo/clients/exosite/MuranoCLI/lib/MrMurano/version.rb"; puts MrMurano::VERSION').gem \
      &>> ${OUT_FILE}
}
build_it

function test_concurrency() {
  for i in $(seq 1 5); do build_it; done
}
# DEVs: Wanna test CTRL-C more easily by keeping the script alive longer?
#       Then uncomment this.
#test_concurrency

function lint_it() {
  annoucement "LINT IT"
  rubocop -D -c .rubocop.yml &>> ${OUT_FILE}
}
lint_it

function rspec_it() {
  annoucement "RSPEC IT"
  rake rspec &>> ${OUT_FILE}
}
# This is probably not the best idea,
# especially if your tests use the same
# business as you do when developing.
#rspec_it

time_n=$(date +%s.%N)
time_elapsed=$(echo "$time_n - $time_0" | bc -l)
annoucement "DONE!"
echo "Build finished at $(date '+%H:%M:%S') on $(date '+%Y-%m-%d') in $time_elapsed secs." >> ${OUT_FILE}

#touch ${DONE_FILE}

trap - SIGINT

/bin/rm ${PID_FILE}
rmdir ${LOCK_DIR}


#!/bin/bash
# Last Modified: 2017.12.06
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
#            tail -F .trustme.log

# MEH: Need to enable errexit?
#set +x

OUT_FILE=".trustme.log"

#local DONE_FILE=".trustme.done"
LOCK_DIR=".trustme.lock"
KILL_DIR=".trustme.kill"
PID_FILE=".trustme.pid"
# Hrm. The bang might not work without
KILL_BIN=".trustme.kill!"

# 2017-10-03: Don't build immediately after every save. If you like to
# code a little, save, code a little save, repeat, then always running
# the builder (a) gets annoying to see constantly churning, if you keep
# a terminal on it; and (b) runs the CPU hot, because eslint. So avoid
# building too frequently.
# LATER/2017-10-03: CLI options for this script? It keeps growing!
# For now, hardcode.
#BUILD_DELAY_SECS=300
#BUILD_DELAY_SECS=90
#BUILD_DELAY_SECS=13
#BUILD_DELAY_SECS=5
#BUILD_DELAY_SECS=1
BUILD_DELAY_SECS=0

say() {
  echo "$1" >> "${OUT_FILE}"
}

announcement() {
  say
  say "###################################################################"
  say "$1"
  say "###################################################################"
  say
}

death() {
  if [[ -n ${WAIT_PID} ]]; then
    say "Sub-killing ‘${WAIT_PID}’"
    kill -s 9 ${WAIT_PID}
  fi
  # The other script waits for us to cleanup the PID file.
  remove_pid_files
  # Note that output gets interleaved with the killing process,
  # so keep this to one line (don't use `announcement`).
  say "☠☠☠ DEATH! ☠☠☠ ‘$$’ is now dead"
  exit 1
}

# FIXME/2017-09-28: Move this and other common fcns. to home-fries?
lock_kill_die() {
  #say "Looking for lock on $(date)..."
  say "Desperately Seeking Lock on $(date)..."
  [[ "$1" == true ]] && local AFTER_WAIT=true || local AFTER_WAIT=false
  local build_it=false
  # mkdir is atomic. Isn't that nice.
  if $(mkdir "${LOCK_DIR}" 2> /dev/null); then
    say "Scored the lock!"
    kill_other ${AFTER_WAIT} true
  elif [[ -d "${LOCK_DIR}" ]]; then
    if ! ${AFTER_WAIT}; then
      # There's another script waiting to build, or a build going on.
      # Kill it if you can.
      say "Could not lock, but can still kill!"
      kill_other ${AFTER_WAIT} false
    else
      # This script got the lock earlier, released it, and slept, and now
      # it cannot get the lock...
      say "i waited for you but you locked me out"
      exit
    fi
  else
    announcement "WARNING: could not mkdir ‘${LOCK_DIR}’ and it does not exist, later!"
    exit
  fi
}

kill_other() {
  [[ "$1" == true ]] && local AFTER_WAIT=true || local AFTER_WAIT=false
  [[ "$2" == true ]] && local OUR_LOCK=true || local OUR_LOCK=false
  if $(mkdir "${KILL_DIR}" 2> /dev/null); then
    if [[ -f "${PID_FILE}" ]]; then
      local build_pid=$(cat "${PID_FILE}")
      if ${AFTER_WAIT}; then
        if [[ "$$" != "${build_pid}" ]]; then
          echo "Panic, jerks! The build_pid is not our PID! ${build_pid} != $$"
          exit
        fi
      elif [[ "${build_pid}" != '' ]]; then
        #say "Locked the kill directory! time for mischiefs"
        say "Killing ‘${build_pid}’"
        # Process, your time has come.
        kill -s SIGUSR1 "${build_pid}" &>> "${OUT_FILE}"
        if [[ $? -ne 0 ]]; then
          say "Kill failed! On PID ‘${build_pid}’"
          # So, what happened? Did the build complete?
          # Should we just move along? Probably...
          # Get the name of the process. If it still exists, die.
          if [[ $(ps -p "${build_pid}" -o comm=) != '' ]]; then
            say "Said process still exists!"
            exit
          fi
          # The process is a ghost.
          remove_pid_files
        else
          # Wait for the other trustme to clean up.
          WAIT_PATIENCE=10
          sleep 0.1
          while [[ -f "${PID_FILE}" ]]; do
            say "Waiting on PID ${build_pid} to cleanup..."
            sleep 0.5
            WAIT_PATIENCE=$((WAIT_PATIENCE - 1))
            [[ ${WAIT_PATIENCE} -eq 0 ]] && echo "Done waiting!" && exit
          done
        fi
      else
        say "WARNING: Empty PID file? Whatever, we'll take it!"
      fi
    elif ! ${OUR_LOCK}; then
      # This is after waiting, which seems weird, eh.
      say "Kill okay without build lock, but no PID file. Is someone tinkering?"
      exit
    else
      say "Got the build lock and kill lock, and there's no PID. Fresh powder!"
    fi
  else
    say "Someone else has the kill lock. We're boned!"
    exit
  fi
}

lock_or_die() {
  lock_kill_die false
}

lock_kill_or_die() {
  lock_kill_die true
}

prepare_to_build() {
  #/bin/rm "${DONE_FILE}"
  #/bin/rm "${OUT_FILE}"
  touch "${OUT_FILE}"
  truncate -s 0 "${OUT_FILE}"
}

init_it() {
  if [[ -f ${HOME}/.fries/lib/ruby_util.sh ]]; then
    source ${HOME}/.fries/lib/ruby_util.sh
  else
    echo 'Missing ruby_util.sh and chruby' >> ${OUT_FILE}
    exit 1
  fi
  chruby 2.3.3
}

lang_it() {
  announcement "LANG IT"
}

build_it() {
  annoucement "BUILD IT"

  echo "cwd: $(pwd)" >> ${OUT_FILE}
  echo "- ruby -v: $(ruby -v)" >> ${OUT_FILE}
  echo "- rubocop -v: $(rubocop -v)" >> ${OUT_FILE}
  #echo "- cmd rubocop: $(command -v rubocop)" >> ${OUT_FILE}

  rake build &>> ${OUT_FILE} && \
      gem install -i $(ruby -rubygems -e 'puts Gem.dir') \
          pkg/MuranoCLI-$(ruby -e 'require "/exo/clients/exosite/MuranoCLI/lib/MrMurano/version.rb"; puts MrMurano::VERSION').gem \
      &>> ${OUT_FILE}
}

lint_it() {
  annoucement "LINT IT"
  rubocop -D -c .rubocop.yml &>> ${OUT_FILE}
}

rspec_it() {
  annoucement "RSPEC IT"
  rake rspec &>> ${OUT_FILE}
}

ctags_it() {
  annoucement "CTAGS IT"
  ctags -R \
    --exclude=coverage \
    --exclude=docs \
    --exclude=pkg \
    --exclude=report \
    --exclude=spec \
    --verbose=yes
  /bin/ls -la tags >> ${OUT_FILE}
}

drop_locks() {
  rmdir "${LOCK_DIR}" "${KILL_DIR}"
}

remove_pid_files() {
  /bin/rm "${PID_FILE}"
  /bin/rm "${KILL_BIN}"
}

main() {
  # We're called on both save, and on simple buffer enter.
  if [[ ${DUBS_TRUST_ME_ON_SAVE} != 1 ]]; then
    # We've got nothing to do on simple buffer enter...
    announcement "DUBS_TRUST_ME_ON_FILE: ${DUBS_TRUST_ME_ON_FILE}"
    say "Nothing to do on open"
    exit 1
  fi

  trap death SIGUSR1

  announcement "❎ ❎ ❎ ❎ ❎ ❎ ❎ ❎ ❎ ❎ ❎ ❎ ❎ ❎ ❎ ❎ ❎ ❎ ❎ ❎ ❎ ❎ ❎ ❎ ❎"

  init_it

  # Get the lock.
  lock_or_die

  say "‘$$’ has the lock"
  echo "$$" > "${PID_FILE}"
  echo "kill -s SIGUSR1 $$" > "${KILL_BIN}"
  chmod 755 "${KILL_BIN}"

  # 2017-10-17: Always build tags.
# 2017-11-13 14:49: WTF?: When run alone, fine; when from Vim, spinning!
#  ctags_it

  say "WAITING ON BUILD (countdown: ${BUILD_DELAY_SECS} secs.)..."

  # Defer the build!
  # FIXME/2017-10-03: Riddle me this: is a two-fer rmdir atomic?
  drop_locks
  # The trap on SIGUSR1 only fires when this script is active and
  # not blocked on a subshell. And sleep is it's own command, so we
  # background it.
  sleep ${BUILD_DELAY_SECS} &
  # Fortunately, we can use the Bash wait command, which does not
  # block signals.
  # Get the process ID of the last command.
  #   LPID=$!
  #   wait ${LPID}
  # Or just wait.
  wait

  say "READY TO BUILD..."

  # Get the lock.
  lock_kill_or_die

  say "BUILDING!"

  if ${TESTING:-false}; then
    drop_locks
    remove_pid_files
    say "DONE! (ONLY TESTING)"
    exit
  fi

  rmdir "${KILL_DIR}"
  prepare_to_build

  time_0=$(date +%s.%N)
  #say # Put newline after "tail: .rake_build.out: file truncated"
  announcement "WARMING UP"
  say "Build started at $(date '+%Y-%m-%d_%H-%M-%S')"
  say "cwd: $(pwd)"

  #lang_it

  build_it
  function test_concurrency() {
    for i in $(seq 1 5); do build_it; done
  }
  # DEVs: Wanna test CTRL-C more easily by keeping the script alive longer?
  #       Then uncomment this.
  #test_concurrency

  lint_it

  # MEH/2017-12-06: The tests take a number of seconds to run, so skipping.
  #test_it

  ctags_it

  time_n=$(date +%s.%N)
  time_elapsed=$(echo "$time_n - $time_0" | bc -l)
  announcement "DONE!"
  say "Build finished at $(date '+%H:%M:%S') on $(date '+%Y-%m-%d') in ${time_elapsed} secs."

  #touch "${DONE_FILE}"

  trap - SIGUSR1

  remove_pid_files
  rmdir "${LOCK_DIR}"
}

main "$@"


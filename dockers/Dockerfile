FROM lazyatom/ruby-2.0:latest

# NOTE: Environs from Jenkins, like ${WORKSPACE} or any passwords you
#   inject, are not available from here (Build Environment setup).

# This is already a given, but just to be clear:
USER root

# Jenkins defaults to the ASCII encoding, but we want UTF-8.
#
# FIXME/MEH: (lb): Murano CLI still has encoding issues, e.g.,
# the highline.say() command crashes on some strings, complaining:
#
#   invalid byte sequence in US-ASCII
#
# which we currently work around by running Murand CLI in ASCII, e.g.,
#
#   murano --no-progress --no-color --ascii ...
#
# which means our Jenkins/Docker test is not quite testing how
# people usually run the app. Oh well.
#
# ((lb): I had hoped that setting ENV herein would help, and while it
# does change the encoding for the `docker exec` command that Jenkins
# runs later, it doesn't fix the "invalid byte sequence" error.)
#
# NOTE: You cannot change the encoding from the Execute Shell build
# command. If you tried, you'd see, e.g.,:
#
#   $ export LC_ALL=en_US.UTF-8
#   setlocale: LC_ALL: cannot change locale (en_US.UTF-8)
#
# ALSO: Skip LC_ALL, otherwise when Jenkins runs `docker exec ...` you'll see:
#
#   /bin/bash: warning: setlocale: LC_ALL: cannot change locale (en_US.UTF-8)

ENV LANGUAGE en_US.UTF-8
ENV LANG en_US.UTF-8

# Jenkins runs the Execute Shell script on Docker as the 'jenkins' user,
# but Docker is confused unless we create that user now and assign it the
# UID that gets used. ((lb): This is hacky; Ops might fix this eventually.)
#
# Without adding the user to the root group and having them run as such,
# we'd see Errno::EACCES "Permission denied @ rb_sysopen" errors, and we'd
# have to do the hideous, grotesque act of granting permissions to all:
#
#    RUN /bin/chmod -R go+w /app
#    RUN /bin/chmod 2777 /app

RUN useradd -m -s /bin/bash --uid 1001 -G root jenkins

# (lb): So. Weird. Sometimes the Jenkins Docker Volumes mount with 2755
# permissions. Othertimes with 2777. In case this happens again, I'll
# leaving this code here. Give jenkins user power to fix permissions on the
# mounted Volumes: /app/report and /app/coverage mount as 2755 root:root.
# NOTE: Skipping `RUN apt-get upgrade -y` to run faster.
#   RUN \
#     echo "deb http://ftp.us.debian.org/debian/ jessie main contrib non-free" \
#       >> /etc/apt/sources.list \
#     && echo "deb-src http://ftp.us.debian.org/debian/ jessie main contrib non-free" \
#       >> /etc/apt/sources.list \
#     && apt-get -qq update \
#     && apt-get install -y sudo
#   #RUN echo "jenkins ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
#   RUN echo "jenkins ALL= NOPASSWD: chmod" >> /etc/sudoers

# Create the /app directory and give ownership to the new user, otherwise
# if we switch to the new user first, they cannot create the workdir.

WORKDIR /app
COPY . /app

RUN /bin/chown -R jenkins /app

# Run as the new jenkins user, otherwise Ruby gem permissions are
# restrictive, and we don't want to have to fudge them, e.g.,
#
#   # Madness!
#   RUN chmod 2777 /usr/local/bundle
#   RUN chmod 2777 /usr/local/bundle/bin
#   RUN find /usr/local/bundle -type d -exec chmod 2777 {} +
#   RUN find /usr/local/bundle -type f -exec chmod u+rw,g+rw,o+rw {} +

# Prepare the bundle and rspec Ruby commands, and build Murano CLI.

USER jenkins

RUN cd /app && \
  gem install bundler && \
  gem install rspec && \
  bundler install && \
  rake build

# Install Murano CLI.

RUN gem install \
	pkg/MuranoCLI-$(ruby -e \
		'require "/app/lib/MrMurano/version.rb"; puts MrMurano::VERSION' \
	).gem

# vim:tw=0:ts=4:sw=4:noet:ft=conf:


FROM debian:jessie
#FROM lazyatom/ruby-2.0:latest
#FROM ruby:2.3.6-jessie

USER root

# [91mE: Could not open lock file /var/cache/apt/archives/lock - open (2: No such file or directory)
# E: Unable to lock the download directory

#RUN apt-get clean && apt-get -y update && apt-get install -y locales && locale-gen en_US.UTF-8
#RUN apt-get clean
#RUN apt-get -y update
RUN \
  echo "deb http://ftp.us.debian.org/debian/ jessie main contrib non-free" \
    >> /etc/apt/sources.list \
  && echo "deb-src http://ftp.us.debian.org/debian/ jessie main contrib non-free" \
    >> /etc/apt/sources.list \
  && apt-get -qq update \
  && apt-get install -y sudo

#ENV LANGUAGE en_US.UTF-8
#ENV LANG en_US.UTF-8
#ENV LC_ALL en_US.UTF-8

RUN apt-get install -y locales
#RUN locale -a
#RUN locale-gen en_US.UTF-8
#RUN locale -a
#ENV LANG='en_US.UTF-8' LANGUAGE='en_US.UTF-8' LC_ALL='en_US.UTF-8'
#RUN locale -a
ENV LANG='C.UTF-8' LANGUAGE='C.UTF-8' LC_ALL='C.UTF-8'


#[91mperl: warning: Setting locale failed.
#[0m[91mperl: warning: Please check that your locale settings:
#[0m[91m	LANGUAGE = "en_US.UTF-8",
#[0m[91m	LC_ALL = "en_US.UTF-8",
#[0m[91m	LANG = "en_US.UTF-8"
#[0m[91m    are supported and installed on your system.
#[0m[91mperl: warning: Falling back to the standard locale ("C").

#ENV LANGUAGE en_US.UTF-8
#ENV LANG en_US.UTF-8
#ENV LC_ALL en_US.UTF-8
#RUN locale-gen en_US.UTF-8
# dpkg-reconfigure locales is interactive
#RUN dpkg-reconfigure locales
# Works, but seems no different than what apt-get install locales does post-install.
#RUN locale-gen --purge
# update-locale is for updating /etc/default/locale, so maybe something else?
# update-locale: Error: invalid locale settings:  LANG=en_US.UTF-8
#RUN update-locale LANG=en_US.UTF-8


RUN useradd -m -s /bin/bash --uid 1001 -G root jenkins


WORKDIR /app
COPY . /app

RUN /bin/chown -R jenkins /app


RUN \
  echo "deb http://ftp.us.debian.org/debian/ jessie main contrib non-free" \
    >> /etc/apt/sources.list \
  && echo "deb-src http://ftp.us.debian.org/debian/ jessie main contrib non-free" \
    >> /etc/apt/sources.list \
  && apt-get -qq update \
  && apt-get install -y sudo \
  && apt-get install -y git \
  && apt-get install -y ruby



USER jenkins


#if [ -e "$HOME/.rbenv" -a ! -d "$HOME/.rbenv" ]; then
#	rm -rf "$HOME/.rbenv"
#fi

#if [ ! -d "$HOME/.rbenv" ]; then
RUN git clone https://github.com/rbenv/rbenv.git /home/jenkins/.rbenv
RUN git clone https://github.com/rbenv/ruby-build.git /home/jenkins/.rbenv/plugins/ruby-build
#fi

RUN /bin/ls -la /home/jenkins/.rbenv
RUN /bin/ls -la /home/jenkins/.rbenv/bin

ENV PATH="/home/jenkins/.rbenv/bin:${PATH}"
RUN rbenv versions || echo none
RUN rbenv install 2.3.4 || echo DONE
RUN rbenv install 2.4.1 || echo DONE
RUN rbenv install 2.2.7 || echo DONE
RUN rbenv rehash
RUN rbenv versions


RUN ruby -rubygems -e 'puts Gem.user_dir'
#if which ruby >/dev/null && which gem >/dev/null; then
#[91mWARNING:  You don't have /home/jenkins/.gem/ruby/2.1.0/bin in your PATH,
ENV PATH="$(ruby -rubygems -e 'puts Gem.user_dir')/bin:$PATH"
#fi


#RUN cd /app && \
#  gem install bundler && \
#  gem install rspec && \
#  bundler install && \
#  rake build
RUN cd /app
RUN gem install --user-install bundler
RUN gem install --user-install rspec
RUN /bin/ls -la /home/jenkins/.gem
RUN /bin/ls -la /home/jenkins/.gem/ruby
RUN bundler install
RUN rake build




# Install Murano CLI.

RUN gem install \
	pkg/MuranoCLI-$(ruby -e \
		'require "/app/lib/MrMurano/version.rb"; puts MrMurano::VERSION' \
	).gem

# vim:tw=0:ts=4:sw=4:noet:ft=conf:






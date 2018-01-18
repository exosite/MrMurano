FROM debian:jessie
#FROM lazyatom/ruby-2.0:latest
#FROM ruby:2.3.6-jessie

USER root

ENV LANGUAGE en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8
RUN locale-gen en_US.UTF-8
RUN dpkg-reconfigure locales



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

ENV PATH="/home/jenkins/.rbenv/bin:${PATH}"
RUN rbenv versions || echo none
RUN rbenv install 2.3.4 || echo DONE
RUN rbenv install 2.4.1 || echo DONE
RUN rbenv install 2.2.7 || echo DONE
RUN rbenv rehash
RUN rbenv versions


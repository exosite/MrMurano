#FROM vallard/nginx
FROM jessie
#MAINTAINER Vallard Benincosa "vallard@benincosa.com"
RUN apt-get update
# install the prerequisite patches here so that rvm will install under non-root account. 
RUN apt-get install -y curl patch gawk g++ gcc make libc6-dev patch libreadline6-dev zlib1g-dev libssl-dev libyaml-dev libsqlite3-dev sqlite3 autoconf libgdbm-dev libncurses5-dev automake libtool bison pkg-config libffi-dev



ENV LANGUAGE en_US.UTF-8
ENV LANG en_US.UTF-8

RUN useradd -m -s /bin/bash --uid 1001 -G root jenkins

WORKDIR /app
COPY . /app

RUN /bin/chown -R jenkins /app

USER jenkins


#RUN useradd -ms /bin/bash app
#USER app
RUN gpg --keyserver hkp://keys.gnupg.net --recv-keys D39DC0E3
RUN /bin/bash -l -c "curl -L get.rvm.io | bash -s stable --rails"
RUN /bin/bash -l -c "rvm install 2.1"
RUN /bin/bash -l -c "echo 'gem: --no-ri --no-rdoc' > ~/.gemrc"
RUN /bin/bash -l -c "gem install bundler --no-ri --no-rdoc"
RUN /bin/bash -l -c "gem install rspec --no-ri --no-rdoc"
RUN /bin/bash -l -c "bundler install"
RUN /bin/bash -l -c "rake build"
RUN gem install \
	pkg/MuranoCLI-$(ruby -e \
		'require "/app/lib/MrMurano/version.rb"; puts MrMurano::VERSION' \
	).gem


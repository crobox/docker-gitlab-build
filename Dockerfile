FROM ubuntu:18.04

RUN apt-get update \
	&& apt-get install -y --no-install-recommends \
		ca-certificates curl wget unzip software-properties-common openjdk-11-jdk libsnappy-java \
		language-pack-en fontconfig libffi-dev build-essential git apt-transport-https ssh libssl-dev \
		python3-dev python3-pip python3-setuptools python-dev python-pip python-setuptools \
		gettext dos2unix bc gpg dirmngr gpg-agent ruby-full patch zlib1g-dev liblzma-dev \
	&& rm -rf /var/lib/apt/lists/*

# Install httpie (with SNI), awscli, docker-compose, sbt
# Need 2 step since some dependencies require setuptools to be present
RUN pip3 install --upgrade wheel setuptools \
    && pip3 install --upgrade pyopenssl pyasn1 ndg-httpsclient httpie awscli docker-compose

RUN pip install --upgrade wheel setuptools \
    && pip install --upgrade pyopenssl pyasn1 ndg-httpsclient httpie awscli docker-compose

RUN gem install rake bundler --no-ri --no-rdoc

# Fix locale.
ENV LANG en_US.UTF-8
ENV LC_CTYPE en_US.UTF-8
RUN locale-gen en_US && update-locale LANG=en_US.UTF-8 LC_CTYPE=en_US.UTF-8

# grab gosu for easy step-down from root
RUN gpg --keyserver keyserver.ubuntu.com --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4
RUN curl -o /usr/local/bin/gosu -SL "https://github.com/tianon/gosu/releases/download/1.6/gosu-$(dpkg --print-architecture)" \
	&& curl -o /usr/local/bin/gosu.asc -SL "https://github.com/tianon/gosu/releases/download/1.6/gosu-$(dpkg --print-architecture).asc" \
	&& gpg --verify /usr/local/bin/gosu.asc \
	&& rm /usr/local/bin/gosu.asc \
	&& chmod +x /usr/local/bin/gosu

# Install sbt
RUN echo "deb https://dl.bintray.com/sbt/debian /" | tee -a /etc/apt/sources.list.d/sbt.list \
  && apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 642AC823 \
  	&& apt-get update \
  	&& apt-get install -y --no-install-recommends sbt \
  	&& rm -rf /var/lib/apt/lists/*
	
# Install docker
ENV DOCKER_VERSION 18.09.9
RUN set -x \
	&& curl -fSL "https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_VERSION}.tgz" -o docker.tgz \
	&& tar -xzvf docker.tgz \
	&& mv docker/* /usr/local/bin/ \
	&& rmdir docker \
	&& rm docker.tgz \
	&& docker -v

RUN groupadd docker && adduser --disabled-password --gecos "" gitlab \
	&& usermod -a -G docker gitlab

# Install maven
ENV MAVEN_VERSION 3.6.2
ENV MAVEN_HOME /usr/share/maven
RUN mkdir -p /usr/share/maven \
  && curl -fsSL https://apache.osuosl.org/maven/maven-3/$MAVEN_VERSION/binaries/apache-maven-$MAVEN_VERSION-bin.tar.gz \
    | tar -xzC /usr/share/maven --strip-components=1 \
  && ln -s /usr/share/maven/bin/mvn /usr/bin/mvn

# Install jq (from github, repo contains ancient version)
RUN curl -o /usr/local/bin/jq -SL https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 \
	&& chmod +x /usr/local/bin/jq

# Install nodejs
ENV NPM_CONFIG_LOGLEVEL info
ENV NODE_VERSION 12.13.0

RUN curl -SLO "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-x64.tar.xz" \
  && curl -SLO "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt" \
  && grep " node-v$NODE_VERSION-linux-x64.tar.xz\$" SHASUMS256.txt | sha256sum -c - \
  && tar -xJf "node-v$NODE_VERSION-linux-x64.tar.xz" -C /usr/local --strip-components=1 \
  && rm "node-v$NODE_VERSION-linux-x64.tar.xz" SHASUMS256.txt \
  && ln -s /usr/local/bin/node /usr/local/bin/nodejs

RUN sbt -Dsbt.version=1.2.8 -batch clean
RUN sbt -Dsbt.version=1.3.3 -batch clean

# Setup the build environment with credentials
# Pass these in as "secret variables" on gitlab group or repository level
ADD scripts /scripts/

# Initialize environment variables and start the run command or the default one
ENTRYPOINT ["/scripts/entrypoint.sh"]
# Default command passed to the entrypoint script
CMD ["/bin/bash"]

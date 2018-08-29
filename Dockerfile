FROM ubuntu:18.04

RUN apt-get update \
	&& apt-get install -y --no-install-recommends \
		ca-certificates curl wget unzip software-properties-common \
		language-pack-en fontconfig libffi-dev build-essential git apt-transport-https ssh libssl-dev \
		python3-dev python3-pip python3-setuptools \
		gettext dos2unix bc gpg dirmngr gpg-agent ruby-full \
	&& rm -rf /var/lib/apt/lists/*

ENV MAVEN_VERSION 3.5.4
ENV MAVEN_HOME /usr/share/maven

ENV DOCKER_VERSION 18.06.1-ce
ENV SONAR_SCANNER_VERSION 3.2.0.1227
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

# Install java-8-oracle
RUN echo "deb https://dl.bintray.com/sbt/debian /" | tee -a /etc/apt/sources.list.d/sbt.list \
  && apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 642AC823 \
  && echo debconf shared/accepted-oracle-license-v1-1 select true | debconf-set-selections \
	&& echo debconf shared/accepted-oracle-license-v1-1 seen true | debconf-set-selections \
	&& add-apt-repository -y ppa:webupd8team/java \
	&& apt-get update \
  	&& apt-get install -y --no-install-recommends \
      oracle-java8-installer ca-certificates-java sbt libsnappy-java \
  	&& rm -rf /var/lib/apt/lists/* /var/cache/oracle-jdk8-installer/*.tar.gz /usr/lib/jvm/java-8-oracle/src.zip /usr/lib/jvm/java-8-oracle/javafx-src.zip \
      /usr/lib/jvm/java-8-oracle/jre/lib/security/cacerts \
  	&& ln -s /etc/ssl/certs/java/cacerts /usr/lib/jvm/java-8-oracle/jre/lib/security/cacerts \
  	&& update-ca-certificates

# Install docker
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
RUN mkdir -p /usr/share/maven \
  && curl -fsSL https://apache.osuosl.org/maven/maven-3/$MAVEN_VERSION/binaries/apache-maven-$MAVEN_VERSION-bin.tar.gz \
    | tar -xzC /usr/share/maven --strip-components=1 \
  && ln -s /usr/share/maven/bin/mvn /usr/bin/mvn

# Install jq (from github, repo contains ancient version)
RUN curl -o /usr/local/bin/jq -SL https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64 \
	&& chmod +x /usr/local/bin/jq

# Install nodejs
# gpg keys listed at https://github.com/nodejs/node
RUN set -ex \
  && for key in \
    94AE36675C464D64BAFA68DD7434390BDBE9B9C5 \
    B9AE9905FFD7803F25714661B63B535A4C206CA9 \
    77984A986EBC2AA786BC0F66B01FBB92821C587A \
    71DCFD284A79C3B38668286BC97EC7A07EDE3FC1 \
    FD3A5288F042B6850C66B31F09FE44734EB7990E \
    8FCCA13FEF1D0C2E91008E09770F7A9A5AE15600 \
    C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8 \
    DD8F2338BAE7501E3DD5AC78C273792F7D83545D \
  ; do \
    gpg --keyserver keyserver.ubuntu.com --recv-keys "$key"; \
  done

ENV NPM_CONFIG_LOGLEVEL info
ENV NODE_VERSION 8.11.4

RUN curl -SLO "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-x64.tar.xz" \
  && curl -SLO "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt.asc" \
  && gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc \
  && grep " node-v$NODE_VERSION-linux-x64.tar.xz\$" SHASUMS256.txt | sha256sum -c - \
  && tar -xJf "node-v$NODE_VERSION-linux-x64.tar.xz" -C /usr/local --strip-components=1 \
  && rm "node-v$NODE_VERSION-linux-x64.tar.xz" SHASUMS256.txt.asc SHASUMS256.txt \
  && ln -s /usr/local/bin/node /usr/local/bin/nodejs

# Install sonar-scanner
RUN curl -SLO "https://sonarsource.bintray.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-${SONAR_SCANNER_VERSION}-linux.zip" \
	&& unzip sonar-scanner-cli-${SONAR_SCANNER_VERSION}-linux.zip -d /usr/share/sonar-scanner/ \
	&& mv /usr/share/sonar-scanner/sonar-scanner-${SONAR_SCANNER_VERSION}-linux/* /usr/share/sonar-scanner/ \
	&& ln -s /usr/share/sonar-scanner/bin/sonar-scanner /usr/bin/sonar-scanner

RUN sbt -Dsbt.version=1.0.3 -batch clean \
    && sbt -Dsbt.version=1.0.4 -batch clean \
    && sbt -Dsbt.version=1.1.0 -batch clean \
    && sbt -Dsbt.version=1.1.2 -batch clean \
    && sbt -Dsbt.version=1.2.0 -batch clean

# Install httpie (with SNI), awscli, docker-compose, sbt
# Need 2 step since some dependencies require setuptools to be present
RUN pip3 install --upgrade wheel setuptools \
    && pip3 install --upgrade pyopenssl pyasn1 ndg-httpsclient httpie awscli docker-compose

RUN gem install rake bundler sass:3.4.22 compass --no-ri --no-rdoc

# Setup the build environment with credentials
# Pass these in as "secret variables" on gitlab group or repository level
ADD scripts /scripts/

# Initialize environment variables and start the run command or the default one
ENTRYPOINT ["/scripts/entrypoint.sh"]
# Default command passed to the entrypoint script
CMD ["/bin/bash"]

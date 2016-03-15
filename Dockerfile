# Use Wheezy instead of Jessie since some of legacy erlang doesn't existing for Jessie.
FROM debian:wheezy

# add our user and group first to make sure their IDs get assigned consistently, regardless of whatever dependencies get added
RUN groupadd -r rabbitmq && useradd -r -d /var/lib/rabbitmq -m -g rabbitmq rabbitmq

# grab gosu for easy step-down from root
ENV GOSU_VERSION 1.7
RUN set -x \
	&& apt-get update && apt-get install -y --no-install-recommends ca-certificates wget && rm -rf /var/lib/apt/lists/* \
	&& wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture)" \
	&& wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture).asc" \
	&& export GNUPGHOME="$(mktemp -d)" \
	&& gpg --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
	&& gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
	&& rm -r "$GNUPGHOME" /usr/local/bin/gosu.asc \
	&& chmod +x /usr/local/bin/gosu \
	&& gosu nobody true \
	&& apt-get purge -y --auto-remove ca-certificates wget

# >> Not using erlang apt package for legacy version - @sunggun-yu
# Add the officially endorsed Erlang debian repository:
# See:
#  - http://www.erlang.org/download.html
#  - https://www.erlang-solutions.com/downloads/download-erlang-otp
#RUN apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 434975BD900CCBE4F7EE1B1ED208507CA14F4FCA
#RUN echo 'deb http://packages.erlang-solutions.com/debian jessie contrib' > /etc/apt/sources.list.d/erlang.list

# >> Ignoring below for legacy version - @sunggun-yu
# get logs to stdout (thanks @dumbbell for pushing this upstream! :D)
#ENV RABBITMQ_LOGS=- RABBITMQ_SASL_LOGS=-
# https://github.com/rabbitmq/rabbitmq-server/commit/53af45bf9a162dec849407d114041aad3d84feaf

# >> Not using apt package for legacy version - @sunggun-yu
# http://www.rabbitmq.com/install-debian.html
# "Please note that the word testing in this line refers to the state of our release of RabbitMQ, not any particular Debian distribution."
#RUN apt-key adv --keyserver ha.pool.sks-keyservers.net --recv-keys F78372A06FF50C80464FC1B4F7B8CEA6056E8E56
#RUN echo 'deb http://www.rabbitmq.com/debian testing main' > /etc/apt/sources.list.d/rabbitmq.list

ENV RABBITMQ_VERSION 3.1.5
ENV RABBITMQ_DEBIAN_VERSION 3.1.5-1_all

# >> Not using apt package for legacy version - @sunggun-yu
#RUN apt-get update && apt-get install -y --no-install-recommends \
#		erlang erlang-mnesia erlang-public-key erlang-crypto erlang-ssl erlang-asn1 erlang-inets erlang-os-mon erlang-xmerl erlang-eldap \
#		rabbitmq-server=$RABBITMQ_DEBIAN_VERSION \
#	&& rm -rf /var/lib/apt/lists/*

# Install packages - @sunggun-yu
# - Install wget and logrotate and dependency of erlang
# - Install Erlang R14B04
# - Install package in dpkg way since legacy version is not available in RabbitMQ package repo
RUN set -x \
    && cd /root \
    && apt-get update && apt-get install -y --no-install-recommends \
        wget logrotate \
        procps libssl1.0.0 libwxbase2.8-0 libwxgtk2.8-0 \
    && wget http://packages.erlang-solutions.com/site/esl/esl-erlang/FLAVOUR_1_general/esl-erlang_14.b.4-1~debian~wheezy_amd64.deb \
    && wget http://www.rabbitmq.com/releases/rabbitmq-server/v$RABBITMQ_VERSION/rabbitmq-server_$RABBITMQ_DEBIAN_VERSION.deb \
    && dpkg -i esl-erlang_14.b.4-1~debian~wheezy_amd64.deb \
    && dpkg -i rabbitmq-server_$RABBITMQ_DEBIAN_VERSION.deb \
    && rm esl-erlang_14.b.4-1~debian~wheezy_amd64.deb \
    && rm rabbitmq-server_$RABBITMQ_DEBIAN_VERSION.deb

# /usr/sbin/rabbitmq-server has some irritating behavior, and only exists to "su - rabbitmq /usr/lib/rabbitmq/bin/rabbitmq-server ..."
ENV PATH /usr/lib/rabbitmq/bin:$PATH

RUN echo '[{rabbit, [{loopback_users, []}]}].' > /etc/rabbitmq/rabbitmq.config

# set home so that any `--user` knows where to put the erlang cookie
ENV HOME /var/lib/rabbitmq

RUN mkdir -p /var/lib/rabbitmq /etc/rabbitmq \
	&& chown -R rabbitmq:rabbitmq /var/lib/rabbitmq /etc/rabbitmq \
	&& chmod 777 /var/lib/rabbitmq /etc/rabbitmq
VOLUME /var/lib/rabbitmq

# add a symlink to the .erlang.cookie in /root so we can "docker exec rabbitmqctl ..." without gosu
RUN ln -sf /var/lib/rabbitmq/.erlang.cookie /root/

RUN ln -sf /usr/lib/rabbitmq/lib/rabbitmq_server-$RABBITMQ_VERSION/plugins /plugins

COPY docker-entrypoint.sh /
ENTRYPOINT ["/docker-entrypoint.sh"]

EXPOSE 4369 5671 5672 25672
CMD ["rabbitmq-server"]

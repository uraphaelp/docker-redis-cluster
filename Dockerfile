# Build from commits based on redis:3.2
FROM redis@sha256:000339fb57e0ddf2d48d72f3341e47a8ca3b1beae9bdcb25a96323095b72a79b

LABEL maintainer="Raphael Zheng <uraphaelp@163.com>"

# Some Environment Variables
ENV HOME /root
ENV DEBIAN_FRONTEND noninteractive


RUN mv /etc/apt/sources.list /etc/apt/sources.list.bak && \
    echo "deb http://apt.x.netease.com:8660/debian/ stretch main non-free contrib" > /etc/apt/sources.list && \
    echo "deb http://apt.x.netease.com:8660/debian/ stretch-updates main non-free contrib" >> /etc/apt/sources.list && \

    echo "deb-src http://apt.x.netease.com:8660/debian/ stretch main non-free contrib" >> /etc/apt/sources.list && \
    echo "deb-src http://apt.x.netease.com:8660/debian/ stretch-updates main non-free contrib" >> /etc/apt/sources.list && \
    echo "deb http://apt.x.netease.com:8660/debian-security/ stretch/updates main non-free contrib" >> /etc/apt/sources.list && \
    echo "deb-src http://apt.x.netease.com:8660/debian-security/ stretch/updates main non-free contrib" >> /etc/apt/sources.list && \
    echo "deb http://mirrors.aliyun.com/debian stretch main contrib non-free" >> /etc/apt/sources.list && \
    echo "deb-src http://mirrors.aliyun.com/debian stretch main contrib non-free" >> /etc/apt/sources.list && \
    echo "deb http://mirrors.aliyun.com/debian stretch-updates main contrib non-free" >> /etc/apt/sources.list && \
    echo "deb-src http://mirrors.aliyun.com/debian stretch-updates main contrib non-free" >> /etc/apt/sources.list && \
    echo "deb http://mirrors.aliyun.com/debian-security stretch/updates main contrib non-free" >> /etc/apt/sources.list && \
    echo "deb-src http://mirrors.aliyun.com/debian-security stretch/updates main contrib non-free" >> /etc/apt/sources.list


# Install system dependencies
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -yqq \
      net-tools supervisor ruby rubygems locales gettext-base wget curl && \
    apt-get clean -yqq

# # Ensure UTF-8 lang and locale
RUN locale-gen en_US.UTF-8
ENV LANG       en_US.UTF-8
ENV LC_ALL     en_US.UTF-8

# Necessary for gem installs due to SHA1 being weak and old cert being revoked
ENV SSL_CERT_FILE=/usr/local/etc/openssl/cert.pem

COPY ./tmpl/redis-4.0.2.gem ./redis-4.0.2.gem
RUN gem install --local ./redis-4.0.2.gem
# RUN gem install redis -v 4.0.2
# RUN mkdir -p /var/lib/gems/2.3.0/cache && \
#    wget https://rubygems.org/downloads/redis-4.0.2.gem -o /var/lib/gems/2.3.0/cache/redis-4.0.2.gem && \
#    gem install --local /var/lib/gems/2.3.0/cache/redis-4.0.2.gem


RUN apt-get install -y gcc make g++ build-essential libc6-dev tcl git supervisor ruby

# 默认 5.0.5
ARG redis_version=5.0.5

RUN echo $redis_version > /redis-version.txt

RUN wget -qO redis.tar.gz https://github.com/antirez/redis/archive/${redis_version}.tar.gz \
    && tar xfz redis.tar.gz -C / \
    && mv /redis-$redis_version /redis

RUN (cd /redis && make)

RUN mkdir /redis-conf
RUN mkdir /redis-data

COPY ./tmpl/redis-cluster.tmpl /redis-conf/redis-cluster.tmpl
COPY ./tmpl/redis.tmpl /redis-conf/redis.tmpl
COPY ./tmpl/sentinel.tmpl /redis-conf/sentinel.tmpl

# Add startup script
COPY ./docker-entrypoint.sh /docker-entrypoint.sh

# Add script that generates supervisor conf file based on environment variables
COPY ./generate-supervisor-conf.sh /generate-supervisor-conf.sh

RUN chmod 755 /docker-entrypoint.sh

EXPOSE 7000 7001 7002 7003 7004 7005 9000 9001 9002

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["redis-cluster"]
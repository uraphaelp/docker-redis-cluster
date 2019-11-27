FROM dockerhub.nie.netease.com/zhenghaowei/redis:4.0 

RUN mkdir /redis-conf
RUN mkdir /redis-data

COPY ./tmpl/redis-cluster.tmpl /redis-conf/redis-cluster.tmpl
COPY ./tmpl/redis.tmpl /redis-conf/redis.tmpl
COPY ./tmpl/sentinel.tmpl /redis-conf/sentinel.tmpl

# Add startup script
COPY ./docker-entrypoint.sh /docker-entrypoint.sh

# Add script that generates supervisor conf file based on environment variables
COPY ./generate-supervisor-conf.sh /generate-supervisor-conf.sh

RUN chmod 755 /docker-entrypoint.sh /redis-conf

#RUN CLUSTER_ANNOUNCE_IP=$(ifconfig eth0 |grep inet|awk '{print $2}') envsubst < /redis-conf/redis-cluster.tmpl > /redis-conf/redis-cluster.tmpl && \
#    SENTINEL_ANNOUNCE_IP=$(ifconfig eth0 |grep inet|awk '{print $2}') envsubst < /redis-conf/sentinel.tmpl > /redis-conf/sentinel.tmpl

EXPOSE 7000 7001 7002 7003 7004 7005 7006 7007 5000 5001 5002

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["redis-up"]

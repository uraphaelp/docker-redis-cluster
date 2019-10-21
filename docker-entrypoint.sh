#!/bin/sh

if [ "$1" = 'redis-cluster' ]; then
    # Allow passing in cluster IP by argument or environmental variable
    IP="${2:-$IP}"

    if [ -z "$IP" ]; then # If IP is unset then discover it
        IP=$(hostname -I)
    fi

    echo " -- IP Before trim: '$IP'"
    IP=$(echo ${IP}) # trim whitespaces
    echo " -- IP Before split: '$IP'"
    IP=${IP%% *} # use the first ip
    echo " -- IP After trim: '$IP'"

    # Default to port 7000
    if [ -z "$INITIAL_PORT" ]; then
      INITIAL_PORT=7000
    else
      INITIAL_PORT=$INITIAL_PORT
    fi

    # Default to 3 masters
    if [  -z "$SLAVES_PER_MASTER" && "$SENTINEL"!="true" && "$STANDALONE"!="true" ]; then
      MASTERS=3
    elif [ -z "$MASTERS" && "$SENTINEL"="true" || "$STANDALONE"="true" ]; then
      MASTERS=1
    else
      MASTERS=$MASTERS
    fi

    # Default to 1 slave for each master
    if [ -z "$SLAVES_PER_MASTER" && "$SENTINEL"!="true" && "$STANDALONE"!="true" ]; then
      SLAVES_PER_MASTER=1
    elif [ -z "$SLAVES_PER_MASTER" && "$SENTINEL"="true" ]; then
      SLAVES_PER_MASTER=2
    elif [ -z "$SLAVES_PER_MASTER" && "$STANDALONE"="true" ]; then
      SLAVES_PER_MASTER=0
    else
      SLAVES_PER_MASTER=$SLAVES_PER_MASTER
    fi

    # TODO:当至少出现两种集群模式为 true 时，抛错


    max_port=$(($INITIAL_PORT + $MASTERS * ( $SLAVES_PER_MASTER  + 1 ) - 1))

    for port in $(seq $INITIAL_PORT $max_port); do
      mkdir -p /redis-conf/${port}
      mkdir -p /redis-data/${port}

      if [ -e /redis-data/${port}/nodes.conf ]; then
        rm /redis-data/${port}/nodes.conf
      fi

      if [ -e /redis-data/${port}/dump.rdb ]; then
        rm /redis-data/${port}/dump.rdb
      fi

      if [ -e /redis-data/${port}/appendonly.aof ]; then
        rm /redis-data/${port}/appendonly.aof
      fi

      if [ "$STANDALONE"="true" || "$SENTINEL"="true" ]; then
        PORT=${port} envsubst < /redis-conf/redis.tmpl > /redis-conf/${port}/redis.conf
      else
        PORT=${port} envsubst < /redis-conf/redis-cluster.tmpl > /redis-conf/${port}/redis.conf
        nodes="$nodes $IP:$port"
      fi

      if [ "$port" -lt $(($INITIAL_PORT + $MASTERS)) ]; then
        if [ "$SENTINEL" = "true" ]; then
          PORT=${port} SENTINEL_PORT=$((port + 2000)) envsubst < /redis-conf/sentinel.tmpl > /redis-conf/sentinel-${port}.conf
          cat /redis-conf/sentinel-${port}.conf
        fi
      fi

    done

    bash /generate-supervisor-conf.sh $max_port > /etc/supervisor/supervisord.conf

    supervisord -c /etc/supervisor/supervisord.conf
    sleep 3

    /redis/src/redis-cli --version | grep -E "redis-cli 3.0|redis-cli 3.2|redis-cli 4.0"

    #TODO: 针对 standalone 和 sentinel 避免创建 cluster
    # 针对不同版本创建，使用不同的创建工具
    if [ $? -eq 0 && "$SENTINEL"!="true" && "$STANDALONE"!="true" ]; then
      echo "Using old redis-trib.rb to create the cluster"
      echo "yes" | eval ruby /redis/src/redis-trib.rb create --replicas "$SLAVES_PER_MASTER" "$nodes"
    elif [ $? -ne 0 && "$SENTINEL"!="true" && "$STANDALONE"!="true" ]; then
      echo "Using redis-cli to create the cluster"
      echo "yes" | eval /redis/src/redis-cli --cluster create --cluster-replicas "$SLAVES_PER_MASTER" "$nodes"
    fi

    if [ "$STANDALONE"="true" ]; then
      for port in $(seq $INITIAL_PORT $(($INITIAL_PORT + $MASTERS))); do
        redis-server /redis-conf/${port}/redis.conf &
      done
    fi

    if [ "$SENTINEL" = "true" ]; then
      for port in $(seq $INITIAL_PORT $(($INITIAL_PORT + $MASTERS))); do
        redis-sentinel /redis-conf/sentinel-${port}.conf &
      done
    fi

    tail -f /var/log/supervisor/redis*.log
else
  exec "$@"
fi

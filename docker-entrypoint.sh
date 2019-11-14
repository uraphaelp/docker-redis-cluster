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

    # 端口
    if [ -z "$INITIAL_PORT" ]; then
      INITIAL_PORT=7000
    fi

    # masters 数量
    if [ -z "$MASTERS" ] && [ -z "$SENTINEL" ] && [ -z "$STANDALONE" ]; then
      MASTERS=3
    elif [ -z "$MASTERS" ] && [ "$SENTINEL" = "true" -o "$STANDALONE" = "true" ]; then
      MASTERS=1
    fi

    # slaves/master 数量
    if [ -z "$SLAVES_PER_MASTER" ] && [ -z "$SENTINEL" ] && [ -z "$STANDALONE" ]; then
      SLAVES_PER_MASTER=1
    elif [ -z "$SLAVES_PER_MASTER" ] && [ "$SENTINEL" = "true" ]; then
      SLAVES_PER_MASTER=2
    elif [ -z "$SLAVES_PER_MASTER" ] && [ "$STANDALONE" = "true" ]; then
      SLAVES_PER_MASTER=0
    fi

    # TODO:当至少出现两种集群模式为 true 时，抛错

    # 数据节点最大端口
    max_port=$(($INITIAL_PORT + $MASTERS * ( $SLAVES_PER_MASTER  + 1 ) - 1))
    echo "$INITIAL_PORT $max_port"
    for port in $(seq $INITIAL_PORT $max_port); do
      mkdir -p /redis-conf/${port}
      mkdir -p /redis-data/${port}

      if [ -e /redis-data/${port}/nodes.conf ]; then
        rm /redis-data/${port}/nodes.conf
      fi

      #if [ -e /redis-data/${port}/dump.rdb ]; then
      #  rm /redis-data/${port}/dump.rdb
      #fi

      #if [ -e /redis-data/${port}/appendonly.aof ]; then
      #  rm /redis-data/${port}/appendonly.aof
      #fi

      # 创建数据节点配置文件
      if [ "$STANDALONE" = "true" -o "$SENTINEL" = "true" ]; then
        PORT=${port} envsubst < /redis-conf/redis.tmpl > /redis-conf/${port}/redis.conf
        echo "here we are not in cluster"
      else 
        PORT=${port} envsubst < /redis-conf/redis-cluster.tmpl > /redis-conf/${port}/redis.conf
        nodes="$nodes 127.0.0.1:$port"
        echo "here we are in cluster"
      fi
        
      # 默认一个主节点起3个 sentinel
      if [ "$port" -le $(($INITIAL_PORT + $MASTERS -1)) ]; then
        if [ "$SENTINEL" = "true" ]; then
            for i in $(seq 0 2); do  
                id=$(($port + $i))
                PORT=${port} SENTINEL_PORT=$((port + 2000 + i)) envsubst < /redis-conf/sentinel.tmpl > /redis-conf/sentinel-${id}.conf
                cat /redis-conf/sentinel-${id}.conf
            done
        fi
      # 从节点  
      else
        if [ "$SENTINEL" = "true" ]; then
            NUM=$(($port - $INITIAL_PORT - $MASTERS + 1))
            MASTER_PORT=$(($NUM / $SLAVES_PER_MASTER + $NUM % $SLAVES_PER_MASTER - 1 + $INITIAL_PORT))  
            echo "slaveof 127.0.0.1 $MASTER_PORT" >> /redis-conf/${port}/redis.conf
        fi  
      fi

    done

    bash /generate-supervisor-conf.sh $max_port > /etc/supervisor/supervisord.conf

    supervisord -c /etc/supervisor/supervisord.conf
    sleep 3

    # 获取当前 redis 版本
    /redis/src/redis-cli --version | grep -E "redis-cli 3.0|redis-cli 3.2|redis-cli 4.0"

    # 创建 cluster 类型集群 
    if [ $? -eq 0 ] && [ -z "$STANDALONE" ] && [-z "$SENTINEL" ]; then
      echo "Using old redis-trib.rb to create the cluster"
      echo "yes" | eval ruby /redis/src/redis-trib.rb create --replicas "$SLAVES_PER_MASTER" "$nodes"
    elif [ $? -ne 0 ] && [ -z "$STANDALONE" ] && [ -z "$SENTINEL" ]; then
      echo "Using redis-cli to create the cluster"
      echo "yes" | eval /redis/src/redis-cli --cluster create "$nodes" --cluster-replicas "$SLAVES_PER_MASTER"
    fi

    # 创建单机类型集群
    if [ "$STANDALONE" = "true" ]; then
        for port in $(seq $INITIAL_PORT $(($INITIAL_PORT + $MASTERS -1))); do
        redis-server /redis-conf/${port}/redis.conf &
      done
    fi

    # 创建 sentinel 类型集群
    if [ "$SENTINEL" = "true" ]; then
      # 创建数据节点  
      for port in $(seq $INITIAL_PORT $max_port); do
        redis-server /redis-conf/${port}/redis.conf &
      done  
      # 创建 sentinel 节点
      for port in $(seq $INITIAL_PORT $(($INITIAL_PORT + $MASTERS -1))); do
          for i in $(seq 0 2); do
              id=$(($port + $i))  
              redis-sentinel /redis-conf/sentinel-${id}.conf &
          done
      done
    fi

    tail -f /var/log/supervisor/redis*.log
else
  exec "$@"
fi

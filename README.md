## 使用文档

### 工具简述

**如果你有这样的需求：**

* 方便开发和业务人员快速在本地创建各种类型的 redis 集群
* 节省宿主机资源：一个 redis 集群的各个 redis 服务（节点）运行在一个容器（的不同端口上）：

**我们提供这样的功能：**

* 创建不同类型的 redis 集群：包括单点、主从、sentinel类型、cluster类型
* 自定义集群参数：节点数量；master 和 slave 数量；服务端口
* 自定义 redis 配置（redis.conf）文件
* 容器数据持久化服务：可加载外部数据并在宿舍机上保留容器内部数据
* 保证非宿主机机器也可访问 redis 容器
* 不同 redis 版本的镜像：3.2，4.0，5.0（及各大版本的子版本）
* 无须反复构建镜像：提供基础镜像资源，可根据一次构建的镜像创建不同类型的 redis 集群容器

**项目结构**

* docker-compose.yml：docker-compose 配置文件。具体配置方法详见下述 *使用 docker-compose 创建集群*
* docker-entrypoint.sh：容器启动时在内部执行的脚本文件。一般不需要修改
* Dockerfile：构建镜像的基础文件。一般不需要修改
* generate-supervisor-conf.sh：supervisor 相关文件。一般不需要修改
* tmpl：包含 redis, sentinel 和 cluster 类型节点及集群的配置文件。如针对集群有特定需求，可以进行在构建镜像前进行修改

### 使用 *docker* 原生命令创建集群

**构建镜像**

* 镜像将会基于 Dockerfile 打包 generate-supervisor-conf.sh, docker-entrypoint.sh 及 tmpl 文件
* 使用 `docker build -t <tag_name> --build-arg redis_version=<version> Dockerfile` 命令构建
    * 使用 `-t <tag_name>` 参数为你创建的镜像打 tag
    * 使用 `--build-arg redis_version=<version>` 参数选择具体的 redis 版本；默认为5.0.5 
* 这将会为你创建一个定制了各种集群模式的特定版本 redis 镜像，后续可以通过不同命令或配置文件，创建不同的 redis 集群

**启动容器（启动 redis 服务）**

* 使用 `docker run --name=<NAME> -e <environment_list> <IMAGE_NAME>` 命令创建 
* 使用 `--name=<NAME>` 参数为你的容器命名
* 使用 `-e <environment_list>` 通过多参数定制你的集群：
    
    ```
    # 参数类型：
    IP：redis 动态调整集群对外服务地址；功能开发中，暂时不要修改
    STANDALONE：为 true 时创建单实例类型集群
    SENTINEL：为 true 时创建 sentinel 类型集群
    MASTERS：集群中 master 节点个数；standalone 和 sentinel 类型默认为1；cluster 类型默认为3
    SLAVE_PER_MASTER：每个 master 节点的从节点个数；sentinel 类型默认为2；cluster类型默认为1
    INITIAL_PORT：redis 集群容器内部初始端口；默认为7000；sentinel 节点默认为9000
    
    # 不带任何参数：这将会创建一个默认的 cluster 类型，包含3-master，3-slave；同时服务部署在容器内部7000-7005端口
    docker run <IMAGE_NAME> 
    # 运行一个单点 redis 服务：
    docker run --name=<NAME> -e STANDALONE=true <IMAGE_NAME>
    # 运行一个默认 sentinel 类型（1主2从；3sentinels）集群：
    docker run --name=<NAME> -e SENTINEL=true <IMAGE_NAME>
    # 调整主从节点数量：这将创建一个 sentinel 类型集群，其中包含2个 master；每个 master 1个 slave；同时3个 sentinel 节点 
    docker run --name=<NAME> -e SENTINEL=true MASTERS=2 SLAVE_PER_MASTER=1 <IMAGE_NAME>

    # 用配置文件替代命令行输入定制参数
    编辑好包含上述定制参数的配置文件FILE，如：
    STANDALONE:true
    MASTERS:2
    SLAVES_PER_MASTER:1
    INITIAL_PORT:5000
    使用如下命令启动集群:
    docker run --env-file=FILE <IMAGE_NAME>
    
    # 其他 docker 参数
    -d:容器运行在后台
    -p <宿主机端口>:<容器内部端口>：端口映射
    ```

**访问 redis 集群**

* 若未创建端口映射，需要通过 `docker exec -it <NAME> /bin/bash` 进入容器后，再执行 `redis-cli -p <对应端口>` 访问 redis 服务
* 若创建了端口映射，可以直接在宿主机上执行 `redis-cli -h <对应端口>`

**保证 redis 容器能够从外部访问**

* 当前创建的集群，无论是否开启端口映射，均只能够在宿主机上访问。为了能够在其他机器上访问到我们搭建的 redis 集群，可以通过

    ```
    docker run -d --network=host --name=<NAME> <IMAGE_NAME>
    # 这样的方式本质是通过容器共享宿主机网络，达到外部访问的目的
    ```

**停止并删除容器**

* 通过：

    ```
    docker stop <NAME>
    docker rm <NAME>
    ```
    
**挂载外部数据卷**

* 通过：

    ```
    docker run -v <宿主机目录>:<容器目录> 
    # 可以挂载本地数据或配置文件
    ```

### 使用 *docker-compose* 创建集群

* *docker-compose* 是一个用于快速定制和创建 docker 服务的工具，使用 .yaml 配置文件定义各项服务参数（如挂载数据卷，端口，其他环境变量），避免重复使用复杂的 docker 原生命令，从而更方便快速地构建镜像及创建容器
* *docker-compose* 的所有操作和指令本质上是读取 .yaml 配置文件，构建相应的镜像或启动容器，因此下述操作描述和 docker 原生指令有异曲同工之处，只作简单叙述

**构建镜像**

* 如果你已经通过 **docker 原生命令构建镜像**，那么可以直接进入下述**启动容器**步骤
* 编辑 docker-compose.yaml 文件（可以参照**docker 原生命令构建镜像---启动容器** 中 编辑配置文件替代定制参数的部分），执行：

    ```
    docker-compose build
    ```

**启动容器**

* 在 docker-compose.yaml 目录下执行：

    ```
    docker-compose up
    # 启动容器并进行端口映射
    ```

**停止服务**

* 在 docker-compose.yaml 目录下执行：

    ```
    docker-compose stop 
    ```

### *redis* 相关

**配置文件**

* 为方便快速搭建一个测试集群，导入本地数据，目前在项目配置文件中已加入两项参数：

    ```
    dir 
    # 数据存放目录
    dbfilename
    # 数据库文件名（rdb 文件）
    ```
* 其他更多参数定义和修改请参照：[redis 官方配置文件](http://download.redis.io/redis-stable/redis.conf)

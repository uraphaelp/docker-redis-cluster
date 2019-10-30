# *docker* 化 *redis* 集群

[项目地址](https://github.com/uraphaelp/docker-redis-cluster/tree/develop)
[原始项目地址](https://github.com/Grokzen/docker-redis-cluster)

## 快速/自动构建
构建镜像：

    make build
这将启动一个基本的 cluster 镜像，为你拷贝各种类型的配置文件，设置环境变量等；
后续的各种类型容器均可以基于该镜像生成

启动容器：

    make up
这将调用 `docker-compose up` 指令创建一个默认的 6 节点(3主3从) cluster 容器；并对外映射 7000-7005 端口
将 **docker-compose.yml** 文件中对应的集群类型，修改为 `true` 能够创建不同的集群：
其中：

* `STANDALONE`： 创建一个单点类型
* `SENTINEL`： 创建一个默认的 sentinel 类型(1主2从，3 sentinels)

停止容器：

    make down
  
 compose file 参数说明：

* `IP`：集群 IP；默认将自动通过 `hostname -I` 获取容器 IP
* `INITIAL_PORT` ：集群节点的初始端口；默认为7000；非 sentinel 节点将依次递增
* `MASTERS`：集群 master 数量；其中 cluster 类型为3；sentinel 和 standalone 类型均为1
* `SLAVES_PER_MASTER`：单个 master 的 slave 数量；其中 cluster 类型为1；sentinel 类型为2；standalone 类型为0

数据持久化：


## 通过 *docker* 命令手动构建

构建镜像：

* 通过 `docker build Dockerfile` 获得的镜像与通过 `make` 和 `docker-compose build` 完全相同

启动容器：

    docker run -d -p 7000-7001:5000-5001 -e STANDALONE=true -e INITIAL_PORT=5000 -e MASTERS=2 --name=<name> <imageID>
    
    # 后台运行一个包含了2个单点 redis 实例的容器：分别跑在 docker 的 5000 和 5001 端口，并将其映射到本地 7000 和 7001 端口
    # 该容器名为 name  
 其他类型启动同理可得
 
 值得注意的是：可以将命令行多个 `-e` 携带的参数整理在 `env.txt` 的环境变量文件中，替换命令行参数为 `--env-file=env.txt` 即可

数据持久化：

    docker run -v <本地目录>:<容器内目录>
本地或容器内部的数据改变都会同步到对方的文件系统中
值得注意的是：建议不要直接在 Dockerfile 中通过 `VOLUME` 关键字挂载数据卷

* 每次需要更换本地数据文件路径时，都需要重新构建镜像，效率太低
* 在镜像中间层导入外部文件，使得构建速度下降，中间层过大

## 项目其他文件说明

* `./tmpl/*.tmpl`：各种集群类型的配置文件；可以根据需求自行修改（`docker build` 时3种类型的配置文件都会拷贝到镜像中）

*  Dockerfile：内容已经根据机房网络环境进行了诸如：apt 源，gem 源等的修改；无特殊需求时尽量不要编辑这个文件，否则会导致因网络原因无法构建镜像

* docker-entrypoint.sh：指定容器启动时的参数和一些环境变量；建议不要修改，否则有可能导致端口冲突，节点类型生成错误

* [项目参考地址](https://github.com/Grokzen/docker-redis-cluster)

## 待完成事项

* 暂不支持自定义 sentinel 节点数量，开发中

* 暂不支持自定义 sentinel 监控多个主从集群，开发中

* 暂不支持一键启动多个 sentinel 类型集群，需要构建一个默认集群后，使用 `docker exec -it <containerID> /bin/bash` 进入容器，手动构建
# ZCash miner

Check out the [rootio/zcash-miner](https://hub.docker.com/r/rootio/zcash-miner/) repository on Docker Hub.

Install the required packages. (**important**: need docker >= v1.12)
```shell
$ brew install docker awscli
```

Create a `config.conf` then run the commands below.
```shell
$ export AWS_ACCESS_KEY_ID=
$ export AWS_SECRET_ACCESS_KEY=
```

Generate the swarm cluster.
```shell
$ bash generateCluster.sh
```

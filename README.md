#Multi-host Cassandra

> Note: This demo uses Flocker, Docker, Docker Swarm, Docker Compose. Docker and Docker Swarm are configured with OVERLAY networking.

> Note: This demo assume you already have the above cluster running.

## Create resources needed for this demo

Create an overlay network
```
docker network create --driver overlay --subnet=192.168.0.0/24 overlay-net
```

Create Docker volumes backed by Flocker
```
docker volume create -d flocker --name=testvol1 -o size=10G
docker volume create -d flocker --name=testvol2 -o size=10G
docker volume create -d flocker --name=testvol3 -o size=10G
```

Use the following `docker-compose.yml` (aslo in the repo)
```
version: '2'
services:
  cassandra-1:
    image: cassandra
    container_name: cassandra-1
    environment:
      CASSANDRA_BROADCAST_ADDRESS: "cassandra-1"
    ports:
    - 7000
    volumes:
    - "cassandra1:/var/lib/cassandra"
    restart: always
  cassandra-2:
    image: cassandra
    container_name: cassandra-2
    environment:
      CASSANDRA_BROADCAST_ADDRESS: "cassandra-2"
      CASSANDRA_SEEDS: "cassandra-1"
    ports:
    - 7000
    depends_on:
      - cassandra-1
    volumes:
    - "cassandra2:/var/lib/cassandra"
    restart: always
  cassandra-3:
    image: cassandra
    container_name: cassandra-3
    environment:
      CASSANDRA_BROADCAST_ADDRESS: "cassandra-3"
      CASSANDRA_SEEDS: "cassandra-1"
    ports:
    - 7000
    depends_on:
      - cassandra-2
    volumes:
    - "cassandra3:/var/lib/cassandra"
    restart: always

volumes:
  cassandra1:
    external:
        name: testvol
  cassandra2:
    external:
        name: testvol4
  cassandra3:
    external:
        name: testvol5

networks:
  default:
    external:
       name: ryan-net
```

### Restart is always because

Swarm starts containers quickly, sometimes too quickly for cassandra where you might see this error.
To avoid this, we make sure the containers try to restart, which will make the bootstrap process recover.

```
encountered during startup: Other bootstrapping/leaving/moving nodes detected, cannot bootstrap while cassandra.consistent.rangemovement is true

WARN  20:42:19 Detected previous bootstrap failure; retrying
```

### Create the cluster

```
docker-compose -f cassandra-multi.yml up -d
Pulling cassandra-1 (cassandra:latest)...
ip-10-0-195-84: Pulling cassandra:latest... : downloaded
ip-10-0-57-22: Pulling cassandra:latest... : downloaded
Creating cassandra-1
Creating cassandra-3
Creating cassandra-2
```

The running containers
```
docker ps
CONTAINER ID        IMAGE                                    COMMAND                  CREATED             STATUS              PORTS                                                                 NAMES
75868663fc45        cassandra                                "/docker-entrypoint.s"   22 minutes ago      Up 22 minutes       7001/tcp, 7199/tcp, 9042/tcp, 9160/tcp, 10.0.195.84:32773->7000/tcp   ip-10-0-195-84/cassandra-2
cc5ee1fc0faa        cassandra                                "/docker-entrypoint.s"   22 minutes ago      Up 20 minutes       7001/tcp, 7199/tcp, 9042/tcp, 9160/tcp, 10.0.57.22:32775->7000/tcp    ip-10-0-57-22/cassandra-3
0d8ea530863f        cassandra                                "/docker-entrypoint.s"   22 minutes ago      Up 22 minutes       7001/tcp, 7199/tcp, 9042/tcp, 9160/tcp, 10.0.57.22:32773->7000/tcp    ip-10-0-57-22/cassandra-1
```

### Data is now in flocker

Checking on a node that is running two of our three cassandra nodes we can see the flocker volumes mounts and data inside them.

```
 df -h
Filesystem      Size  Used Avail Use% Mounted on
/dev/xvda1      7.8G  4.3G  3.1G  59% /
none            4.0K     0  4.0K   0% /sys/fs/cgroup
udev            3.7G   12K  3.7G   1% /dev
tmpfs           749M  384K  748M   1% /run
none            5.0M     0  5.0M   0% /run/lock
none            3.7G  264K  3.7G   1% /run/shm
none            100M     0  100M   0% /run/user
/dev/xvdb        30G   45M   28G   1% /mnt
/dev/xvdh       9.8G   24M  9.2G   1% /flocker/40948462-8d21-4165-b5d5-9c7d148016f3
/dev/xvdf        74G   53M   70G   1% /flocker/c2915fbb-7b85-4c58-9069-ce08ffb3e064
```

```
root@ip-10-0-57-22:~# ls /flocker/40948462-8d21-4165-b5d5-9c7d148016f3/
commitlog  data  hints  saved_caches
```

### Connect to cassandra cluster

```
docker run -it --rm --net=ryan-net cassandra sh -c 'exec cqlsh "cassandra-1"'
Connected to Test Cluster at cassandra-1:9042.
[cqlsh 5.0.1 | Cassandra 3.3 | CQL spec 3.4.0 | Native protocol v4]
Use HELP for help.
cqlsh>
```

Example commands
```
cqlsh> SHOW VERSION;
[cqlsh 5.0.1 | Cassandra 3.3 | CQL spec 3.4.0 | Native protocol v4]
cqlsh> SHOW HOST;
Connected to Test Cluster at cassandra-1:9042.
Improper SHOW command.
cqlsh> DESCRIBE CLUSTER;

Cluster: Test Cluster
Partitioner: Murmur3Partitioner
cqlsh> DESCRIBE TABLES;

Keyspace system_traces
----------------------
events  sessions

Keyspace system_schema
----------------------
tables     triggers    views    keyspaces  dropped_columns
functions  aggregates  indexes  types      columns

Keyspace system_auth
--------------------
resource_role_permissons_index  role_permissions  role_members  roles

Keyspace system
---------------
available_ranges          peers               paxos           range_xfers
batches                   compaction_history  batchlog        local
"IndexInfo"               sstable_activity    size_estimates  hints
views_builds_in_progress  peer_events         built_views

Keyspace system_distributed
---------------------------
repair_history  parent_repair_history
```

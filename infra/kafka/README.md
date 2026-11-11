# Kafka PoC

The base Compose configuration runs a single Apache Kafka 4.4.0 broker in KRaft
mode. Containers connect to `kafka:9092`. The development override adds an
external listener on `127.0.0.1:29092` and Kafbat UI at
`http://127.0.0.1:8083`.

## Start and verify

From the repository root:

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d
docker compose -f docker-compose.yml -f docker-compose.dev.yml ps
docker compose -f docker-compose.yml -f docker-compose.dev.yml exec kafka \
  /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --list
```

The broker creates `poc.ping` and `poc.ping.dlq` with one partition and
replication factor one. `kafka-init` exits successfully after topic creation.
Kafka's healthcheck uses the broker API, not a TCP port probe.

## Send and read a test message

Run the producer and paste a JSON event that follows
[`contracts/ping.v1.schema.json`](../../contracts/ping.v1.schema.json):

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml exec kafka \
  /opt/kafka/bin/kafka-console-producer.sh --bootstrap-server localhost:9092 --topic poc.ping
```

For example, paste:

```json
{"eventId":"4c8f73e2-f4b4-4c64-8d55-19300f0a0001","correlationId":"manual-test","occurredAt":"2026-11-11T13:00:00Z","payload":{"message":"ping"}}
```

In another terminal:

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml exec kafka \
  /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 \
  --topic poc.ping --from-beginning
```

The development UI lists the topics at `http://127.0.0.1:8083`. To inspect
container memory use:

```bash
docker stats --no-stream
```

## PoC environment

`KAFKA_BOOTSTRAP_SERVERS` defaults to `kafka:9092`. Compose gives each service
its own consumer group using `KAFKA_GROUP_ID_USUARIOS`,
`KAFKA_GROUP_ID_CASOS`, and `KAFKA_GROUP_ID_PARTIDAS`. Set
`KAFKA_POC_PING_ON_START=true` in the local `.env` to make all three services
publish one ping after connecting; the shared development default is `false`.
Each service starts independently of Kafka health and retries its connection
in the background, so the HTTP health checks do not depend on Kafka.

The official Kafka image is pinned to `apache/kafka:4.4.0`; its KRaft and
listener settings follow the [Apache Kafka Docker example](https://github.com/apache/kafka/blob/trunk/docker/examples/docker-compose-files/single-node/plaintext/docker-compose.yml)
and [official quickstart](https://kafka.apache.org/quickstart/). The
development UI is pinned to `ghcr.io/kafbat/kafka-ui:v1.5.0`.

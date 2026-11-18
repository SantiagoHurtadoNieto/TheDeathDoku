# Kafka local: eventos de partida y PoC

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

`kafka-init` creates these single-partition, replication-factor-one topics:

- `matches.finished.v1`: durable outbox publisher in partidas to idempotent
  result consumer in usuarios.
- `matches.finished.dlq`: failed `MatchFinished` events after three attempts.
- `matches.saga.confirmed.v1`: confirmation or cancellation returned to partidas.
- `poc.ping` and `poc.ping.dlq`: independent broker smoke-test.

The one-broker topology is for local development, not high availability.
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

## Event flow and failure walkthrough

Use the application to finish a CLASSIC, TIMED or VERSUS match. The partidas
service atomically stores `sagaStatus=PENDING` and the `MatchFinished` payload
in Redis. Its outbox worker publishes it even after a broker restart. The
usuarios consumer stores results and achievements in one PostgreSQL transaction
and emits a confirmation. Partidas applies ranking and history once, then the
Godot board displays the confirmed result. Poll `GET
/partidas/matches/{matchId}/saga` through the gateway to see `PENDING`,
`CONFIRMED` or `CANCELLED`.

Useful evidence while demonstrating:

```powershell
docker compose logs --since=10m partidas-service usuarios-service
docker compose exec kafka /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --list
docker compose exec kafka /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic matches.finished.v1 --from-beginning
docker compose exec kafka /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic matches.finished.dlq --from-beginning
```

Success evidence is a `MatchFinished published` log followed by `MatchFinished
procesado`, both with the same `correlationId`, then a `CONFIRMED` transition.
Repeat delivery with the same `matchId`: users replays the persisted result and
does not award XP or achievements twice.

To demonstrate a recoverable failure, stop PostgreSQL briefly while a match
event is being consumed, then restore it before the consumer exhausts its
initial attempt and two retries. Delivery recovers and the saga becomes
`CONFIRMED`. For the terminal failure path, keep PostgreSQL unavailable until
those three attempts are exhausted (about two seconds with the local policy):
the original event appears in `matches.finished.dlq`, usuarios emits
`CANCELLED`, partidas records the transition, and Grafana's DLQ panel increases.
Restore PostgreSQL afterwards; a cancelled saga is not replayed automatically.

## PoC environment

`KAFKA_BOOTSTRAP_SERVERS` defaults to `kafka:9092`. Compose gives each service
its own consumer group using `KAFKA_GROUP_ID_USUARIOS`,
`KAFKA_GROUP_ID_CASOS`, and `KAFKA_GROUP_ID_PARTIDAS`. Set
`KAFKA_POC_PING_ON_START=true` in the local `.env` to make all three services
publish one ping after connecting; the shared development default is `false`.
Partidas and casos retry their independent ping consumers in the background.
Partidas also owns the business outbox publisher and saga outcome consumer;
usuarios owns the business result consumer and dead-letter outcome publisher.
HTTP health checks do not depend on Kafka, so monitor the saga and consumer
metrics when the broker is unavailable.

The official Kafka image is pinned to `apache/kafka:4.4.0`; its KRaft and
listener settings follow the [Apache Kafka Docker example](https://github.com/apache/kafka/blob/trunk/docker/examples/docker-compose-files/single-node/plaintext/docker-compose.yml)
and [official quickstart](https://kafka.apache.org/quickstart/). The
development UI is pinned to `ghcr.io/kafbat/kafka-ui:v1.5.0`.

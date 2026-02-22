# ADR-001: Event Bus Selection

**Status:** Proposed
**Date:** 2026-02-22
**Deciders:** dc-sim team

---

## Context

Multiple services (sim-engine, cmdb, drift-detector, itsm, patch-manager) need to communicate asynchronously via events. We need an event bus that:

1. Supports pub/sub with multiple consumers per topic.
2. Has persistent message delivery (consumers can replay events on restart).
3. Is easy to run locally in Docker Compose.
4. Has good client library support.

## Options Considered

### Option A: NATS + JetStream
- Lightweight, high performance.
- JetStream provides persistence and replay.
- Good Go/Python/Node clients.
- Simple Docker deployment.

### Option B: Redis Streams
- Most teams already have Redis for other purposes.
- Built-in consumer groups (like Kafka).
- Message persistence configurable.
- Slightly more complex consumer group management.

### Option C: Apache Kafka
- Industry standard, extremely reliable.
- Heavy to run locally (requires ZooKeeper or KRaft).
- Overkill for this simulation scale.

## Decision

**Use Redis Streams** (Option B).

Redis is already needed for drift-detector ephemeral state. Using it as the event bus avoids an additional infrastructure dependency. Redis Streams consumer groups provide sufficient reliability for this project's scale.

## Consequences

- All services that produce or consume events depend on Redis.
- Event schema must be documented in each producing service's spec.
- Stream retention configured to 24h for dev, 7 days for staging/prod.

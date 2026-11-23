# Session 5: Kafka on GKE
The log at the heart of the speed layer

**Date:** 2026-11-25, 16:30–19:00

## Goals
By the end of this session you can:
- Explain Kafka as a log: topics, partitions and offsets, and how a key keeps one shipment's events in order.
- Explain replication, in-sync replicas and acks, and what happens when a broker fails.
- Use consumer groups, read consumer lag, and replay a topic by resetting offsets.
- Set a Kafka topic's retention long enough to replay the whole log, about 30 days: a later session rebuilds a table by replaying it.
- Run Kafka on Kubernetes with an operator (Strimzi), and compare it with managed Kafka services.

You leave with a three-broker Kafka cluster on your GKE cluster, and ocean events flowing into it.

## Materials
- [Slides](slides/)
- [Workshop](workshop.md)
- [Starter code](starter/)

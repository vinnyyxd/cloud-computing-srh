# Session 6: Pub/Sub and App Engine
Managed messaging and serverless ingestion for air events

**Date:** 2026-11-30, 16:30–19:00

## Goals
By the end of this session you can:
- Explain how Pub/Sub works: topics and subscriptions, pull, push and BigQuery subscriptions, acks and redelivery.
- Explain Pub/Sub's delivery guarantees, ordering keys and dead-letter topics, and handle duplicates by deduplicating on an event ID.
- Compare Pub/Sub with Kafka on cost, operations, ordering and replay, and choose between them.
- Explain serverless compute, compare App Engine with Cloud Run, and deploy a webhook on App Engine.
- Land a live stream in BigQuery without writing a pipeline.

You leave with air events flowing from a carrier webhook on App Engine, through Pub/Sub, into BigQuery.

## Materials
- [Slides](slides/)
- [Workshop](workshop.md)
- [Starter code](starter/)

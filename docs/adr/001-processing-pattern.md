# ADR 001: Choose lightweight Lambda processing for Helix Pharma

## Status
Accepted

Date: 2026-11-23

## Context
Helix Pharma (SHP07) transports temperature-sensitive pharmaceuticals by air.

Its platform targets are:
- **Freshness:** 60 seconds for operational shipment updates.
- **Reliability:** 99% on-time arrivals on every lane.
- **Budget:** Maximum $60/month in cloud resources.

BigQuery analysis of 118 shipments shows that all three lanes miss the reliability target:

| Lane | On-time rate | Target |
|---|---:|---:|
| ICN → FRA | 97.0% | 99% |
| SIN → LHR | 97.6% | 99% |
| HKG → LAX | 97.7% | 99% |

AQL accounts for two late shipments and SKY for one. The platform needs timely carrier-specific monitoring, while historical reliability and daily freight-rate analysis can run in batch.

## Options considered

1. **Lambda:** Separate live and batch processing. Shipment events use Pub/Sub, Cloud Run and BigQuery; daily rate files use Cloud Storage and scheduled processing. Supports different freshness requirements but creates two processing paths.

2. **Kappa:** Process operational and historical data through one streaming architecture, using event replay for reprocessing. Simplifies the processing model but requires durable event retention and replay mechanisms. Daily rate files must also be converted into events or handled separately.

## Decision

We chose **a lightweight Lambda architecture**.

Live shipment events will flow through Pub/Sub and Cloud Run into BigQuery, supporting operational monitoring and delay alerts.

Daily carrier rate files will be stored in Cloud Storage and processed on a schedule into curated BigQuery tables.

We replace Kafka, Dataflow and Dataproc from the reference architecture with lighter managed components to reduce operational overhead and control costs.

This separates time-critical pharmaceutical shipment visibility from less urgent historical and financial analysis.

## Consequences

- **Cost:** Must remain below $60/month. Pub/Sub, Cloud Run, Cloud Storage and BigQuery are usage-based services. Actual monthly cost requires a workload estimate and pricing validation.
- **Freshness:** Live processing is designed for updates within 60 seconds; end-to-end latency must be measured before claiming compliance.
- **Complexity:** Two processing paths, separate monitoring and data consistency checks are required.
- **What gets harder:** Maintaining consistent definitions across live and historical data, handling late events, and replaying historical data across both paths.
- **Reliability:** Carrier-specific monitoring can identify problems sooner but cannot itself guarantee 99% on-time arrivals.

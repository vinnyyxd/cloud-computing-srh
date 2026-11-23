# Helix Pharma (SHP07) — Freight Reliability Metrics

## Launch customer

- Customer: Helix Pharma
- Shipper ID: SHP07
- Transport mode: Air freight
- Freshness target: 60 seconds
- Reliability target: 99% on-time arrivals on every lane
- Monthly cloud budget: $60

A shipment is considered on time if its actual arrival is
no more than 24 hours after its planned arrival.

## Delay per lane

| Lane | Trade lane | Shipments | Avg delay (hours) | On-time rate | Target | Status |
|---|---|---:|---:|---:|---:|---|
| ICN → FRA | Asia-Europe | 33 | 2.0 | 97.0% | 99% | FAIL |
| SIN → LHR | Asia-Europe | 42 | 1.3 | 97.6% | 99% | FAIL |
| HKG → LAX | Transpacific | 43 | 2.4 | 97.7% | 99% | FAIL |

Total shipments analyzed: 118
On-time shipments: 115
Overall on-time rate: 97.5% (rounded)

All three lanes fail the required 99% reliability target.

## Carrier-level reliability

| Lane | Carrier | Shipments | On-time rate | Late shipments |
|---|---|---:|---:|---:|
| HKG → LAX | AQL | 6 | 83.3% | 1 |
| HKG → LAX | FAL | 3 | 100.0% | 0 |
| HKG → LAX | MER | 20 | 100.0% | 0 |
| HKG → LAX | SKY | 14 | 100.0% | 0 |
| ICN → FRA | SKY | 7 | 85.7% | 1 |
| ICN → FRA | MER | 20 | 100.0% | 0 |
| ICN → FRA | FAL | 3 | 100.0% | 0 |
| ICN → FRA | AQL | 3 | 100.0% | 0 |
| SIN → LHR | AQL | 6 | 83.3% | 1 |
| SIN → LHR | FAL | 6 | 100.0% | 0 |
| SIN → LHR | MER | 20 | 100.0% | 0 |
| SIN → LHR | SKY | 10 | 100.0% | 0 |

## Key findings

1. All three lanes fall below the 99% reliability requirement.
2. Three of 118 shipments arrived more than 24 hours late.
3. AQL accounts for two late shipments.
4. SKY accounts for one late shipment.
5. MER and FAL have no late shipments in this sample.
6. Carrier sample sizes are limited; these results should not
   be interpreted as long-term carrier reliability guarantees.

## Architecture implications

- Operations data must be refreshed within 60 seconds.
- Carrier-specific delay monitoring is necessary.
- The platform should support alerts for delayed shipments.
- Historical analytics can be processed in batch where suitable.
- Cloud infrastructure must remain within $60 per month.
- Faster monitoring improves visibility but does not itself
  prevent carrier delays.

## Methodology

Source tables:
- freight.bookings
- freight.schedules

Bookings are joined to schedules using schedule_id.
Only bookings with matching schedule records are included.

Arrival delay is calculated using DATETIME_DIFF in hours.
On-time shipments have an arrival delay of at most 24 hours.

Metrics are based on the Session 3 workshop dataset.

# Launch customers

Your company sells one platform to many shippers. Your shipper is its launch customer: the first big contract, and its targets are what your company promised. Build the platform so it meets them.

From session 3 each of you has one of these seven shippers as your launch customer. They are the same seven shippers that appear in the generator's `bookings` data, with the same IDs, so you can filter your data by `shipper_id`.

I assign the launch customers in class: three students per shipper, 21 in all. You each build and defend your own design.

Every launch customer has three targets your platform must meet:

- **Freshness:** how far behind reality the operations view may be.
- **Reliability:** the minimum on-time rate on each lane the shipper uses. A shipment is on time if it arrived no more than 24 hours after its scheduled arrival.
- **Budget:** the most the shipper will pay per month for your platform's cloud resources, in US dollars.

Lanes are written origin to destination, with UN/LOCODE port codes for ocean and IATA airport codes for air.

## SHP01 · Alpine Outdoor

**Focus:** cost. **Modes:** ocean.

Sells outdoor gear and ships seasonal stock by sea; every dollar saved on freight goes back into the price tag.

**Lanes:** NLRTM → USHOU (Transatlantic) · KRPUS → USLGB (Transpacific) · CNNGB → DEHAM (Asia-North Europe) · GBFXT → CNSHA (North Europe-Asia)

| Target | Value |
|---|---|
| Freshness | 15 minutes |
| Reliability | 55% on time on every lane |
| Budget | $20 per month |

## SHP02 · Nordic Home

**Focus:** reliability. **Modes:** ocean.

A furniture chain whose new store openings are planned around container arrivals; a late ship means an empty showroom on opening day.

**Lanes:** NLRTM → USHOU (Transatlantic) · DEHAM → USNYC (Transatlantic) · KRPUS → USLGB (Transpacific) · SGSIN → BEANR (Asia-North Europe)

| Target | Value |
|---|---|
| Freshness | 1 hour |
| Reliability | 75% on time on every lane |
| Budget | $45 per month |

## SHP03 · Brightwave Electronics

**Focus:** reliability. **Modes:** air.

Flies new devices to market for launch days that were announced months ago; missing one makes the news.

**Lanes:** PVG → ORD (Transpacific) · DXB → FRA (Middle East-Europe) · SIN → LHR (Asia-Europe)

| Target | Value |
|---|---|
| Freshness | 5 minutes |
| Reliability | 98% on time on every lane |
| Budget | $35 per month |

## SHP04 · Greenleaf Foods

**Focus:** balanced. **Modes:** ocean.

Imports and exports packaged food with a limited shelf life, so warehouse teams re-plan the moment a vessel slips.

**Lanes:** GBFXT → CNSHA (North Europe-Asia) · CNSHA → NLRTM (Asia-North Europe) · NLRTM → USHOU (Transatlantic) · CNYTN → USLAX (Transpacific)

| Target | Value |
|---|---|
| Freshness | 60 seconds |
| Reliability | 65% on time on every lane |
| Budget | $30 per month |

## SHP05 · Vertex Auto Parts

**Focus:** balanced. **Modes:** ocean and air.

Supplies car factories that run just in time: parts go by sea, and by air when a production line is about to stop.

**Lanes:**
- Ocean: SGSIN → BEANR (Asia-North Europe) · NLRTM → USHOU (Transatlantic) · CNSHA → ITGOA (Asia-Mediterranean) · CNNGB → DEHAM (Asia-North Europe)
- Air: DXB → FRA (Middle East-Europe) · ICN → FRA (Asia-Europe) · HKG → AMS (Asia-Europe)

| Target | Value |
|---|---|
| Freshness | 2 minutes |
| Reliability | 65% on time on every ocean lane, 95% on every air lane |
| Budget | $50 per month |

## SHP06 · Coastline Fashion

**Focus:** cost. **Modes:** ocean and air.

A fashion brand that ships most stock by sea and flies only the pieces that are selling fast; margins are thin.

**Lanes:**
- Ocean: CNSHA → ITGOA (Asia-Mediterranean) · SGSIN → BEANR (Asia-North Europe) · DEHAM → USNYC (Transatlantic) · GBFXT → CNSHA (North Europe-Asia)
- Air: PVG → FRA (Asia-Europe) · SIN → LHR (Asia-Europe) · ICN → FRA (Asia-Europe)

| Target | Value |
|---|---|
| Freshness | 30 minutes |
| Reliability | 60% on time on every ocean lane, 90% on every air lane |
| Budget | $25 per month |

## SHP07 · Helix Pharma

**Focus:** reliability. **Modes:** air.

Flies temperature-controlled medicines to hospitals and distributors; every delay is a quality and patient-safety question.

**Lanes:** ICN → FRA (Asia-Europe) · HKG → LAX (Transpacific) · SIN → LHR (Asia-Europe)

| Target | Value |
|---|---|
| Freshness | 60 seconds |
| Reliability | 99% on time on every lane |
| Budget | $60 per month |

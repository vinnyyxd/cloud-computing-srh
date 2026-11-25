# Workshop: air events through Pub/Sub

**Time:** about 80 minutes, on your own, in Cloud Shell. You need the `freight` BigQuery dataset from session 2. You don't need your GKE cluster today: leave it at zero nodes.

Ocean events go through Kafka, which you run yourself. Air events take the managed path: airlines call a webhook on App Engine, which publishes to Pub/Sub, and Pub/Sub writes straight into BigQuery.

## 1. Create your App Engine app (5 min)

Get today's material first, and check Terraform:

```bash
cd ~/cloud-computing-srh && git pull upstream main
terraform version                              # should print Terraform v1.9.8
```

If `terraform version` prints installation instructions instead of a version, follow tip 3 in the [Cloud Shell tips](../../setup/gcp.md#cloud-shell-tips) before step 2. Without a real Terraform, `terraform apply` looks as if it worked but creates nothing.

> **Read this before you run the next command.** An App Engine app's region is permanent: you can't change it, and you can't delete the app. Make sure it says `europe-west3`.

```bash
gcloud app create --region=europe-west3
gcloud app describe --format="value(locationId)"
```

If `gcloud app create` asks to enable the App Engine Admin API, answer `y`. If `describe` then says there's no application, wait a minute and run it again.

This also creates the App Engine default service account, `<project-id>@appspot.gserviceaccount.com`, which your webhook runs as.

## 2. Create the topics, subscriptions and table (10 min)

```bash
cd ~/cloud-computing-srh/sessions/06-pub-sub-and-app-engine/starter
cp terraform.tfvars.example terraform.tfvars   # set project_id
terraform init
terraform apply
```

Read the plan. It creates:

- a topic, `air-events`, that keeps messages for 7 days
- a pull subscription, `air-events-debug`, for you to read by hand, with ordering switched on and a dead-letter topic after 5 failed deliveries
- a table, `freight.air_events_raw`, and a **BigQuery subscription** that writes every message into it
- permissions: the webhook may publish to `air-events`, and Pub/Sub's own service agent may write to the table and the dead-letter topic

Open **Pub/Sub** in the console and find the topic and its three subscriptions. Every subscription gets its own copy of every message.

## 3. Finish and deploy the webhook (15 min)

Read `app/main.py`. It accepts one event per `POST /events`, checks the required fields, and publishes the event with the shipment ID as its **ordering key**, so each shipment's events arrive in order.

**Your turn:** ocean events belong on Kafka, not here. Finish the `TODO` so that an event whose `mode` isn't `AIR` gets a `400` with a clear error.

Then deploy it. The first deploy takes a few minutes, and sometimes fails with `an internal error has occurred`: run `gcloud app deploy --quiet` again.

```bash
cd app
gcloud app deploy --quiet
URL=$(gcloud app browse --no-launch-browser)
curl $URL/
```

Try it by hand, with one good event and one bad one:

```bash
curl -i -X POST $URL/events -H "Content-Type: application/json" \
  -d '{"event_id":"test-1","shipment_id":"TEST-1","event_type":"BOOKED","mode":"AIR"}'
curl -i -X POST $URL/events -H "Content-Type: application/json" \
  -d '{"event_id":"test-2","shipment_id":"TEST-2","event_type":"BOOKED","mode":"OCEAN"}'
```

The first returns `202` and a Pub/Sub message ID. The second should return your `400`.

## 4. Send air events (10 min)

Point the generator at your webhook. The HTTP sink needs no extra packages:

```bash
cd ~/cloud-computing-srh/event-generator
python3 -m generator stream --mode air --sink http --http-url $URL/events --rate 2 --count 200
```

While it runs, open a second Cloud Shell tab and pull a few messages from the debug subscription:

```bash
gcloud pubsub subscriptions pull air-events-debug --limit=5 --auto-ack
```

`--auto-ack` tells Pub/Sub you've handled them. Without an ack, Pub/Sub delivers the message again when the ack deadline runs out: 20 seconds here.

In the console, open **App Engine → Instances**. App Engine started an instance when the first request came in, and stops it again when the traffic stops.

## 5. Query them in BigQuery (10 min)

The BigQuery subscription has been writing every message into `freight.air_events_raw`. In the BigQuery console:

```sql
SELECT
  JSON_VALUE(data, '$.event_type') AS event_type,
  COUNT(*) AS events
FROM freight.air_events_raw
GROUP BY event_type
ORDER BY events DESC;
```

How long did each event take from the airline to BigQuery? The event carries when it happened, and Pub/Sub records when it arrived:

```sql
SELECT
  JSON_VALUE(data, '$.shipment_id') AS shipment_id,
  JSON_VALUE(data, '$.event_type') AS event_type,
  TIMESTAMP_DIFF(publish_time, TIMESTAMP(JSON_VALUE(data, '$.event_time')), MILLISECOND) AS delay_ms
FROM freight.air_events_raw
ORDER BY publish_time DESC
LIMIT 20;
```

That's event time against processing time, from session 3, in one query.

## 6. Duplicates (10 min)

Carriers send some events twice. Ask the generator to do the same, for one event in ten:

```bash
python3 -m generator stream --mode air --sink http --http-url $URL/events --rate 5 --count 200 --duplicates 0.1
```

Then count:

```sql
SELECT
  COUNT(*) AS messages,
  COUNT(DISTINCT message_id) AS pubsub_message_ids,
  COUNT(DISTINCT JSON_VALUE(data, '$.event_id')) AS distinct_events
FROM freight.air_events_raw
WHERE publish_time > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 15 MINUTE);
```

The 15 minutes may include some of step 4's events too, so the totals can be bigger than 200. What matters is the gap: `messages` minus `distinct_events` is the number of duplicates.

Every duplicate got its own Pub/Sub message ID: Pub/Sub can't tell that two messages carry the same event. Only the `event_id` can. Pub/Sub can also redeliver a message of its own accord (at-least-once delivery), so whatever reads this stream must deduplicate on `event_id`. That's being idempotent, from session 3.

## 7. Replay with seek (5 min)

Your debug subscription keeps acknowledged messages for 7 days. Rewind it by 10 minutes, and messages you've already acked come back:

```bash
gcloud pubsub subscriptions seek air-events-debug \
  --time=$(date -u -d '-10 minutes' +%Y-%m-%dT%H:%M:%SZ)
gcloud pubsub subscriptions pull air-events-debug --limit=5 --auto-ack
```

Compare it with Wednesday's `--reset-offsets` in Kafka. Same idea, but in Pub/Sub you have to set up retention before you need it. In Kafka, keeping the log is the default.

## Checkpoint

Your fork contains:

- your finished `app/main.py`
- `docs/pubsub.md`, with:
  - your webhook URL, and the response to the bad (`OCEAN`) request
  - the output of the duplicates query in step 6
  - three or four sentences: for your launch customer's air events, would you keep Pub/Sub, or send them through Kafka like ocean events? Think about cost, effort, ordering and replay.

```bash
cd ~/cloud-computing-srh
git add sessions/06-pub-sub-and-app-engine/starter/app docs/pubsub.md
git commit -m "Session 6: air events through Pub/Sub"
git push origin main
```

## Stretch

- **Dead letters.** Start from an empty debug subscription with one new event in it. Seeking to now marks everything older as acked:

  ```bash
  gcloud pubsub subscriptions seek air-events-debug --time=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  curl -X POST $URL/events -H "Content-Type: application/json" \
    -d '{"event_id":"dl-1","shipment_id":"DL-1","event_type":"BOOKED","mode":"AIR"}'
  gcloud pubsub subscriptions pull air-events-debug --limit=1      # no --auto-ack
  ```

  Don't ack it. Wait for the 20-second ack deadline and pull again: it's the same message, and `DELIVERY_ATTEMPT` goes up by one. After the fifth delivery it stops coming back. Find it with `gcloud pubsub subscriptions pull air-events-dead-letter-debug --auto-ack`. Why would you want undeliverable messages kept somewhere, rather than retried for ever or thrown away?
- **Two versions at once.** Change the webhook (for example, add a `received_at` timestamp to each event), and deploy it without moving traffic: `gcloud app deploy --no-promote --version v2 --quiet`. Then send 10% of traffic to it: `gcloud app services set-traffic default --splits <old-version>=0.9,v2=0.1 --split-by=random`. For `<old-version>`, run `gcloud app versions list` and take the one with `TRAFFIC_SPLIT` `1.00`; a failed deploy can leave extra versions in the list. Without `--split-by=random`, App Engine splits by IP address, and every request from your Cloud Shell goes to the same version. Send 50 events, and count in BigQuery how many have a `received_at`: about one in ten. This is a canary release.
- **ADR 002.** Write `docs/adr/002-air-events-messaging.md`: Kafka or Pub/Sub for your launch customer's air events.

## Teardown

Nothing from today bills by the hour. App Engine scales back to zero when the requests stop, and Pub/Sub and BigQuery charge only for what they handle and store. Stop the generator with **Ctrl+C** if it's still running.

Check your GKE cluster is still at zero nodes from Wednesday:

```bash
gcloud compute instances list --filter="name~^gke-freight"
```

An empty list means zero nodes; gcloud may add a warning that the filter keys "were not present in any resource", which only means there was nothing to list. If a VM is listed, run `terraform apply -var node_count=0` in `sessions/04-docker-and-kubernetes-on-gke/starter`.

## If something goes wrong

- **`gcloud app create` says the project already contains an App Engine application**: you've created it before. `gcloud app describe` shows its region. If it isn't `europe-west3`, carry on anyway, and note in your ADR that the webhook runs in another region.
- **Terraform: `Service account <project-id>@appspot.gserviceaccount.com does not exist`**: you skipped step 1. Run `gcloud app create`, then `terraform apply` again.
- **Terraform: `Service account service-...@gcp-sa-pubsub.iam.gserviceaccount.com does not exist`**: Google creates Pub/Sub's service agent a moment after the API is switched on. Wait a minute and run `terraform apply` again.
- **Terraform: `Not found: Dataset ...:freight`**: you haven't got session 2's dataset. Run session 2's `terraform apply` first.
- **`gcloud app deploy` fails on a build step with a permission error**: wait two minutes for the build permission to apply and try again. Terraform gives the build role to two accounts, `<number>-compute@developer.gserviceaccount.com` and `<project-id>@appspot.gserviceaccount.com`, because Google builds as one or the other depending on the project's age. If the error names any other account, tell me which.
- **`gcloud app deploy` fails with `an internal error has occurred`**: run it again. It usually works the second time.
- **Terraform: `Service account <number>-compute@developer.gserviceaccount.com does not exist`**: your project has never used Compute Engine, so Google hasn't created that account yet. Your session 4 cluster normally creates it. Run `gcloud services enable compute.googleapis.com`, wait two minutes, and run `terraform apply` again.
- **The webhook returns `500` or `503`**: read its logs with `gcloud app logs tail -s default`. `PermissionDenied` means the publish permission hasn't applied yet; wait a minute.
- **Nothing in `air_events_raw`**: open the `air-events-to-bigquery` subscription in the console and check its state. If it complains about the table, check the table's columns weren't changed.
- **`pull` returns nothing**: the messages were already acked. Use `seek` (step 7), or send some more.

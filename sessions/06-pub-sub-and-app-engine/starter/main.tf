data "google_project" "this" {}

locals {
  # Google-managed identities that act inside your project.
  pubsub_agent = "serviceAccount:service-${data.google_project.this.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
  appengine_sa = "serviceAccount:${var.project_id}@appspot.gserviceaccount.com"
  compute_sa   = "serviceAccount:${data.google_project.this.number}-compute@developer.gserviceaccount.com"
  seven_days   = "604800s"
  labels = {
    course  = "cloud-computing-srh"
    session = "06"
  }
}

resource "google_project_service" "services" {
  for_each = toset([
    "pubsub.googleapis.com",
    "appengine.googleapis.com",
    "cloudbuild.googleapis.com",
    "bigquery.googleapis.com",
  ])
  service            = each.value
  disable_on_destroy = false
}

# ---------------------------------------------------------------- topics

# Where the webhook publishes air events. Keeping messages for 7 days lets a
# subscription seek back in time and replay them.
resource "google_pubsub_topic" "air_events" {
  name                       = "air-events"
  message_retention_duration = local.seven_days
  labels                     = local.labels
  depends_on                 = [google_project_service.services]
}

# Where messages go after too many failed deliveries.
resource "google_pubsub_topic" "dead_letter" {
  name       = "air-events-dead-letter"
  labels     = local.labels
  depends_on = [google_project_service.services]
}

# ---------------------------------------------------------- subscriptions

# A pull subscription for you to read from by hand.
resource "google_pubsub_subscription" "debug" {
  name                       = "air-events-debug"
  topic                      = google_pubsub_topic.air_events.id
  ack_deadline_seconds       = 20
  retain_acked_messages      = true
  message_retention_duration = local.seven_days
  enable_message_ordering    = true

  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.dead_letter.id
    max_delivery_attempts = 5
  }

  expiration_policy {
    ttl = "" # never expire
  }

  labels = local.labels
}

resource "google_pubsub_subscription" "dead_letter_debug" {
  name  = "air-events-dead-letter-debug"
  topic = google_pubsub_topic.dead_letter.id

  expiration_policy {
    ttl = ""
  }

  labels = local.labels
}

# The raw landing table for air events. Pub/Sub writes the message and its
# metadata; the event itself is in `data`, as JSON.
resource "google_bigquery_table" "air_events_raw" {
  dataset_id          = var.dataset_id
  table_id            = "air_events_raw"
  deletion_protection = false
  description         = "Air shipment events, written by the air-events-to-bigquery subscription"

  time_partitioning {
    type  = "DAY"
    field = "publish_time"
  }

  schema = jsonencode([
    { name = "subscription_name", type = "STRING" },
    { name = "message_id", type = "STRING" },
    { name = "publish_time", type = "TIMESTAMP" },
    { name = "attributes", type = "JSON" },
    { name = "data", type = "JSON" },
  ])

  labels = local.labels
}

# A BigQuery subscription: Pub/Sub writes every message straight into the
# table. No pipeline code at all.
resource "google_pubsub_subscription" "to_bigquery" {
  name  = "air-events-to-bigquery"
  topic = google_pubsub_topic.air_events.id

  bigquery_config {
    table          = "${google_bigquery_table.air_events_raw.project}.${google_bigquery_table.air_events_raw.dataset_id}.${google_bigquery_table.air_events_raw.table_id}"
    write_metadata = true
  }

  expiration_policy {
    ttl = ""
  }

  labels     = local.labels
  depends_on = [google_bigquery_table_iam_member.pubsub_writes_table]
}

# ------------------------------------------------------------------- IAM

# Pub/Sub's own service agent writes to the table ...
resource "google_bigquery_table_iam_member" "pubsub_writes_table" {
  project    = google_bigquery_table.air_events_raw.project
  dataset_id = google_bigquery_table.air_events_raw.dataset_id
  table_id   = google_bigquery_table.air_events_raw.table_id
  role       = "roles/bigquery.dataEditor"
  member     = local.pubsub_agent
  depends_on = [google_project_service.services]
}

# ... and moves undeliverable messages to the dead-letter topic.
resource "google_pubsub_topic_iam_member" "pubsub_publishes_dead_letters" {
  topic  = google_pubsub_topic.dead_letter.name
  role   = "roles/pubsub.publisher"
  member = local.pubsub_agent
}

resource "google_pubsub_subscription_iam_member" "pubsub_forwards_dead_letters" {
  subscription = google_pubsub_subscription.debug.name
  role         = "roles/pubsub.subscriber"
  member       = local.pubsub_agent
}

# The webhook runs as the App Engine default service account. It may publish
# to air-events, and to nothing else. The account exists once you have run
# `gcloud app create` (step 1).
resource "google_pubsub_topic_iam_member" "webhook_publishes" {
  topic  = google_pubsub_topic.air_events.name
  role   = "roles/pubsub.publisher"
  member = local.appengine_sa
}

# `gcloud app deploy` builds your app with Cloud Build, running as the Compute
# Engine default service account. Make sure it may build.
resource "google_project_iam_member" "build" {
  project    = var.project_id
  role       = "roles/cloudbuild.builds.builder"
  member     = local.compute_sa
  depends_on = [google_project_service.services]
}

# In newer projects Google doesn't give default service accounts any roles, and
# the build runs as the App Engine default service account instead. It needs
# the same role, or the deploy fails with "does not have access to the bucket".
resource "google_project_iam_member" "build_as_appengine" {
  project    = var.project_id
  role       = "roles/cloudbuild.builds.builder"
  member     = local.appengine_sa
  depends_on = [google_project_service.services]
}

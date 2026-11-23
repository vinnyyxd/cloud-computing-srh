output "topic" {
  value = google_pubsub_topic.air_events.id
}

output "debug_subscription" {
  value = google_pubsub_subscription.debug.name
}

output "table" {
  value = "${google_bigquery_table.air_events_raw.dataset_id}.${google_bigquery_table.air_events_raw.table_id}"
}

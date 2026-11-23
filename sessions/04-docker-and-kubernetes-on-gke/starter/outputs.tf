output "image_repo" {
  description = "Tag your images with this prefix, e.g. <image_repo>/generator:v1"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.freight.repository_id}"
}

output "get_credentials" {
  description = "Run this to point kubectl at your cluster"
  value       = "gcloud container clusters get-credentials ${google_container_cluster.freight.name} --zone ${var.zone} --project ${var.project_id}"
}

# The APIs this session needs. Terraform switches them on for you.
resource "google_project_service" "services" {
  for_each = toset([
    "compute.googleapis.com",
    "container.googleapis.com",
    "artifactregistry.googleapis.com",
  ])
  service            = each.value
  disable_on_destroy = false
}

# A private Docker registry for your images.
resource "google_artifact_registry_repository" "freight" {
  location      = var.region
  repository_id = "freight"
  format        = "DOCKER"
  description   = "Container images for the freight platform"

  labels = {
    course  = "cloud-computing-srh"
    session = "04"
  }

  depends_on = [google_project_service.services]
}

# The nodes run as their own service account with only what they need,
# not as the Compute Engine default account, which has Editor on the project.
resource "google_service_account" "nodes" {
  account_id   = "gke-nodes"
  display_name = "GKE nodes for the freight cluster"
}

resource "google_project_iam_member" "nodes" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/stackdriver.resourceMetadata.writer",
  ])
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.nodes.email}"
}

# The nodes may pull images from your registry, and nothing else.
resource "google_artifact_registry_repository_iam_member" "nodes_pull" {
  location   = google_artifact_registry_repository.freight.location
  repository = google_artifact_registry_repository.freight.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.nodes.email}"
}

# A Standard, zonal cluster. Google runs the control plane; you choose the nodes.
resource "google_container_cluster" "freight" {
  name     = "freight"
  location = var.zone

  # Start without the default node pool and add our own below, so the node
  # settings live in one place.
  remove_default_node_pool = true
  initial_node_count       = 1

  # Lets `terraform destroy` delete the cluster at the end of the module.
  deletion_protection = false

  release_channel {
    channel = "REGULAR"
  }

  # Lets pods act as a Google service account without key files (session 7).
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  resource_labels = {
    course  = "cloud-computing-srh"
    session = "04"
  }

  depends_on = [google_project_service.services]
}

resource "google_container_node_pool" "main" {
  name     = "main"
  cluster  = google_container_cluster.freight.id
  location = var.zone

  node_count = var.node_count

  node_config {
    machine_type    = var.machine_type
    disk_type       = "pd-balanced"
    disk_size_gb    = 30
    service_account = google_service_account.nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    resource_labels = {
      course  = "cloud-computing-srh"
      session = "04"
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  depends_on = [
    google_project_iam_member.nodes,
    google_artifact_registry_repository_iam_member.nodes_pull,
  ]
}

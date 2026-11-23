variable "project_id" {
  description = "Your GCP project ID"
  type        = string
}

variable "region" {
  description = "Region for the image registry"
  type        = string
  default     = "europe-west3"
}

variable "zone" {
  description = "Zone for the cluster. A zonal cluster is covered by GKE's free tier; a regional one is not."
  type        = string
  default     = "europe-west3-a"
}

variable "node_count" {
  description = "Nodes in the cluster. Set it to 0 at the end of each session; the cluster and its disks stay."
  type        = number
  default     = 1
}

variable "machine_type" {
  description = "Node size. e2-standard-4 is 4 vCPUs and 16 GB: enough for Kafka next session."
  type        = string
  default     = "e2-standard-4"
}

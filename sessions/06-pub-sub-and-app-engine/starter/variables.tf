variable "project_id" {
  description = "Your GCP project ID"
  type        = string
}

variable "region" {
  description = "Region for the provider; Pub/Sub topics themselves are global"
  type        = string
  default     = "europe-west3"
}

variable "dataset_id" {
  description = "The BigQuery dataset from session 2"
  type        = string
  default     = "freight"
}

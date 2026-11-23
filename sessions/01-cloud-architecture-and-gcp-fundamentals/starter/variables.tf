variable "project_id" {
  description = "Your GCP project ID, e.g. cc-anna-123456 (own account) or cc-anna-1234 (course account)"
  type        = string
}

variable "region" {
  description = "Where your resources live. europe-west3 is Frankfurt."
  type        = string
  default     = "europe-west3"
}

variable "neighbour_emails" {
  description = "Google account emails of neighbours"
  type        = list(string)
  default     = []
}

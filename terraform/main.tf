terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.20"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

# Configure the Google Cloud provider
provider "google" {
  project = var.gcp_project_id
  region  = "us-central1"

  # When using user credentials, you must specify a project for billing and quota.
  # This is a more robust way to set the quota project than the gcloud command.
  user_project_override = true
  billing_project       = var.gcp_project_id
}

# Define a variable for the project ID to avoid hardcoding it
# Pass the gcp_project_id value to the terraform command as: terraform plan -var="gcp_project_id=YOUR_PROJECT_ID"
variable "gcp_project_id" {
  type        = string
  description = "The GCP project ID to deploy resources into."
}

variable "gcs_location" {
  type        = string
  description = "The location for the GCS bucket. E.g., US-CENTRAL1 or US-MULTI-REGION."
  default     = "US-CENTRAL1"
}

# Use a different resource_prefix for different corpi. 
# AI corpus: asrr-ai-corpus
# Psychology dissertation corpus: asrr-psych-corpus
# Biblical scholar corpus: asrr-bib-corpus
variable "resource_prefix" {
  type        = string
  description = "A prefix to apply to resource names for uniqueness and identification."
  default     = "asrr-ai-corpus"
}

# It's best practice to explicitly enable the APIs your Terraform configuration will use.
resource "google_project_service" "discovery_engine" {
  project            = var.gcp_project_id
  service            = "discoveryengine.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "storage" {
  project            = var.gcp_project_id
  service            = "storage.googleapis.com"
  disable_on_destroy = false
}

# Use the random provider to ensure the GCS bucket name is globally unique.
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Define the Google Cloud Storage bucket to act as our Data Lake.
resource "google_storage_bucket" "corpus_bucket" {
  name          = "${var.resource_prefix}-${random_id.bucket_suffix.hex}"
  project       = var.gcp_project_id
  location      = var.gcs_location
  uniform_bucket_level_access = true
  force_destroy = false # Set to true for ephemeral dev environments

  # Ensure the Storage API is enabled before creating the bucket.
  depends_on = [google_project_service.storage]
}

# To grant permissions, we need the project number to construct the service agent's email.
data "google_project" "project" {
  project_id = var.gcp_project_id

  depends_on = [google_project_service.discovery_engine]
}

# Grant the Discovery Engine service agent permission to read from the GCS bucket.
# The service agent email format is service-<PROJECT_NUMBER>@gcp-sa-discoveryengine.iam.gserviceaccount.com
resource "google_storage_bucket_iam_member" "corpus_bucket_reader" {
  bucket = google_storage_bucket.corpus_bucket.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-discoveryengine.iam.gserviceaccount.com"
}

# Define the Discovery Engine data store.
resource "google_discovery_engine_data_store" "corpus_datastore" {
  project           = var.gcp_project_id
  location          = "global"
  display_name      = "${var.resource_prefix}-data-store"
  data_store_id     = "${var.resource_prefix}-data-store"
  industry_vertical = "GENERIC"
  solution_types    = ["SOLUTION_TYPE_SEARCH"]
  content_config    = "CONTENT_REQUIRED"

  # Ensure the Discovery Engine API is enabled before creating the data store.
  depends_on = [google_project_service.discovery_engine]
}

# Output the name of the GCS bucket for easy reference.
output "corpus_bucket_name" {
  description = "The globally unique name of the GCS bucket for the corpus."
  value       = google_storage_bucket.corpus_bucket.name
}

output "corpus_datastore_id" {
  description = "The ID of the Discovery Engine data store."
  value       = google_discovery_engine_data_store.corpus_datastore.data_store_id
}
resource "google_compute_instance" "default" {
  project      = "qwiklabs-gcp-02-6f760836ef50"
  zone         = "europe-west1-c"
  name         = "terraform"
  machine_type = "e2-medium"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

 READMY network_interface {
    network = "default"
  }
}
# Terraform Infrastructure Guide

This project automates the creation of a Google Compute Engine VM instance using Terraform.

## Prerequisites
- Google Cloud SDK installed and authenticated.
- Terraform installed.

## How to deploy
1. Initialize the Terraform directory:
   ```bash
   terraform init

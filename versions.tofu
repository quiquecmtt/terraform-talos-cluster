terraform {
  required_version = ">= 1.11.0"
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "2.8.0"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "0.10.1"
    }
  }
}



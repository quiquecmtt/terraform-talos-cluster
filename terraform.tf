terraform {
  required_version = ">= 1.10.3"
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "2.6.1"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "0.9.0"
    }
  }
}



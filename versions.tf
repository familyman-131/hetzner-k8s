terraform {
  required_version = ">= 1.5"

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.50"
    }
  }
}

# Токен берётся из переменной (или из env HCLOUD_TOKEN, если var не задана).
provider "hcloud" {
  token = var.hcloud_token
}

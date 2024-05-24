terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = ">= 0.87.0"
    }
  }
  # Хранение состояния k8s
  backend "s3" {
    endpoint   = "storage.yandexcloud.net"
    bucket     = "s3-std-ext-001-022-k8s"
    region     = "ru-central1"
    key        = "terraform.tfstate"

    skip_region_validation      = true
    skip_credentials_validation = true
  }
}

provider "yandex" {
  cloud_id  = var.yandex_cloud_id
  folder_id = var.yandex_folder_id
  zone      = var.yandex_zone_name
}

resource "yandex_vpc_network" "default" {
  name = "k8s-network"
}

resource "yandex_vpc_subnet" "default" {
  name           = "k8s-subnet"
  zone           = var.yandex_zone_name
  network_id     = yandex_vpc_network.default.id
  v4_cidr_blocks = ["10.2.0.0/16"]
} 

output "yandex_vpc_subnets" {
  description = "Yandex.Cloud Subnets map"
  value       = resource.yandex_vpc_subnet.default
}

resource "yandex_kubernetes_cluster" "default" {
  name                     = "my-k8s-cluster"
  network_id               = yandex_vpc_network.default.id
  service_account_id       = var.service_account_id
  node_service_account_id  = var.service_account_id

  master {
    version = "1.28"
    public_ip = false

    maintenance_policy {
      auto_upgrade = true
    }
    
    master_location {
      zone = var.yandex_zone_name    
    }
  }
}

resource "yandex_kubernetes_node_group" "default" {
  cluster_id = yandex_kubernetes_cluster.default.id
  name       = "k8s-node-group"
  version    = "1.28"
  instance_template {
    platform_id = "standard-v1"
    resources {
      memory = 4
      cores  = 2
    }
    boot_disk {
      type = "network-ssd"
      size = 50
    }
  }
  scale_policy {
    auto_scale {
      min = 1
      max = 3
      initial = 1
    }
  }
  allocation_policy {
    location {
      zone = var.yandex_zone_name
    }
  }
  deploy_policy {
    max_unavailable = 1
    max_expansion = 1
  }
  allowed_unsafe_sysctls = ["net.ipv4.tcp_tw_reuse", "net.ipv4.ip_local_port_range"]
}

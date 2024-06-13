terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = ">= 0.87.0"
    }
  }
  #   k8s
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

provider "kubernetes" {
  config_path = "~/.kube/config"
}

resource "yandex_iam_service_account" "myaccount" {
  name = "k8s-brezhnev-account"
}

resource "kubernetes_service_account" "admin_user" {
  metadata {
    name      = "admin-user"
    namespace = "kube-system"
  }
}

resource "kubernetes_cluster_role_binding" "admin_user" {
  metadata {
    name = "admin-user"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.admin_user.metadata[0].name
    namespace = kubernetes_service_account.admin_user.metadata[0].namespace
  }
}

resource "kubernetes_secret" "admin_user_token" {
  metadata {
    name      = "admin-user-token"
    namespace = kubernetes_service_account.admin_user.metadata[0].namespace
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account.admin_user.metadata[0].name
    }
  }
  type = "kubernetes.io/service-account-token"
}

#Создаем vpc сеть.
resource "yandex_vpc_network" "default" {
  name = "k8s-network"
}

resource "yandex_vpc_subnet" "default" {
  name           = "k8s-subnet"
  zone           = var.yandex_zone_name
  network_id     = yandex_vpc_network.default.id
  v4_cidr_blocks = ["10.2.0.0/16"]
#  route_table_id = yandex_vpc_route_table.route_table.id # добавлена маршрутизация
}

resource "yandex_kubernetes_cluster" "default" {
  name                     = "sharuman-k8s-cluster"
  network_id               = yandex_vpc_network.default.id
  service_account_id       = var.service_account_id
  node_service_account_id  = var.service_account_id

  master {
    version = "1.28"
    public_ip = true

    maintenance_policy {
      auto_upgrade = true
    }
    
    master_location {
      zone = var.yandex_zone_name
      subnet_id = yandex_vpc_subnet.default.id    
    }
    security_group_ids = [yandex_vpc_security_group.k8s-public-services.id]
  }
  
  
  depends_on = [
    yandex_resourcemanager_folder_iam_member.k8s-clusters-agent,
    yandex_resourcemanager_folder_iam_member.vpc-public-admin,
    yandex_resourcemanager_folder_iam_member.images-puller,
    yandex_resourcemanager_folder_iam_member.encrypterDecrypter
  ]
}

resource "yandex_resourcemanager_folder_iam_member" "k8s-clusters-agent" {
  # Сервисному аккаунту назначается роль "k8s.clusters.agent".
  folder_id = var.yandex_folder_id
  role      = "k8s.clusters.agent"
  member    = "serviceAccount:${yandex_iam_service_account.myaccount.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "vpc-public-admin" {
  # Сервисному аккаунту назначается роль "vpc.publicAdmin".
  folder_id = var.yandex_folder_id
  role      = "vpc.publicAdmin"
  member    = "serviceAccount:${yandex_iam_service_account.myaccount.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "images-puller" {
  # Сервисному аккаунту назначается роль "container-registry.images.puller".
  folder_id = var.yandex_folder_id
  role      = "container-registry.images.puller"
  member    = "serviceAccount:${yandex_iam_service_account.myaccount.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "encrypterDecrypter" {
  # Сервисному аккаунту назначается роль "kms.keys.encrypterDecrypter".
  folder_id = var.yandex_folder_id
  role      = "kms.keys.encrypterDecrypter"
  member    = "serviceAccount:${yandex_iam_service_account.myaccount.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "dnsEditor" {
  # Сервисному аккаунту назначается роль "dns.editor".
  folder_id = var.yandex_folder_id
  role      = "dns.editor"
  member    = "serviceAccount:${yandex_iam_service_account.myaccount.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "Editor" {
  # Сервисному аккаунту назначается роль "editor".
  folder_id = var.yandex_folder_id
  role      = "editor"
  member    = "serviceAccount:${yandex_iam_service_account.myaccount.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "load-balancerAdmin" {
  # Сервисному аккаунту назначается роль "load-balancer.admin".
  folder_id = var.yandex_folder_id
  role      = "load-balancer.admin"
  member    = "serviceAccount:${yandex_iam_service_account.myaccount.id}"
}

resource "yandex_vpc_security_group" "k8s-public-services" {
  name        = "k8s-public-services"
  description = "Правила группы разрешают подключение к сервисам из интернета. Примените правила только для групп узлов."
  network_id  = yandex_vpc_network.default.id
  ingress {
    protocol          = "TCP"
    description       = "Правило разрешает проверки доступности с диапазона адресов балансировщика нагрузки. Нужно для работы отказоустойчивого кластера Managed Service for Kubernetes и сервисов балансировщика."
    predefined_target = "loadbalancer_healthchecks"
    from_port         = 0
    to_port           = 65535
  }
  ingress {
    protocol          = "ANY"
    description       = "Правило разрешает взаимодействие мастер-узел и узел-узел внутри группы безопасности."
    predefined_target = "self_security_group"
    from_port         = 0
    to_port           = 65535
  }
  ingress {
    protocol          = "ANY"
    description       = "Правило разрешает взаимодействие под-под и сервис-сервис. Укажите подсети вашего кластера Managed Service for Kubernetes и сервисов."
    v4_cidr_blocks    = concat(yandex_vpc_subnet.default.v4_cidr_blocks)
    from_port         = 0
    to_port           = 65535
  }
  ingress {
    protocol          = "ICMP"
    description       = "Правило разрешает отладочные ICMP-пакеты из внутренних подсетей."
    v4_cidr_blocks    = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
  }
  ingress {
    protocol          = "TCP"
    description       = "Правило разрешает входящий трафик из интернета на диапазон портов NodePort. Добавьте или измените порты на нужные вам."
    v4_cidr_blocks    = ["0.0.0.0/0"]
    from_port         = 30000
    to_port           = 32767
  }
  ingress {
    protocol          = "TCP"
    description       = "Правило разрешает входящий трафик из интернета на порт 443."
    v4_cidr_blocks    = ["0.0.0.0/0"]
    from_port         = 443
    to_port           = 443
  }
  ingress {
    protocol          = "TCP"
    description       = "Правило разрешает входящий трафик из интернета на порт 80."
    v4_cidr_blocks    = ["0.0.0.0/0"]
    from_port         = 80
    to_port           = 80
  }
  ingress {
    protocol          = "TCP"
    description       = "Правило разрешает входящий трафик из интернета на порт 8080."
    v4_cidr_blocks    = ["0.0.0.0/0"]
    from_port         = 8080
    to_port           = 8080
  }
  ingress {
    protocol          = "TCP"
    description       = "Правило разрешает входящий трафик из интернета на порт 5050."
    v4_cidr_blocks    = ["0.0.0.0/0"]
    from_port         = 5050
    to_port           = 5050
  }
  ingress {
    protocol          = "TCP"
    description       = "Правило разрешает входящий трафик из интернета на порт 3100."
    v4_cidr_blocks    = ["0.0.0.0/0"]
    from_port         = 3100
    to_port           = 3100
  }
  ingress {
    protocol          = "TCP"
    description       = "Правило разрешает входящий трафик из интернета на порт 8081."
    v4_cidr_blocks    = ["0.0.0.0/0"]
    from_port         = 8081
    to_port           = 8081
  }
      
  egress {
    protocol          = "ANY"
    description       = "Правило разрешает весь исходящий трафик. Узлы могут связаться с Yandex Container Registry, Yandex Object Storage, Docker Hub и т. д."
    v4_cidr_blocks    = ["0.0.0.0/0"]
    from_port         = 0
    to_port           = 65535
  }
}



# добавление вертикального автомасштабирования
#resource "null_resource" "apply_vpa_crd" {
#  provisioner "local-exec" {
#    command = "kubectl apply -f vpa-crd.yaml"
#  }
#  depends_on = [yandex_kubernetes_cluster.default]
#}
#
#resource "null_resource" "apply_vpa" {
#  provisioner "local-exec" {
#    command = "kubectl apply -f vpa.yaml"
#  }
#  depends_on = [null_resource.apply_vpa_crd]
#}

#добавление группы нод
resource "yandex_kubernetes_node_group" "default" {
  cluster_id = yandex_kubernetes_cluster.default.id
  name       = "k8s-node-group"
  version    = "1.28"
  instance_template {
    platform_id = "standard-v1"
    resources {
      memory = 8
      cores  = 4
    }
    boot_disk {
      type = "network-ssd"
      size = 150
    }
    network_interface {
      subnet_ids = [yandex_vpc_subnet.default.id]
      nat = true
    }    
  }
  scale_policy {
    auto_scale {
      min = 1
      max = 4
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
  
  node_labels = {
    "app" = "frontend"
  }
}

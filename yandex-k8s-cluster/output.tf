output "yandex_vpc_subnets" {
  description = "Yandex.Cloud Subnets map"
  value       = resource.yandex_vpc_subnet.default
}

output "external_v4_endpoint" {
  description = "An IPv4 external network address that is assigned to the master."

  value = yandex_kubernetes_cluster.default.master[0].external_v4_endpoint
}

output "internal_v4_endpoint" {
  description = "An IPv4 internal network address that is assigned to the master."

  value = yandex_kubernetes_cluster.default.master[0].internal_v4_endpoint
}

#output "external_ip_address" {
#  value = flatten([for l in yandex_lb_network_load_balancer.default.listener : [for a in l.external_address_spec : a.address]])[0]
#}

output "cluster_ca_certificate" {
  description = <<-EOF
  PEM-encoded public certificate that is the root of trust for
  the Kubernetes cluster.
  EOF

  value = yandex_kubernetes_cluster.default.master[0].cluster_ca_certificate
}

output "cluster_id" {
  description = "ID of a new Kubernetes cluster."

  value = yandex_kubernetes_cluster.default.id
}

output "node_info" {
  description = "ID of a new Kubernetes cluster."

  value = yandex_kubernetes_node_group.default.id
}
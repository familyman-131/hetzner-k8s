# Приватная сеть: по ней ноды общаются между собой (kubelet <-> API server,
# etcd, трафик CNI между подами). Публичные IP остаются только для SSH/API
# снаружи и для исходящего трафика (apt, pull образов).
resource "hcloud_network" "this" {
  name     = "${var.cluster_name}-net"
  ip_range = var.network_cidr
}

resource "hcloud_network_subnet" "nodes" {
  network_id   = hcloud_network.this.id
  type         = "cloud"
  network_zone = var.network_zone
  ip_range     = var.nodes_subnet_cidr
}

# Spread placement group: Hetzner разнесёт VM по разным физическим хостам,
# чтобы падение одного гипервизора не уронило оба воркера сразу.
resource "hcloud_placement_group" "spread" {
  name = "${var.cluster_name}-spread"
  type = "spread"
}

resource "hcloud_ssh_key" "admin" {
  name       = "${var.cluster_name}-admin"
  public_key = file(pathexpand(var.ssh_public_key_path))
}

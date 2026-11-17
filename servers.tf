locals {
  # Фиксированные приватные IP: удобно для kubeadm (--apiserver-advertise-address)
  # и для /etc/hosts. .1 в подсети занят шлюзом Hetzner, поэтому начинаем с .10.
  cp_private_ip      = cidrhost(var.nodes_subnet_cidr, 10)
  worker_private_ips = [for i in range(var.worker_count) : cidrhost(var.nodes_subnet_cidr, 20 + i)]

  # Все ноды в /etc/hosts каждой ноды — имена резолвятся в приватные IP.
  hosts = merge(
    { "${var.cluster_name}-cp-1" = local.cp_private_ip },
    { for i, ip in local.worker_private_ips : "${var.cluster_name}-worker-${i + 1}" => ip }
  )

  common_labels = {
    cluster    = var.cluster_name
    managed-by = "terraform"
  }
}

resource "hcloud_server" "control_plane" {
  name               = "${var.cluster_name}-cp-1"
  server_type        = var.control_plane_type
  image              = var.image
  location           = var.location
  ssh_keys           = [hcloud_ssh_key.admin.id]
  firewall_ids       = [hcloud_firewall.control_plane.id]
  placement_group_id = hcloud_placement_group.spread.id
  labels             = merge(local.common_labels, { role = "control-plane" })

  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }

  network {
    network_id = hcloud_network.this.id
    ip         = local.cp_private_ip
  }

  user_data = templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
    kubernetes_minor = var.kubernetes_minor
    node_private_ip  = local.cp_private_ip
    hosts            = local.hosts
  })

  # Сервер должен создаваться только после подсети, иначе attach к сети падает.
  depends_on = [hcloud_network_subnet.nodes]

  lifecycle {
    # Изменение cloud-init не должно пересоздавать уже живую ноду кластера.
    ignore_changes = [user_data, image]
  }
}

resource "hcloud_server" "worker" {
  count = var.worker_count

  name               = "${var.cluster_name}-worker-${count.index + 1}"
  server_type        = var.worker_type
  image              = var.image
  location           = var.location
  ssh_keys           = [hcloud_ssh_key.admin.id]
  firewall_ids       = [hcloud_firewall.workers.id]
  placement_group_id = hcloud_placement_group.spread.id
  labels             = merge(local.common_labels, { role = "worker" })

  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }

  network {
    network_id = hcloud_network.this.id
    ip         = local.worker_private_ips[count.index]
  }

  user_data = templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
    kubernetes_minor = var.kubernetes_minor
    node_private_ip  = local.worker_private_ips[count.index]
    hosts            = local.hosts
  })

  depends_on = [hcloud_network_subnet.nodes]

  lifecycle {
    ignore_changes = [user_data, image]
  }
}

# ВАЖНО про Hetzner Cloud Firewall:
#   * фильтрует ТОЛЬКО публичный интерфейс (eth0). Трафик по private network
#     не фильтруется вообще — поэтому kubelet (10250), etcd (2379-2380),
#     VXLAN/Geneve/BGP от CNI между нодами ходят свободно и правил под них не нужно;
#   * если нет ни одного outbound-правила — весь исходящий трафик разрешён
#     (нужно для apt, pkgs.k8s.io, registry.k8s.io, docker hub);
#   * всё входящее, что не разрешено явно, — DROP.

resource "hcloud_firewall" "control_plane" {
  name = "${var.cluster_name}-cp"

  rule {
    description = "SSH"
    direction   = "in"
    protocol    = "tcp"
    port        = "22"
    source_ips  = var.admin_cidrs
  }

  rule {
    description = "Kubernetes API (kubectl с ноутбука)"
    direction   = "in"
    protocol    = "tcp"
    port        = "6443"
    source_ips  = var.admin_cidrs
  }

  rule {
    description = "ICMP (ping, PMTU discovery)"
    direction   = "in"
    protocol    = "icmp"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }
}

resource "hcloud_firewall" "workers" {
  name = "${var.cluster_name}-workers"

  rule {
    description = "SSH"
    direction   = "in"
    protocol    = "tcp"
    port        = "22"
    source_ips  = var.admin_cidrs
  }

  rule {
    description = "ICMP"
    direction   = "in"
    protocol    = "icmp"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }

  dynamic "rule" {
    for_each = var.expose_nodeports ? [1] : []
    content {
      description = "NodePort services"
      direction   = "in"
      protocol    = "tcp"
      port        = "30000-32767"
      source_ips  = var.admin_cidrs
    }
  }
}

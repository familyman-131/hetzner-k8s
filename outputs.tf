output "control_plane" {
  value = {
    name       = hcloud_server.control_plane.name
    public_ip  = hcloud_server.control_plane.ipv4_address
    private_ip = local.cp_private_ip
  }
}

output "workers" {
  value = [for i, s in hcloud_server.worker : {
    name       = s.name
    public_ip  = s.ipv4_address
    private_ip = local.worker_private_ips[i]
  }]
}

output "ssh_commands" {
  value = concat(
    ["ssh root@${hcloud_server.control_plane.ipv4_address}"],
    [for s in hcloud_server.worker : "ssh root@${s.ipv4_address}"]
  )
}

output "kubeadm_init_hint" {
  description = "Команда для control plane после того, как cloud-init закончил."
  value = join(" ", [
    "kubeadm init",
    "--apiserver-advertise-address=${local.cp_private_ip}",
    "--apiserver-cert-extra-sans=${hcloud_server.control_plane.ipv4_address}",
    "--pod-network-cidr=${var.pod_cidr}",
    "--service-cidr=${var.service_cidr}",
  ])
}

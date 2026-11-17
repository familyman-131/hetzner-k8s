# Hetzner Cloud: 3 ноды под kubeadm

```
              интернет (только admin_cidrs: 22, 6443, 30000-32767)
                   │ Hetzner Cloud Firewall (только публичный интерфейс)
   ┌───────────────┼──────────────────────────┐
   │ cp-1 (CX23)   worker-1 (CX33)  worker-2 (CX33)
   │ 10.0.1.10     10.0.1.20        10.0.1.21
   └──── private network 10.0.0.0/16 — без фильтрации ──┘
   pods: 10.244.0.0/16   services: 10.96.0.0/12   (не пересекаются с сетью нод)
```

| Файл | Что внутри |
|---|---|
| `versions.tf` | провайдер hcloud |
| `variables.tf` | все параметры + адресный план |
| `network.tf` | private network, subnet, spread placement group, SSH-ключ |
| `firewall.tf` | firewall для CP и воркеров |
| `servers.tf` | 1× CX23 + N× CX33, фиксированные приватные IP, cloud-init |
| `templates/cloud-init.yaml.tftpl` | подготовка ноды под kubeadm (с комментариями «зачем») |
| `outputs.tf` | IP-адреса, ssh-команды, готовая команда `kubeadm init` |

## Запуск

```bash
export TF_VAR_hcloud_token=...            # Hetzner Console → Security → API tokens (Read & Write)
cp terraform.tfvars.example terraform.tfvars   # впиши свой IP в admin_cidrs
terraform init && terraform plan && terraform apply
```

Проверить, что cloud-init закончил (≈2–4 мин):

```bash
ssh root@<ip> 'cloud-init status --wait; ls /var/lib/k8s-node-prep.done'
ssh root@<ip> 'tail -n 30 /var/log/k8s-node-prep.log'   # если status: error
```

Быстрая самопроверка на ноде:

```bash
lsmod | grep -E 'overlay|br_netfilter'
sysctl net.ipv4.ip_forward net.bridge.bridge-nf-call-iptables
swapon --show                      # пусто
crictl info | grep -i systemdcgroup
containerd --version               # 2.x
kubeadm version -o short
cat /etc/default/kubelet           # --node-ip=10.0.1.x
```

## Что делать дальше (руками — это и есть учебная часть)

1. **Control plane:** `terraform output -raw kubeadm_init_hint` → выполнить на cp-1.
   - `--apiserver-advertise-address` = приватный IP: API server слушает и рекламирует себя в private network.
   - `--apiserver-cert-extra-sans` = публичный IP: чтобы kubectl с ноутбука не ругался на сертификат.
   - `--pod-network-cidr` должен совпадать с настройкой CNI.
2. `mkdir -p ~/.kube && cp /etc/kubernetes/admin.conf ~/.kube/config` → нода будет `NotReady`, пока нет CNI.
3. **CNI:** Cilium или Calico. MTU private network Hetzner = 1450, оверлей (VXLAN/Geneve) съедает ещё ~50 байт. Оба CNI определяют MTU сами, но если видишь «висящие» большие ответы (TLS, `kubectl logs`), первым делом проверяй MTU.
4. **Воркеры:** `kubeadm token create --print-join-command` на cp-1 → выполнить на каждом воркере.
5. kubeconfig на ноутбук: скопировать `admin.conf` и заменить `server:` на публичный IP cp-1.

## Нюансы

- **Firewall Hetzner не фильтрует private network.** Поэтому правил для 10250/2379/VXLAN нет, они и не нужны. Обратная сторона: любая VM в этой же сети видит все порты нод.
- **Публичные IP на воркерах** нужны для исходящего трафика (apt, pull образов). Без них понадобится NAT-шлюз в private network — хорошее следующее упражнение.
- `lifecycle.ignore_changes = [user_data, image]` — правка cloud-init не пересоздаст живую ноду. Чтобы применить новый cloud-init: `terraform apply -replace=hcloud_server.worker[0]`.
- **Hetzner Cloud Controller Manager + CSI** (LoadBalancer-сервисы и Volumes как PV) — логичный шаг после работающего кластера. Для CCM ноды нужно поднимать с `--cloud-provider=external` в kubelet.
- `kubernetes_minor = "v1.36"` специально на один минор ниже последнего (1.37) — можно потренировать `kubeadm upgrade` (сначала поменять repo на v1.37).

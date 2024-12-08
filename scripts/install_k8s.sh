#!/usr/bin/env bash
set -exuo pipefail

sudo swapoff -a
# keeps the swaf off during reboot
(
  crontab -l 2>/dev/null
  echo "@reboot /sbin/swapoff -a"
) | crontab - || true

CNI_PLUGINS_VERSION="v1.3.0"
ARCH="amd64"
DEST="/opt/cni/bin"
sudo mkdir -p "$DEST"
curl -L "https://github.com/containernetworking/plugins/releases/download/${CNI_PLUGINS_VERSION}/cni-plugins-linux-${ARCH}-${CNI_PLUGINS_VERSION}.tgz" | sudo tar -C "$DEST" -xz
DOWNLOAD_DIR="/usr/local/bin"
sudo mkdir -p "$DOWNLOAD_DIR"

CRICTL_VERSION="v1.31.0"
curl -L "https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRICTL_VERSION}/crictl-${CRICTL_VERSION}-linux-${ARCH}.tar.gz" | sudo tar -C $DOWNLOAD_DIR -xz

RELEASE="$(curl -sSL https://dl.k8s.io/release/stable.txt)"
cd $DOWNLOAD_DIR
sudo curl -L --remote-name-all https://dl.k8s.io/release/${RELEASE}/bin/linux/${ARCH}/{kubeadm,kubelet}
sudo chmod +x {kubeadm,kubelet}

RELEASE_VERSION="v0.16.2"
curl -sSL "https://raw.githubusercontent.com/kubernetes/release/${RELEASE_VERSION}/cmd/krel/templates/latest/kubelet/kubelet.service" | sed "s:/usr/bin:${DOWNLOAD_DIR}:g" | sudo tee /usr/lib/systemd/system/kubelet.service
sudo mkdir -p /usr/lib/systemd/system/kubelet.service.d
curl -sSL "https://raw.githubusercontent.com/kubernetes/release/${RELEASE_VERSION}/cmd/krel/templates/latest/kubeadm/10-kubeadm.conf" | sed "s:/usr/bin:${DOWNLOAD_DIR}:g" | sudo tee /usr/lib/systemd/system/kubelet.service.d/10-kubeadm.conf

curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x ./kubectl

cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# sysctl params required by setup, params persist across reboots
cat <<EOF >/etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

systemctl enable kubelet.service
systemctl enable containerd.service
systemctl start containerd.service

cat <<EOF >/etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
EOF

cat <<EOF >/tmp/kubeadm_config.yaml
apiVersion: kubeadm.k8s.io/v1beta4
kind: ClusterConfiguration
apiServer:
  timeoutForControlPlane: 4m0s
networking:
  dnsDomain: cluster.local
  serviceSubnet: 192.168.192.0/24
EOF

if [[ ! $(kubectl get nodes) ]]; then
  # Apply sysctl params without reboot
  sudo kubeadm config images pull
  sysctl --system
  kubeadm init --config /tmp/kubeadm_config.yaml
fi

mkdir -p "$HOME"/.kube
cp -i /etc/kubernetes/admin.conf "$HOME"/.kube/config
sudo chown "$(id -u)":"$(id -g)" "$HOME"/.kube/config

kubectl apply -f https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s.yaml

echo "Wait for weave to come up..."
timeout_dns=420

set +x
while [ "$timeout_dns" -gt 0 ]; do
  if sudo -E kubectl get pods --all-namespaces | grep dns | grep Running; then
    break
  fi
  echo -n '.'
  sleep 1s
  ((timeout_dns--))
done
set -x

if [[ $(kubectl get nodes -o=custom-columns=NAME:.metadata.name,TAINTS:.spec.taints | grep master) ]]; then
  kubectl taint nodes --all node-role.kubernetes.io/master-
fi

if [[ $(kubectl get nodes -o=custom-columns=NAME:.metadata.name,TAINTS:.spec.taints | grep control-plane) ]]; then
  kubectl taint nodes --all node-role.kubernetes.io/control-plane-
fi

echo "Setting up access to kubectl by the default user"
mkdir -p /home/vagrant/.kube
cp -i /etc/kubernetes/admin.conf /home/vagrant/config
chown vagrant /home/vagrant/config

# Install helm
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3)"

# Install Metrics
kubectl apply -f https://raw.githubusercontent.com/techiescamp/kubeadm-scripts/main/manifests/metrics-server.yaml

# Install local-path-provisioner
mkdir -p /opt/local-path-provisioner
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.30/deploy/local-path-storage.yaml
kubectl patch storageclass local-path -p '{"metadata": {"annotations": {"storageclass.kubernetes.io/is-default-class": "true"}}}'

# Install MetalLB
# https://metallb.universe.tf/installation/
kubectl get configmap kube-proxy -n kube-system -o yaml |
  sed -e "s/strictARP: false/strictARP: true/" |
  kubectl apply -f - -n kube-system

kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.8/config/manifests/metallb-native.yaml

# Waits for metallb to be ready
set +x
NAMESPACE="metallb-system"
SERVICE="metallb-webhook-service"
TIMEOUT=600 # Total time to wait (in seconds)
INTERVAL=5  # Time between each check (in seconds)
ELAPSED=0

echo "Waiting for $SERVICE to become ready in namespace $NAMESPACE..."

# While loop to wait for the service to be ready
while true; do
  # Check if the service is ready to accept connections
  if nc -z "$(kubectl get service $SERVICE -n $NAMESPACE -o jsonpath='{.spec.clusterIP}')" 443 >/dev/null 2>&1; then
    echo "$SERVICE is ready. Proceeding with IP address pool creation."
    break
  fi

  if [ $ELAPSED -ge $TIMEOUT ]; then
    echo "Timeout reached ($TIMEOUT seconds). $SERVICE did not become ready."
    exit 1
  fi

  echo -n "."
  sleep $INTERVAL
  ELAPSED=$((ELAPSED + INTERVAL))
done
set -x

# Create the IP address pool
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: sandbox
  namespace: metallb-system
spec:
  addresses:
  # On the other hand, the sandbox environment uses private IP space,
  # which is free and plentiful. We give this address pool a ton of IPs,
  # so that developers can spin up as many sandboxes as they need.
  - 10.252.0.1-10.252.0.9
EOF

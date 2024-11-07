# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure('2') do |config|
  config.vm.box = 'opensuse/Leap-15.3.x86_64'
  config.vm.box_version = '15.3.10.25'
  config.vm.network 'private_network', ip: '192.168.33.11'
  config.vm.synced_folder '.', '/vagrant', type: 'nfs', nfs_udp: false, nfs_version: 4
  config.vm.hostname = 'ncn-w001'
  config.vm.provider :libvirt do |ncn|
    ncn.nested = true
    ncn.cpus = 4
    ncn.memory = 8192
  end

  config.vm.provision 'shell', inline: <<-SHELL
    sudo zypper refresh
    sudo zypper -n in wget curl tmux vim htop docker git bind-utils python39
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

    # Upgrade Python
    # sbps requires python3.9
    sudo zypper -n in python39 python39-pip
    sudo /usr/bin/python3.9 -m pip install --upgrade pip==20.0.2
    sudo /usr/bin/python3.9 -m pip install --upgrade virtualenv

    # Start Docker
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo chown vagrant /var/run/docker.sock

    # Install K8s
    wget -q -O - https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | sudo bash
    sudo k3d cluster create csm
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x ./kubectl
    mv ./kubectl /usr/local/bin/
    mkdir /home/vagrant/.kube
    k3d kubeconfig get -a >> /home/vagrant/.kube/config
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3)"

    # Install PowerDNS
    git clone https://github.com/cdwv/powerdns-helm
    helm install . --generate-name
    echo "127.0.0.1 api-gw-service-nmn.local" >> /etc/hosts
    # Need to add powerdns svc as the upstream

    # Install Minio
    helm install my-release oci://registry-1.docker.io/bitnamicharts/minio
    echo 'export ROOT_USER=$(kubectl get secret --namespace default my-release-minio -o jsonpath="{.data.root-user}" | base64 -d)' >> /home/vagrant/.bashrc
    echo 'export ROOT_PASSWORD=$(kubectl get secret --namespace default my-release-minio -o jsonpath="{.data.root-password}" | base64 -d)' /home/vagrant/.bashrc
    cat <<EOS >> /home/vagrant/.bashrc
    function minio-client() {
    kubectl run --namespace default my-release-minio-client \
     --rm --tty -i --restart='Never' \
     --env MINIO_SERVER_ROOT_USER=$ROOT_USER \
     --env MINIO_SERVER_ROOT_PASSWORD=$ROOT_PASSWORD \
     --env MINIO_SERVER_HOST=my-release-minio \
     --image docker.io/bitnami/minio-client:2024.10.29-debian-12-r0 -- $1 $2 minio
    }
    EOS

    # Install sbps
    sudo zypper -n --no-gpg-checks in /vagrant/sbps-marshal-0.0.5-1.noarch.rpm
  SHELL

  config.vm.provision :ansible do |ansible|
    # ansible.limit = 'all'
    ansible.playbook = 'ansible/config_sbps_iscsi_targets.yml'
    ansible.inventory_path = 'ansible/inventory.yml'
  end

end

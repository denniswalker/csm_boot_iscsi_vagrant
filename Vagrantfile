# -*- mode: ruby -*-
# vi: set ft=ruby :

REQUIRED_PLUGINS = %w(vagrant-libvirt vagrant-env)
puts "Checking that the required plugins are installed. Exit 1 if not."
exit 1 unless REQUIRED_PLUGINS.all? { |plugin| Vagrant.has_plugin? plugin }
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

  # Populate artifactory creds so zypper can reach algol.
  config.vm.provision 'shell', inline: <<~EOS
    if [[ ! $(grep "ARTIFACTORY_USER" /etc/environment) || ! $(grep "ARTIFACTORY_TOKEN" /etc/environment) ]]; then
      echo "ARTIFACTORY_USER=#{ENV['ARTIFACTORY_USER']}" | sudo tee -a /etc/environment >/dev/null
      echo "ARTIFACTORY_TOKEN=#{ENV['ARTIFACTORY_TOKEN']}" | sudo tee -a /etc/environment >/dev/null
    fi
  EOS
  config.vm.provision 'shell', inline: <<-SHELL
    sudo zypper refresh
    sudo zypper -n in wget curl tmux vim htop docker git bind-utils python39 jq podman
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

    # Install Minio
    helm install my-release oci://registry-1.docker.io/bitnamicharts/minio
    echo 'export ROOT_USER=$(kubectl get secret --namespace default my-release-minio -o jsonpath="{.data.root-user}" | base64 -d)' >> /home/vagrant/.bashrc
    echo 'export ROOT_PASSWORD=$(kubectl get secret --namespace default my-release-minio -o jsonpath="{.data.root-password}" | base64 -d)' /home/vagrant/.bashrc
    echo 'function minio-client() { kubectl run --namespace default my-release-minio-client --rm --tty -i --restart="Never" --env MINIO_SERVER_ROOT_USER=$ROOT_USER --env MINIO_SERVER_ROOT_PASSWORD=$ROOT_PASSWORD --env MINIO_SERVER_HOST=my-release-minio --image docker.io/bitnami/minio-client:2024.10.29-debian-12-r0 -- $1 $2 minio }' >> /home/vagrant/.bashrc

    # Install sbps
    sudo zypper -n --no-gpg-checks in /vagrant/artifacts/sbps-marshal-0.0.11-1.noarch.rpm

    # Configure PowerDNS as the DNS server
    echo 'export POWERDNS_ENDPOINT=$( kubectl get svc -l app=powerdns-helm -A -o json | jq -r ".items[0].spec.clusterIP")' >> /home/vagrant/.bashrc
    echo "NETCONFIG_DNS_STATIC_SERVERS=${POWERDNS_ENDPOINT}" >> /etc/sysconfig/network/config
    netconfig update -f
    
    # Mimic CPS
    mkdir -p /var/lib/cps-local/boot-images

    # Install IMS
    git clone https://github.com/Cray-HPE/ims
    cd ./ims
    python3.9 -m venv .env
    source .env/bin/activate
    python3.9 -m pip install -r requirements.txt
    # remove the artifactory prefix from the Dockerfile, pulls from dockerhub
    sudo sed -i 's|artifactory.algol60.net/csm-docker/stable/docker.io/library/||g' Dockerfile
    sudo sed -i 's|artifactory.algol60.net/csm-docker/stable/docker.io/||g' Dockerfile
    echo "testing" > .version
    echo "dev" > .docker_version
    sudo mkdir -p  ~/tmp/datastore/
    ims_config_files=(v2_public_keys.json v3_deleted_public_keys.json v2.2_recipes.json v3.2_deleted_recipes.json v2.1_images.json v3.1_deleted_images.json v2.2_jobs.json v2.0_remote_build_nodes.json)
    for file in ${ims_config_files[@]}; do
      echo "[]" | sudo tee -a ~/tmp/datastore/$file >/dev/null
    done
    docker build -t cray-ims-service:dev -f Dockerfile .
    cd $OLDPWD
    curl http://127.0.0.1:9100/images
  SHELL

  config.vm.provision :ansible do |ansible|
    # ansible.limit = 'all'
    ansible.playbook = 'ansible/config_sbps_iscsi_targets.yml'
    ansible.inventory_path = 'ansible/inventory.yml'
  end

end

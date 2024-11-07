# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "opensuse/Leap-15.3.x86_64"
  config.vm.box_version = "15.3.10.25"
  config.vm.network "private_network", ip: "192.168.33.11"
  config.vm.synced_folder "../data", "/vagrant_data", type: "nfs"
  # config.vm.provision "shell", inline: <<-SHELL
  #   apt-get update
  #   apt-get install -y apache2
  # SHELL
  config.vm.provision :ansible do |ansible|
    # ansible.limit = "all"
    ansible.playbook = "ansible/config_sbps_iscsi_targets.yml"
    ansible.inventory_path = "ansible/inventory.yml"
  end

end

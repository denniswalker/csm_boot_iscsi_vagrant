# -*- mode: ruby -*-
# vi: set ft=ruby :

REQUIRED_PLUGINS = %w(vagrant-libvirt vagrant-env)
puts "Checking that the required plugins are installed. Exit 1 if not."
exit 1 unless REQUIRED_PLUGINS.all? { |plugin| Vagrant.has_plugin? plugin }
Vagrant.configure('2') do |config|
  config.vm.define :ncn do |ncn|
    ncn.vm.box = 'opensuse/Leap-15.3.x86_64'
    ncn.vm.box_version = '15.3.10.25'
    ncn.vm.network 'private_network', ip: '10.252.0.10', libvirt__network_name: 'nmn', libvirt__dhcp_enabled: false
    ncn.vm.synced_folder '.', '/vagrant', type: 'nfs', nfs_udp: false, nfs_version: 4
    ncn.vm.hostname = 'k3d-csm-server-0'
    ncn.vm.provider :libvirt do |ncnw|
      ncnw.nested = true
      ncnw.cpu_mode = 'host-passthrough'
      ncnw.cpus = 4
      ncnw.memory = 8192
    end

    # Populate artifactory creds so zypper can reach algol. Not necessary.
    ncn.vm.provision 'shell', inline: <<~EOS
      if [[ ! $(grep "ARTIFACTORY_USER" /etc/environment) || ! $(grep "ARTIFACTORY_TOKEN" /etc/environment) ]]; then
        echo "ARTIFACTORY_USER=#{ENV['ARTIFACTORY_USER']}" | sudo tee -a /etc/environment >/dev/null
        echo "ARTIFACTORY_TOKEN=#{ENV['ARTIFACTORY_TOKEN']}" | sudo tee -a /etc/environment >/dev/null
      fi
    EOS
    ncn.vm.provision 'shell', path: 'configure_vm.sh'
    ncn.vm.provision :ansible_local do |ansible|
      # ansible.limit = 'all'
      ansible.playbook = '/vagrant/ansible/config_sbps_iscsi_targets.yml'
      ansible.inventory_path = '/vagrant/ansible/inventory.yml'
    end
  end

  # Define the NID
  config.vm.define :compute, autostart: false do |compute|
    compute.vm.hostname = "nid001"
    compute.vm.network 'private_network', libvirt__network_name: 'nmn'

     # Configure VM
    compute.vm.provider :libvirt do |libvirt|
      libvirt.cpu_mode = 'host-passthrough'
      libvirt.memory = '4096'
      libvirt.cpus = '2'
      # Create a disk
      libvirt.storage :file,
        size: '50G',
        type: 'qcow2',
        bus: 'sata',
        device: 'sda'
      # Set fr keyboard for vnc connection
      libvirt.keymap = 'en'
      # Set pxe network NIC as default boot
      boot_network = {'network' => 'nmn'}
      libvirt.boot boot_network
      libvirt.boot 'hd'
      # Set UEFI boot, comment for legacy
      libvirt.loader = '/usr/share/qemu/OVMF.fd'
    end
  end
end

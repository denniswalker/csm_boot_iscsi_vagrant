# -*- mode: ruby -*-
# vi: set ft=ruby :
Vagrant.configure('2') do |config|
  config.vm.define :ncn do |ncn|
    ncn.vm.box = 'opensuse/Leap-15.3.x86_64'
    ncn.vm.box_version = '15.3.10.25'
    ncn.vm.network 'private_network', ip: '10.252.0.10', libvirt__network_name: 'nmn', libvirt__dhcp_enabled: false
    ncn.vm.synced_folder '.', '/vagrant', type: 'nfs', nfs_udp: false, nfs_version: 4
    ncn.vm.hostname = 'ncn-w001'
    ncn.vm.provider :libvirt do |ncnw|
      ncnw.nested = true
      ncnw.cpu_mode = 'host-passthrough'
      ncnw.cpus = 4
      ncnw.memory = 8192
    end
  end

  # Define the NID
  config.vm.define :compute, autostart: false do |compute|
    #compute.vm.box = 'opensuse/Leap-15.6.x86_64'
    compute.vm.hostname = "nid0001"
    compute.vm.network 'private_network', libvirt__network_name: 'nmn'

     # Configure VM
    compute.vm.provider :libvirt do |libvirt|
      libvirt.cpu_mode = 'host-passthrough'
      libvirt.memory = '4096'
      libvirt.cpus = '2'
      # Create a disk
      libvirt.storage :file,
        size: '60G',
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

# Local Vagrant Environment for CSM iSCSI PXE Boot

This repository provides a **local Vagrant environment** designed to simulate and test **CSM iSCSI PXE Boot** workflows. The environment uses **Vagrant** and **libvirt** to provision virtual machines, mimicking a real-world setup for iSCSI-based PXE boot testing.

## Features

- Simplified local testing for iSCSI PXE boot configurations.
- Pre-configured Vagrant setup for quick deployment.
- Compatibility with `libvirt` for efficient virtual machine management.
- Customizable Vagrantfile for extending the environment to your needs.

## Requirements

Before using this environment, ensure you have the following installed on your system:

1. **[Vagrant](https://www.vagrantup.com/)**  
   A tool for managing virtualized development environments.

2. **[Libvirt](https://libvirt.org/)**  
   A toolkit to interact with the virtualization capabilities of Linux.

3. **[vagrant-libvirt](https://github.com/vagrant-libvirt/vagrant-libvirt)**  
   A Vagrant plugin to manage libvirt-based virtual machines. Install it by running:  
   ```bash
   vagrant plugin install vagrant-libvirt
   ```

## Getting Started

Run ```bash ./up.sh ```

# Local Vagrant Environment for CSM iSCSI PXE Boot

This repository provides a **local Vagrant environment** designed to simulate
and test **CSM iSCSI PXE Boot** workflows. The environment uses **Vagrant** and
**libvirt** to provision virtual machines, mimicking a real-world setup for
iSCSI-based PXE boot testing.

## Features

- Simplified local testing for iSCSI PXE boot configurations.
- Easily restore from snapshots of each script and replay forward.
- Pre-configured Vagrant setup for quick deployment.
- Compatibility with `libvirt` for efficient virtual machine management.
- Customizable Vagrantfile for extending the environment to your needs.

## Requirements

Before using this environment, ensure you have the following installed on your
system:

1. **[Vagrant](https://www.vagrantup.com/)**\
   A tool for managing virtualized development environments.

1. **[Libvirt](https://libvirt.org/)**\
   A toolkit to interact with the virtualization capabilities of Linux.

1. **[vagrant-libvirt](https://github.com/vagrant-libvirt/vagrant-libvirt)**\
   A Vagrant plugin to manage libvirt-based virtual machines. Install it by
   running:
   ```bash
   vagrant plugin install vagrant-libvirt
   ```
1. A local NFS server - This folder is automatically mounted into the image at
   "/vagrant". It requires an NFS server to be installed and started. Consult
   your OS documentation or package manager.

## Getting Started

Run `bash ./up.sh`

## Replay From Snapshot

Run `bash ./replay_from.sh [stage]`. The script will restore the snapshot
created before the script ran.

For a list of stages, consult the 'STAGES' variable in ./scripts/lib/lib

## Troubleshooting

Occasionally the VMs may become inaccessible. If this occurs and unless you see
why, simply start over.

`bash vagrant destroy -f && ./up.sh`

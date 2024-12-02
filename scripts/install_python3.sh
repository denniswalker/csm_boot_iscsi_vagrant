#!/usr/bin/env bash
set -exuo pipefail

# Upgrade Python
# sbps requires python3.9
sudo zypper -n in python39 python39-pip
sudo /usr/bin/python3.9 -m pip install --upgrade pip==20.0.2
sudo /usr/bin/python3.9 -m pip install --upgrade virtualenv

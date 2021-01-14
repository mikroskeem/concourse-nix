#!/bin/sh
set -euo pipefail
nix-build '<nixpkgs/nixos>' -A vm -I nixos-config=./scripts/vm-configuration.nix --show-trace
rm ./nixos.qcow2 || true
./result/bin/run-nixos-vm

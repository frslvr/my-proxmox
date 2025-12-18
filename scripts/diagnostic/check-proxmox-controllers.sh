#!/bin/bash
# Check detailed controller information on Proxmox host

echo "=== Full Controller Details ==="
echo ""

for ctrl in 77:00.0 78:00.0 79:00.3 79:00.4; do
  echo "======================================"
  echo "Controller: $ctrl"
  echo "======================================"
  lspci -s $ctrl -nnv | head -20
  echo ""
done

echo ""
echo "=== USB Bus Topology (if any devices on host) ==="
lsusb -t

echo ""
echo "=== IOMMU Group Check ==="
for ctrl in 77:00.0 78:00.0 79:00.3 79:00.4; do
  echo "Controller $ctrl:"
  find /sys/kernel/iommu_groups/ -name "*$ctrl*" -exec dirname {} \; | xargs basename 2>/dev/null
done

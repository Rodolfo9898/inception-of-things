#!/bin/bash
GREEN="\033[32m"
RED="\033[31m"
RESET="\033[0m"

if sudo apt-get update && sudo apt-get install -y curl net-tools; then
  echo -e "${GREEN}Prerequisites installation SUCCEEDED${RESET}"
else
  echo -e "${RED}Prerequisites installation FAILED${RESET}"
fi

if sudo ip link add eth1 type dummy 2>/dev/null || true && \
  sudo ip addr add 192.168.56.110/24 dev eth1 2>/dev/null || true && \
  sudo ip link set eth1 up; then
  echo -e "${GREEN}Network interface setup SUCCEEDED${RESET}"
else
  echo -e "${RED}Network interface setup FAILED${RESET}"
fi

if curl -sfL https://get.k3s.io | sh -s - \
  --write-kubeconfig-mode 644 \
  --tls-san=rperez-tS \
  --node-ip=192.168.56.110 \
  --bind-address=192.168.56.110 \
  --advertise-address=192.168.56.110; then
  echo -e "${GREEN}K3s MASTER installation SUCCEEDED${RESET}"
else
  echo -e "${RED}K3s MASTER installation FAILED${RESET}"
fi

if sudo cp /var/lib/rancher/k3s/server/node-token /vagrant/token; then
  echo -e "${GREEN}Token copy SUCCEEDED${RESET}"
else
  echo -e "${RED}Token copy FAILED${RESET}"
fi

if sudo systemctl status k3s.service; then
  echo -e "${GREEN}K3s service status check SUCCEEDED${RESET}"
else
  echo -e "${RED}K3s service status check FAILED${RESET}"
fi

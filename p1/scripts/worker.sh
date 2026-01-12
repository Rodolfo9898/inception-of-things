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
  sudo ip addr add 192.168.56.111/24 dev eth1 2>/dev/null || true && \
  sudo ip link set eth1 up; then
  echo -e "${GREEN}Network interface setup SUCCEEDED${RESET}"
else
  echo -e "${RED}Network interface setup FAILED${RESET}"
fi

if curl -sfL https://get.k3s.io | sh -s - agent \
  --server=https://192.168.56.110:6443 \
  --node-ip=192.168.56.111 \
  --token-file=/vagrant/token; then
  echo -e "${GREEN}K3s AGENT installation SUCCEEDED${RESET}"
else
  echo -e "${RED}K3s AGENT installation FAILED${RESET}"
fi

if sudo rm /vagrant/token; then
  echo -e "${GREEN}Token cleanup SUCCEEDED${RESET}"
else
  echo -e "${RED}Token cleanup FAILED${RESET}"
fi

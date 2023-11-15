#!/bin/bash

# shellcheck disable=SC1009
# shellcheck disable=SC2155
# shellcheck disable=SC2092
# shellcheck disable=SC2006

export Red="$(tput setaf 1)"
export green="$(tput setaf 2)"
export yellow="$(tput setaf 3)"
export blue="$(tput setaf 4)"

if [ "$(id -u)" != "0" ]; then
  echo "${Red} [!] This script requires root privilege [run with : sudo bash setup.sh] "
  exit 1
fi


echo "[!] Downloading megatools"
wget https://mega.nz/linux/repo/xUbuntu_22.04/amd64/megacmd-xUbuntu_22.04_amd64.deb && sudo apt install "$PWD/megacmd-xUbuntu_22.04_amd64.deb"

echo "[!] Installing .."
sudo apt-get install jq -yy
sudo apt-get install curl -yy

echo "${green}[!] Installed necessary packages"
sudo chmod +777 manage.sh
echo "${green}[!] Done .."


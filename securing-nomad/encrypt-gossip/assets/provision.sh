#! /bin/bash

log() {
  echo $(date) - ${1} | tee -a /var/log/provision.log
}

fix_journal() {
  log "Fixing Journal"
  if [ ! -f "/etc/machine-id" ]
  then
    systemd-machine-id-setup > /dev/null 2>&1
    systemd-tmpfiles --create --prefix /var/log/journal
    systemctl start systemd-journald.service
  fi
}

install_apt_deps() {
  log "Installing OS dependencies"
  export DEBIAN_FRONTEND=noninteractive
  apt-get -y update >> /var/log/provision.log 2>&1
  apt-get -y install sudo unzip python3 python3-pip >> /var/log/provision.log 2>&1 
  unset DEBIAN_FRONTEND
}

install_zip() {
  NAME="$1"
  log "Fetching zip and installing ${NAME}"
  if [ ! -f "/usr/local/bin/$NAME" ]
  then
    DOWNLOAD_URL="$2"
    curl -s -L -o /tmp/$NAME.zip $DOWNLOAD_URL
    sudo unzip -qq -d /usr/local/bin/ /tmp/$NAME.zip
    sudo chmod +x /usr/local/bin/$NAME
    rm /tmp/$NAME.zip
  fi
}

install_pyhcl() {
  log "Installing pyhcl"
  pip install -qqq pyhcl
}

create_nomad_service() {
  if [ ! -f "/etc/nomad.d/nomad.hcl" ]
  then
    cp /tmp/nomad.hcl /etc/nomad.d/nomad.hcl
  fi
  systemctl enable nomad
}

maybe_preprovision() {
  if [ -x /usr/local/bin/provision_scenario_pre.sh ]
  then
    /usr/local/bin/provision_scenario_pre.sh
  fi
}

maybe_postprovision() {
  if [ -x /usr/local/bin/provision_scenario_post.sh ]
  then
    /usr/local/bin/provision_scenario_post.sh
  fi
}

maybe_provision_namespace() {
  if [ ! -f /provision/namespace_done ]
  then
    while [ ! -x /usr/local/bin/provision_ns.sh ]
    do 
      sleep 1
    done
    /usr/local/bin/provision_ns.sh
    touch /provision/namespace_done
  fi
}

finish() {
  log "Complete!  Move on to the next step."
}

maybe_provision_base() {
  if [ ! -f /provision/provision_base_done ]
  then
    fix_journal
    install_apt_deps
    install_pyhcl
    install_zip "consul" "https://releases.hashicorp.com/consul/1.8.4/consul_1.8.4_linux_amd64.zip"
    install_zip "nomad" "https://releases.hashicorp.com/nomad/0.12.5/nomad_0.12.5_linux_amd64.zip"
    touch /provision/provision_base_done
  fi
}

# Main stuff
mkdir -p /provision /etc/nomad.d /opt/nomad/data

maybe_provision_base
maybe_preprovision
maybe_provision_namespace
maybe_postprovision
finish

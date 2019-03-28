#!/bin/bash

cur_dir=$(pwd)
path_to_env="${cur_dir}/k8.env"
if [[ "${CLUSTER_CONFIG}" != "" ]]; then
    path_to_env="${CLUSTER_CONFIG}"
fi
if [[ ! -e ${path_to_env} ]]; then
    if [[ -e ${cur_dir}/../k8.env ]]; then
        cur_dir=".."
        path_to_env="${cur_dir}/k8.env"
    else
        echo "failed to find env file: ${path_to_env} with CLUSTER_CONFIG=${CLUSTER_CONFIG}"
        exit 1
    fi
fi
source ${path_to_env}

env_name=${K8_ENV}
os_type=${OS}
storage_type="${KVM_STORAGE_TYPE}"

if [[ "${os_type}" == "fc" ]]; then
    export LIBVIRT_DEFAULT_URI="qemu:///system"
fi

# defined in the CLUSTER_CONFIG
start_logger

# Credit to all the awesomeness at:
# https://github.com/giovtorres/kvm-install-vm/blob/master/kvm-install-vm

# requires having kvm installed

# usage: ./multihost/kvm/create-centos-vm.sh m1 /data/kvm/m1.${storage_type}
# usage: ./multihost/kvm/create-centos-vm.sh m2
# usage: ./multihost/kvm/create-centos-vm.sh m3

test_virt_installed=$(which virt-install | wc -l)
if [[ "${test_virt_installed}" == "0" ]]; then
    err "Please install kvm before running this script"
    exit 1
fi

if [[ ! -e ${KVM_IMAGES_DIR} ]]; then
    mkdir -p -m 777 ${KVM_IMAGES_DIR}
fi
if [[ ! -e ${KVM_VMS_DIR} ]]; then
    mkdir -p -m 777 ${KVM_VMS_DIR}
fi

if [[ "${os_type}" == "fc" ]]; then
    # fedora 29 fails without this:
    export LIBGUESTFS_BACKEND=direct
fi
anmt "--------------------------------"

path_to_use="$(dirname ${path_to_env})"
INCLUDE_SSH_ACCESS="  - /bin/echo \"no ssh set with CLUSTER_CONFIG=${path_to_env} setting K8_USER_DATA_SSH_ACCESS=${K8_USER_DATA_SSH_ACCESS}\""
INCLUDE_STATIC_NETWORK="  - /bin/echo \"not using static networking with CLUSTER_CONFIG=${path_to_env} setting K8_USER_DATA_STATIC_NETWORKING=${K8_USER_DATA_STATIC_NETWORKING}\""

set -e

# Set program name variable - basename without subshell
prog=${0##*/}

function usage ()
{
    cat << EOF
NAME
    kvm-install-vm - Install virtual guests using cloud-init on a local KVM
    hypervisor.

SYNOPSIS
    $prog COMMAND [OPTIONS]

DESCRIPTION
    A bash wrapper around virt-install to build virtual machines on a local KVM
    hypervisor. You can run it as a normal user which will use qemu:///session
    to connect locally to your KVM domains.

COMMANDS
    help        - show this help or help for a subcommand
    attach-disk - create and attach a disk device to guest domain
    create      - create a new guest domain
    detach-disk - detach a disk device from a guest domain
    list        - list all domains, running and stopped
    remove      - delete a guest domain

EOF
exit 0
}

function usage_subcommand ()
{
    case "$1" in
        create)
            printf "NAME\n"
            printf "    $prog create [COMMANDS] [OPTIONS] VMNAME\n"
            printf "\n"
            printf "DESCRIPTION\n"
            printf "    Create a new guest domain.\n"
            printf "\n"
            printf "COMMANDS\n"
            printf "    help - show this help\n"
            printf "\n"
            printf "OPTIONS\n"
            printf "    -a          Autostart           (default: false)\n"
            printf "    -b          Bridge              (default: virbr0)\n"
            printf "    -c          Number of vCPUs     (default: 1)\n"
            printf "    -d          Disk Size (GB)      (default: 10)\n"
            printf "    -D          DNS Domain          (default: example.local)\n"
            printf "    -f          CPU Model / Feature (default: host)\n"
            printf "    -g          Graphics type       (default: spice)\n"
            printf "    -h          Display help\n"
            printf "    -i          Custom QCOW2 Image\n"
            printf "    -k          SSH Public Key      (default: $HOME/.ssh/id_rsa.pub)\n"
            printf "    -l          Location of Images  (default: $HOME/virt/images)\n"
            printf "    -L          Location of VMs     (default: $HOME/virt/vms)\n"
            printf "    -m          Memory Size (MB)    (default: 1024)\n"
            printf "    -M          Mac address         (default: auto-assigned)\n"
            printf "    -p          Console port        (default: auto)\n"
            printf "    -s          Custom shell script\n"
            printf "    -t          Linux Distribution  (default: k8)\n"
            printf "    -T          Timezone            (default: US/Eastern)\n"
            printf "    -u          Custom user         (default: $USER)\n"
            printf "    -v          Be verbose\n"
            printf "\n"
            printf "DISTRIBUTIONS\n"
            printf "    NAME            DESCRIPTION                         LOGIN\n"
            printf "    k8              CentOS 7                            jay\n"
            printf "    amazon2         Amazon Linux 2                      ec2-user\n"
            printf "    centos7         CentOS 7                            centos\n"
            printf "    centos7-atomic  CentOS 7 Atomic Host                centos\n"
            printf "    centos6         CentOS 6                            centos\n"
            printf "    debian9         Debian 9 (Stretch)                  debian\n"
            printf "    fedora27        Fedora 27                           fedora\n"
            printf "    fedora27-atomic Fedora 27 Atomic Host               fedora\n"
            printf "    fedora28        Fedora 28                           fedora\n"
            printf "    fedora28-atomic Fedora 28 Atomic Host               fedora\n"
            printf "    ubuntu1604      Ubuntu 16.04 LTS (Xenial Xerus)     ubuntu\n"
            printf "    ubuntu1804      Ubuntu 18.04 LTS (Bionic Beaver)    ubuntu\n"
            printf "\n"
            printf "EXAMPLES\n"
            printf "    $prog create foo\n"
            printf "        Create VM with the default parameters: CentOS 7, 1 vCPU, 1GB RAM, 10GB\n"
            printf "        disk capacity.\n"
            printf "\n"
            printf "    $prog create -c 2 -m 2048 -d 20 foo\n"
            printf "        Create VM with custom parameters: 2 vCPUs, 2GB RAM, and 20GB disk\n"
            printf "        capacity.\n"
            printf "\n"
            printf "    $prog create -t debian9 foo\n"
            printf "        Create a Debian 9 VM with the default parameters.\n"
            printf "\n"
            printf "    $prog create -T UTC foo\n"
            printf "        Create a default VM with UTC timezone.\n"
            printf "\n"
            ;;
        remove)
            printf "NAME\n"
            printf "    $prog remove [COMMANDS] VMNAME\n"
            printf "\n"
            printf "DESCRIPTION\n"
            printf "    Destroys (stops) and undefines a guest domain.  This also remove the\n"
            printf "    associated storage pool.\n"
            printf "\n"
            printf "COMMANDS\n"
            printf "    help - show this help\n"
            printf "\n"
            printf "EXAMPLE\n"
            printf "    $prog remove foo\n"
            printf "        Remove (destroy and undefine) a guest domain.  WARNING: This will\n"
            printf "        delete the guest domain and any changes made inside it!\n"
            ;;
        attach-disk)
            printf "NAME\n"
            printf "    $prog attach-disk [OPTIONS] [COMMANDS] VMNAME\n"
            printf "\n"
            printf "DESCRIPTION\n"
            printf "    Attaches a new disk to a guest domain.\n"
            printf "\n"
            printf "COMMANDS\n"
            printf "    help - show this help\n"
            printf "\n"
            printf "OPTIONS\n"
            printf "    -d SIZE     Disk size (GB)\n"
            printf "    -f FORMAT   Disk image format       (default: ${storage_type})\n"
            printf "    -s IMAGE    Source of disk device\n"
            printf "    -t TARGET   Disk device target\n"
            printf "\n"
            printf "EXAMPLE\n"
            printf "    $prog attach-disk -d 10 -s example-5g.${storage_type} -t vdb foo\n"
            printf "        Attach a 10GB disk device named example-5g.${storage_type} to the foo guest\n"
            printf "        domain.\n"
            ;;
        list)
            printf "NAME\n"
            printf "    $prog list\n"
            printf "\n"
            printf "DESCRIPTION\n"
            printf "    Lists all running and stopped guest domains.\n"
            ;;
        *)
            printf "'$subcommand' is not a valid subcommand.\n"
            exit 1
            ;;
    esac
    exit 0
}

# Console output colors
bold() { echo -e "\e[1m$@\e[0m" ; }
red() { echo -e "\e[31m$@\e[0m" ; }
green() { echo -e "\e[32m$@\e[0m" ; }
yellow() { echo -e "\e[33m$@\e[0m" ; }

die() { red "ERR: $@" >&2 ; exit 2 ; }
silent() { "$@" > /dev/null 2>&1 ; }
output() { echo -e "- $@" ; }
outputn() { echo -en "- $@ ... " ; }
ok() { green "${@:-OK}" ; }

pushd() { command pushd "$@" >/dev/null ; }
popd() { command popd "$@" >/dev/null ; }

# Detect OS and set wget parameters
function set_wget ()
{
    if [ -f /etc/fedora-release ]
    then
        WGET="wget --quiet --show-progress"
    else
        WGET="wget"
    fi
}

function check_vmname_set ()
{
    [ -n "${VMNAME}" ] || die "VMNAME not set."
}

function delete_vm ()
{
    check_vmname_set

    if [ "${DOMAIN_EXISTS}" -eq 1 ]
    then
        outputn "Destroying ${VMNAME} domain"
        virsh destroy --graceful ${VMNAME} > /dev/null 2>&1 \
            && ok \
            || yellow "(Domain is not running.)"

        outputn "Undefining ${VMNAME} domain"
        virsh undefine --managed-save ${VMNAME} > /dev/null 2>&1 \
            && ok \
            || die "Could not undefine domain."
    else
        output "Domain ${VMNAME} does not exist"
    fi

    [[ -d ${VMDIR}/${VMNAME} ]] && DISKDIR=${VMDIR}/${VMNAME} || DISKDIR=${IMAGEDIR}/${VMNAME}
    [ -d $DISKDIR ] \
        && outputn "Deleting ${VMNAME} files" \
        && sudo rm -rf $DISKDIR \
        && ok

    if [ "${STORPOOL_EXISTS}" -eq 1 ]
    then
        outputn "Destroying ${VMNAME} storage pool"
        virsh pool-destroy ${VMNAME} > /dev/null 2>&1 && ok
    else
        output "Storage pool ${VMNAME} does not exist"
    fi
}

function fetch_images ()
{
    # Create image directory if it doesn't already exist
    mkdir -p ${IMAGEDIR}

    # Set variables based on $DISTRO
    # Use the command "osinfo-query os" to get the list of the accepted OS variants.
    case "$DISTRO" in
        k8)
            QCOW=CentOS-7-x86_64-GenericCloud.qcow2
            OS_VARIANT="centos7.0"
            IMAGE_URL=https://cloud.centos.org/centos/7/images
            LOGIN_USER=jay
            ;;
        amazon2)
            QCOW=amzn2-kvm-2.0.20181114-x86_64.xfs.gpt.qcow2
            OS_VARIANT="auto"
            IMAGE_URL=https://cdn.amazonlinux.com/os-images/2.0.20181114/kvm
            LOGIN_USER=ec2-user
            ;;
        centos7)
            QCOW=CentOS-7-x86_64-GenericCloud.qcow2
            OS_VARIANT="centos7.0"
            IMAGE_URL=https://cloud.centos.org/centos/7/images
            LOGIN_USER=centos
            ;;
        centos7-atomic)
            QCOW=CentOS-Atomic-Host-7-GenericCloud.qcow2
            OS_VARIANT="centos7.0"
            IMAGE_URL=http://cloud.centos.org/centos/7/atomic/images
            LOGIN_USER=centos
            ;;
        centos6)
            QCOW=CentOS-6-x86_64-GenericCloud.qcow2
            OS_VARIANT="centos6.9"
            IMAGE_URL=https://cloud.centos.org/centos/6/images
            LOGIN_USER=centos
            ;;
        debian8)
            # FIXME: Not yet working.
            QCOW=debian-8-openstack-amd64.qcow2
            OS_VARIANT="debian8"
            IMAGE_URL=https://cdimage.debian.org/cdimage/openstack/current-8
            LOGIN_USER=debian
            ;;
        debian9)
            QCOW=debian-9-openstack-amd64.qcow2
            OS_VARIANT="debian9"
            IMAGE_URL=https://cdimage.debian.org/cdimage/openstack/current-9
            LOGIN_USER=debian
            ;;
        fedora27)
            QCOW=Fedora-Cloud-Base-27-1.6.x86_64.qcow2
            OS_VARIANT="fedora27"
            IMAGE_URL=https://download.fedoraproject.org/pub/fedora/linux/releases/27/CloudImages/x86_64/images
            LOGIN_USER=fedora
            ;;
        fedora27-atomic)
            QCOW=Fedora-Atomic-27-1.6.x86_64.qcow2
            OS_VARIANT="fedora27"
            IMAGE_URL=https://download.fedoraproject.org/pub/fedora/linux/releases/27/CloudImages/x86_64/images
            LOGIN_USER=fedora
            ;;
        fedora28)
          QCOW=Fedora-Cloud-Base-28-1.1.x86_64.qcow2
          OS_VARIANT="fedora27"
          IMAGE_URL=https://download.fedoraproject.org/pub/fedora/linux/releases/28/Cloud/x86_64/images
          LOGIN_USER=fedora
          ;;
        fedora28-atomic)
          QCOW=Fedora-AtomicHost-28-20180425.0.x86_64.qcow2
          OS_VARIANT="fedora27"
          IMAGE_URL=https://download.fedoraproject.org/pub/alt/atomic/stable/Fedora-Atomic-28-20180425.0/AtomicHost/x86_64/images
          LOGIN_USER=fedora
          ;;
        ubuntu1604)
            QCOW=ubuntu-16.04-server-cloudimg-amd64-disk1.img
            OS_VARIANT="ubuntu16.04"
            IMAGE_URL=https://cloud-images.ubuntu.com/releases/16.04/release
            LOGIN_USER=ubuntu
            ;;
        ubuntu1804)
            QCOW=ubuntu-18.04-server-cloudimg-amd64.img
            OS_VARIANT="ubuntu17.10"
            IMAGE_URL=https://cloud-images.ubuntu.com/releases/18.04/release
            LOGIN_USER=ubuntu
            ;;
        *)
            die "${DISTRO} not a supported OS.  Run 'kvm-install-vm create help'."
            ;;
    esac

    IMAGE=${IMAGEDIR}/${QCOW}

    if [ ! -f ${IMAGEDIR}/${QCOW} ]
    then
        output "Cloud image not found.  Downloading"
        set_wget
        ${WGET} --directory-prefix ${IMAGEDIR} ${IMAGE_URL}/${QCOW} || \
            die "Could not download image."
    fi

}

function check_ssh_key ()
{
    local key
    if [ -z "${PUBKEY}" ]; then
        # Try to find a suitable key file.
        for key in ~/.ssh/id_{rsa,dsa,ed25519}.pub; do
            if [ -f "$key" ]; then
                PUBKEY="$key"
                break
            fi
        done
    fi

    if [ ! -f "${PUBKEY}" ]
    then
        # Check for existence of a pubkey, or else exit with message
        die "Please generate an SSH keypair using 'ssh-keygen -t rsa' or \
             specify one with the "-k" flag."
    else
        # Place contents of $PUBKEY into $KEY
        KEY=$(<${PUBKEY})
    fi
}

function domain_exists ()
{
    virsh dominfo "${1}" > /dev/null 2>&1 \
        && DOMAIN_EXISTS=1 \
        || DOMAIN_EXISTS=0
}

function storpool_exists ()
{
    virsh pool-info "${1}" > /dev/null 2>&1 \
        && STORPOOL_EXISTS=1 \
        || STORPOOL_EXISTS=0
}

function set_sudo_group ()
{
    case "${DISTRO}" in
        k8|centos?|fedora??|*-atomic|amazon? )
            SUDOGROUP="wheel"
            ;;
        ubuntu*|debian? )
            SUDOGROUP="sudo"
            ;;
        *)
            die "OS not supported."
            ;;
    esac
}

function set_cloud_init_remove ()
{
    case "${DISTRO}" in
        centos6 )
            CLOUDINITDISABLE="chkconfig cloud-init off"
            ;;
        k8|centos7|amazon?|fedora??|ubuntu*|debian? )
            CLOUDINITDISABLE="systemctl disable cloud-init.service"
            ;;
        *-atomic)
            CLOUDINITDISABLE="/usr/bin/true"
            ;;
    esac
}

function set_network_restart_cmd ()
{
    case "${DISTRO}" in
        centos6 )           NETRESTART="service network stop && service network start" ;;
        ubuntu*|debian?)    NETRESTART="systemctl stop networking && systemctl start networking" ;;
        *)                  NETRESTART="systemctl stop network && systemctl start network" ;;
    esac
}

function check_delete_known_host ()
{
    output "Checking for ${IP} in known_hosts file"
    grep -q ${IP} ${HOME}/.ssh/known_hosts \
        && outputn "Found entry for ${IP}. Removing" \
        && (sed --in-place "/^${IP}/d" ~/.ssh/known_hosts && ok ) \
        || output "No entries found for ${IP}"
}

function create_vm ()
{
    # Create image directory if it doesn't already exist
    mkdir -p ${VMDIR}

    check_vmname_set

    # Start clean
    [ -d "${VMDIR}/${VMNAME}" ] && sudo rm -rf ${VMDIR}/${VMNAME}
    mkdir -p ${VMDIR}/${VMNAME}

    pushd ${VMDIR}/${VMNAME}

    if [[ "${K8_USER_DATA_SSH_ACCESS}" == "1" ]]; then
        INCLUDE_SSH_ACCESS=$(cat << _EOF_
  - /bin/echo "" >> /etc/ssh/sshd_config
  - /bin/echo "# added for metalnetes" >> /etc/ssh/sshd_config
  - /bin/echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
  - /bin/echo "AllowUsers ${K8_VM_USER} root" >> /etc/ssh/sshd_config
  - /bin/echo "PermitEmptyPasswords no" >> /etc/ssh/sshd_config
  - /bin/echo "Port 22" >> /etc/ssh/sshd_config
  - systemctl restart ssh
_EOF_
)
    fi
    if [[ "${K8_USER_DATA_STATIC_NETWORKING}" == "1" ]]; then
        INCLUDE_STATIC_NETWORK=$(cat << _EOF_
  - /bin/echo "NAME=eth0" > /etc/sysconfig/network-scripts/ifcfg-eth0
  - /bin/echo "DEVICE=eth0" >> /etc/sysconfig/network-scripts/ifcfg-eth0
  - /bin/echo "HWADDR=${MAC}" >> /etc/sysconfig/network-scripts/ifcfg-eth0
  - /bin/echo "IPADDR=${IP}" >> /etc/sysconfig/network-scripts/ifcfg-eth0
  - /bin/echo "GATEWAY=${K8_GATEWAY}" >> /etc/sysconfig/network-scripts/ifcfg-eth0
  - /bin/echo "DNS1=${K8_DNS_SERVER_1}" >> /etc/sysconfig/network-scripts/ifcfg-eth0
  - /bin/echo "TYPE=Ethernet" >> /etc/sysconfig/network-scripts/ifcfg-eth0
  - /bin/echo "PROXY_METHOD=none" >> /etc/sysconfig/network-scripts/ifcfg-eth0
  - /bin/echo "BROWSER_ONLY=no" >> /etc/sysconfig/network-scripts/ifcfg-eth0
  - /bin/echo "BOOTPROTO=static" >> /etc/sysconfig/network-scripts/ifcfg-eth0
  - /bin/echo "DEFROUTE=yes" >> /etc/sysconfig/network-scripts/ifcfg-eth0
  - /bin/echo "IPV4_FAILURE_FATAL=no" >> /etc/sysconfig/network-scripts/ifcfg-eth0
  - /bin/echo "IPV6INIT=yes" >> /etc/sysconfig/network-scripts/ifcfg-eth0
  - /bin/echo "IPV6_AUTOCONF=yes" >> /etc/sysconfig/network-scripts/ifcfg-eth0
  - /bin/echo "IPV6_DEFROUTE=yes" >> /etc/sysconfig/network-scripts/ifcfg-eth0
  - /bin/echo "IPV6_FAILURE_FATAL=no" >> /etc/sysconfig/network-scripts/ifcfg-eth0
  - /bin/echo "IPV6_ADDR_GEN_MODE=stable-privacy" >> /etc/sysconfig/network-scripts/ifcfg-eth0
  - /bin/echo "ONBOOT=yes" >> /etc/sysconfig/network-scripts/ifcfg-eth0
  - /bin/echo "PREFIX=24" >> /etc/sysconfig/network-scripts/ifcfg-eth0
  - /bin/echo "DNS2=8.8.8.8" >> /etc/sysconfig/network-scripts/ifcfg-eth0
  - /bin/echo "DNS3=8.8.4.4" >> /etc/sysconfig/network-scripts/ifcfg-eth0
  - /bin/echo "IPV6_PRIVACY=no" >> /etc/sysconfig/network-scripts/ifcfg-eth0
  - /bin/echo "ZONE=" >> /etc/sysconfig/network-scripts/ifcfg-eth0
  - /bin/echo "search ${K8_DOMAIN}" > /etc/resolv.conf
  - /bin/echo "nameserver ${K8_DNS_SERVER_1}" >> /etc/resolv.conf
  - /bin/echo "nameserver 8.8.8.8" >> /etc/resolv.conf
  - /bin/echo "nameserver 8.8.4.4" >> /etc/resolv.conf
_EOF_
)
    fi

    # Create log file
    touch ${VMNAME}.log

    # cloud-init config: set hostname, remove cloud-init package,
    # and add ssh-key
    cat > $USER_DATA << _EOF_
Content-Type: multipart/mixed; boundary="==BOUNDARY=="
MIME-Version: 1.0
--==BOUNDARY==
Content-Type: text/cloud-config; charset="us-ascii"

#cloud-config

# Hostname management
preserve_hostname: False
hostname: ${VMNAME}
fqdn: ${VMNAME}.${DNSDOMAIN}

# Users
users:
    - default
    - name: ${ADDITIONAL_USER}
      groups: ['${SUDOGROUP}']
      shell: /bin/bash
      sudo: ALL=(ALL) NOPASSWD:ALL
      ssh-authorized-keys:
        - ${KEY}
chpasswd:
  list: |
     root:${K8_VM_PASSWORD}
     ${ADDITIONAL_USER}:${K8_VM_PASSWORD}
  expire: False

# Configure where output will go
output:
  all: ">> /var/log/cloud-init.log"

# configure interaction with ssh server
ssh_genkeytypes: ['ed25519', 'rsa']

# allow ssh as root by setting this to false
disable_root: false

# Install my public ssh key to the first user-defined user configured
# in cloud.cfg in the template (which is centos for CentOS cloud images)
ssh_authorized_keys:
  - ${KEY}

timezone: ${TIMEZONE}

${nic_data}

network:
  config: disabled
  renderers: ['sysconfig', 'netplan', 'eni']

# Remove cloud-init when finished with it
runcmd:
  - /bin/echo "NAME=eth0" > /etc/sysconfig/network-scripts/ifcfg-eth0
  - /bin/echo "DEVICE=eth0" >> /etc/sysconfig/network-scripts/ifcfg-eth0
  - /bin/echo "HWADDR=${MAC}" >> /etc/sysconfig/network-scripts/ifcfg-eth0
  - /bin/echo "IPADDR=${IP}" >> /etc/sysconfig/network-scripts/ifcfg-eth0
  - /bin/echo "GATEWAY=${K8_GATEWAY}" >> /etc/sysconfig/network-scripts/ifcfg-eth0
  - /bin/echo "DNS1=${K8_DNS_SERVER_1}" >> /etc/sysconfig/network-scripts/ifcfg-eth0
  - /bin/echo "TYPE=Ethernet" >> /etc/sysconfig/network-scripts/ifcfg-eth0
  - /bin/echo "PROXY_METHOD=none" >> /etc/sysconfig/network-scripts/ifcfg-eth0
  - /bin/echo "BROWSER_ONLY=no" >> /etc/sysconfig/network-scripts/ifcfg-eth0
  - /bin/echo "BOOTPROTO=static" >> /etc/sysconfig/network-scripts/ifcfg-eth0
  - /bin/echo "DEFROUTE=yes" >> /etc/sysconfig/network-scripts/ifcfg-eth0
  - /bin/echo "IPV4_FAILURE_FATAL=no" >> /etc/sysconfig/network-scripts/ifcfg-eth0
  - /bin/echo "IPV6INIT=yes" >> /etc/sysconfig/network-scripts/ifcfg-eth0
  - /bin/echo "IPV6_AUTOCONF=yes" >> /etc/sysconfig/network-scripts/ifcfg-eth0
  - /bin/echo "IPV6_DEFROUTE=yes" >> /etc/sysconfig/network-scripts/ifcfg-eth0
  - /bin/echo "IPV6_FAILURE_FATAL=no" >> /etc/sysconfig/network-scripts/ifcfg-eth0
  - /bin/echo "IPV6_ADDR_GEN_MODE=stable-privacy" >> /etc/sysconfig/network-scripts/ifcfg-eth0
  - /bin/echo "ONBOOT=yes" >> /etc/sysconfig/network-scripts/ifcfg-eth0
  - /bin/echo "PREFIX=24" >> /etc/sysconfig/network-scripts/ifcfg-eth0
  - /bin/echo "DNS2=8.8.8.8" >> /etc/sysconfig/network-scripts/ifcfg-eth0
  - /bin/echo "DNS3=8.8.4.4" >> /etc/sysconfig/network-scripts/ifcfg-eth0
  - /bin/echo "IPV6_PRIVACY=no" >> /etc/sysconfig/network-scripts/ifcfg-eth0
  - /bin/echo "ZONE=" >> /etc/sysconfig/network-scripts/ifcfg-eth0
  - /bin/echo "search ${K8_DOMAIN}" > /etc/resolv.conf
  - /bin/echo "nameserver ${K8_DNS_SERVER_1}" >> /etc/resolv.conf
  - /bin/echo "nameserver 8.8.8.8" >> /etc/resolv.conf
  - /bin/echo "nameserver 8.8.4.4" >> /etc/resolv.conf
  - /bin/echo "" >> /etc/ssh/sshd_config
  - /bin/echo "# added for metalnetes" >> /etc/ssh/sshd_config
  - /bin/echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
  - /bin/echo "AllowUsers ${K8_VM_USER} root" >> /etc/ssh/sshd_config
  - /bin/echo "PermitEmptyPasswords no" >> /etc/ssh/sshd_config
  - /bin/echo "Port 22" >> /etc/ssh/sshd_config
  - systemctl restart ssh
  - ${NETRESTART}
  - ${CLOUDINITDISABLE}
_EOF_


    if [ ! -z "${SCRIPTNAME+x}" ]
    then
        SCRIPT=${SCRIPTDATA}
        cat >> $USER_DATA << _EOF_

--==BOUNDARY==
Content-Type: text/x-shellscript; charset="us-ascii"
${SCRIPT}

--==BOUNDARY==--
_EOF_
    else
       cat >> $USER_DATA << _EOF_

--==BOUNDARY==--
_EOF_
    fi

    { 
        echo "instance-id: ${VMNAME}";
        echo "local-hostname: ${VMNAME}";
    } > $META_DATA

    DISK=${VMNAME}.${storage_type}
    if [[ "${BOOT_MODE}" != "import-base" ]]; then
        outputn "Copying cloud image ($(basename ${IMAGE}))"
        cp $IMAGE $DISK && ok
        if $RESIZE_DISK
        then
            outputn "Resizing the disk to $DISK_SIZE"
            # Workaround to prevent virt-resize from renumbering partitions and breaking grub
            # See https://bugzilla.redhat.com/show_bug.cgi?id=1472039
            # Ubuntu will automatically grow the partition to the new size on its first boot
            if [[ "$DISTRO" = "ubuntu1804" ]] || [[ "$DISTRO" = "amazon2" ]]
            then
                qemu-img resize $DISK $DISK_SIZE &>> ${VMNAME}.log \
                    && ok \
                    || die "Could not resize disk."
            else
                echo ""
                anmt "${env_name} running: qemu-img create -f ${storage_type} -o preallocation=metadata $DISK.new $DISK_SIZE"
                last_status=$?
                if [[ "${storage_type}" == "qcow2" ]]; then
                    qemu-img create -f ${storage_type} \
                        -o preallocation=metadata $DISK.new $DISK_SIZE
                    last_status=$?
                else
                    qemu-img create -f ${storage_type} \
                        $DISK.new $DISK_SIZE
                fi
                if [[ "$?" != "0" ]]; then
                    die "failed qemu-img create disk: qemu-img create -f ${storage_type} -o preallocation=metadata $DISK.new $DISK_SIZE"
                fi
                anmt "${env_name} running: sudo virt-resize --quiet --expand /dev/sda1 $DISK $DISK.new"
                virt-resize --expand /dev/sda1 $DISK $DISK.new
                if [[ "$?" != "0" ]]; then
                    die "failed virt-resize disk: virt-resize --quiet --expand /dev/sda1 $DISK $DISK.new"
                fi
                mv $DISK.new $DISK
            fi
        fi
    fi

    # Create CD-ROM ISO with cloud-init config
    outputn "Generating ISO for cloud-init"
    if command -v genisoimage &>/dev/null
    then
        genisoimage -output $CI_ISO \
            -volid cidata \
            -joliet -r $USER_DATA $META_DATA &>> ${VMNAME}.log \
            && ok \
            || die "Could not generate ISO."
    else
        mkisofs -o $CI_ISO -V cidata -J -r $USER_DATA $META_DATA &>> ${VMNAME}.log \
            && ok \
            || die "Could not generate ISO."
    fi

    if [ "${VERBOSE}" -eq 1 ]
    then
        output "Creating storage pool with the following command"
        printf "    virsh pool-create-as \\ \n"
        printf "      --name ${VMNAME} \\ \n"
        printf "      --type dir \\ \n"
        printf "      --target ${VMDIR}/${VMNAME} \n"
    else
        outputn "Creating storage pool"
    fi

    # Create new storage pool for new VM
    echo ""
    anmt "$(date) - creating pool for vm ${VMNAME}"
    anmt "virsh pool-create-as --name ${VMNAME} --type dir --target ${VMDIR}/${VMNAME} &>> ${VMNAME}.log"
    virsh pool-create-as \
        --name ${VMNAME} \
        --type dir \
        --target ${VMDIR}/${VMNAME}
    if [[ "$?" != "0" ]]; then
        red "virsh pool-create-as --name ${VMNAME} --type dir --target ${VMDIR}/${VMNAME} &>> ${VMNAME}.log"
        die "Could not create storage pool."
    fi

    # Add custom MAC Address if specified
    if [ -z "${MACADDRESS}" ]
    then
        NETWORK_PARAMS="bridge=${BRIDGE},model=virtio"
    else
        NETWORK_PARAMS="bridge=${BRIDGE},model=virtio,mac=${MACADDRESS}"
    fi

    if [[ "${BOOT_MODE}" != "import-base" ]]; then
        if [ "${VERBOSE}" -eq 1 ]
        then
            output "Installing the domain with the following command"
            printf "    virt-install \\ \n"
            printf "      --import \\ \n"
            printf "      --name ${VMNAME} \\ \n"
            printf "      --memory ${MEMORY} \\ \n"
            printf "      --vcpus ${CPUS} \\ \n"
            printf "      --cpu ${FEATURE} \\ \n"
            printf "      --disk ${DISK},format=${storage_type},bus=virtio \\ \n"
            printf "      --disk ${CI_ISO},device=cdrom \\ \n"
            printf "      --network ${NETWORK_PARAMS} \\ \n"
            printf "      --os-type=linux \\ \n"
            printf "      --os-variant=${OS_VARIANT} \\ \n"
            printf "      --graphics ${GRAPHICS},port=${PORT},listen=localhost \\ \n"
            printf "      --noautoconsole  \n"
        else
            outputn "Installing the domain"
        fi

        # Call virt-install to import the cloud image and create a new VM
        yellow "$(date) - $(pwd) - virt-install --import --name ${VMNAME} --memory ${MEMORY} --vcpus ${CPUS} --cpu ${FEATURE} --disk ${DISK},format=${storage_type},bus=virtio --disk ${CI_ISO},device=cdrom --network ${NETWORK_PARAMS} --os-type=linux --os-variant=${OS_VARIANT} --graphics ${GRAPHICS},port=${PORT},listen=localhost --noautoconsole"
        virt-install --import \
            --name ${VMNAME} \
            --memory ${MEMORY} \
            --vcpus ${CPUS} \
            --cpu ${FEATURE} \
            --disk ${DISK},format=${storage_type},bus=virtio \
            --disk ${CI_ISO},device=cdrom \
            --network ${NETWORK_PARAMS} \
            --os-type=linux \
            --os-variant=${OS_VARIANT} \
            --graphics ${GRAPHICS},port=${PORT},listen=localhost \
            --noautoconsole
        if [[ "$?" != "0" ]]; then
            die "Could not create domain with virt-install."
        fi
    else
        new_dir=$(dirname ${DISK})
        if [[ ! -e ${new_dir} ]]; then
            mkdir -p -m 775 ${new_dir}
        fi
        anmt "$(date) - BOOT_MODE=${BOOT_MODE} - copying existing base: ${KVM_BASE_IMAGE_PATH} for: ${env_name}:${VMNAME} to disk location: ${DISK}"
        cp ${KVM_BASE_IMAGE_PATH} $DISK
        if [[ ! -e $DISK ]]; then
            err "$(date) - failed copying existing base: ${KVM_BASE_IMAGE_PATH} for: ${env_name}:${VMNAME} to disk location: ${DISK}"
            exit 1
        fi
        anmt "$(date) - creating ${VMNAME} existing base: ${KVM_BASE_IMAGE_PATH} for: ${env_name}:${VMNAME} disk: ${DISK}"
        if [ "${VERBOSE}" -eq 1 ]
        then
            output "Installing the domain with the following command"
            printf "    virt-install \\ \n"
            printf "      --import \\ \n"
            printf "      --name ${VMNAME} \\ \n"
            printf "      --memory ${MEMORY} \\ \n"
            printf "      --vcpus ${CPUS} \\ \n"
            printf "      --cpu ${FEATURE} \\ \n"
            printf "      --disk ${DISK},format=${storage_type},bus=virtio \\ \n"
            printf "      --network ${NETWORK_PARAMS} \\ \n"
            printf "      --os-type=linux \\ \n"
            printf "      --os-variant=${OS_VARIANT} \\ \n"
            printf "      --graphics ${GRAPHICS},port=${PORT},listen=localhost \\ \n"
            printf "      --noautoconsole  \n"
        else
            outputn "Installing the domain"
        fi

        # Call virt-install to import the cloud image and create a new VM
        yellow "$(date) - $(pwd) - virt-install --import --name ${VMNAME} --memory ${MEMORY} --vcpus ${CPUS} --cpu ${FEATURE} --disk ${DISK},format=${storage_type},bus=virtio --network ${NETWORK_PARAMS} --os-type=linux --os-variant=${OS_VARIANT} --graphics ${GRAPHICS},port=${PORT},listen=localhost --noautoconsole"
        virt-install --import \
            --name ${VMNAME} \
            --memory ${MEMORY} \
            --vcpus ${CPUS} \
            --cpu ${FEATURE} \
            --disk ${DISK},format=${storage_type},bus=virtio \
            --network ${NETWORK_PARAMS} \
            --os-type=linux \
            --os-variant=${OS_VARIANT} \
            --graphics ${GRAPHICS},port=${PORT},listen=localhost \
            --noautoconsole
        if [[ "$?" != "0" ]]; then
            die "Could not create domain with virt-install for importing from base: ${KVM_BASE_IMAGE_PATH}."
        fi
    fi
    virsh dominfo ${VMNAME} &>> ${VMNAME}.log

    # Enable autostart if true
    if $AUTOSTART
    then
        outputn "Enabling autostart"
        virsh autostart \
            --domain ${VMNAME} > /dev/null 2>&1 \
            && ok \
            || die "Could not enable autostart."
    fi

    # Eject cdrom
    media_device_name=$(virsh dumpxml ${VMNAME} | grep -A 5 cdrom  | grep dev | sed -e "s/'/ /g"| grep target | awk '{print $3}')
    if [[ "${media_device_name}" != "" ]]; then
        anmt "ejecting cdrom"
        anmt "virsh change-media ${VMNAME} ${media_device_name} --eject --config"
        virsh change-media ${VMNAME} ${media_device_name} --eject --config
        # Remove the unnecessary cloud init files
        anmt "Cleaning up cloud-init files"
        sudo rm $USER_DATA $META_DATA $CI_ISO && ok
    fi

    if [ -f "/var/lib/libvirt/dnsmasq/${BRIDGE}.status" ]
    then
        outputn "Waiting for domain to get an IP address"
        MAC=$(virsh dumpxml ${VMNAME} | awk -F\' '/mac address/ {print $2}')
        while true
        do
            IP=$(grep -B1 $MAC /var/lib/libvirt/dnsmasq/$BRIDGE.status | head \
                 -n 1 | awk '{print $2}' | sed -e s/\"//g -e s/,//)
            if [ "$IP" = "" ]
            then
                sleep 1
            else
                ok
                break
            fi
        done
        printf "\n"
        check_delete_known_host
    else
        outputn "Bridge looks like a layer 2 bridge, get the domain's IP address from your DHCP server"
        IP="<IP address>"
    fi

    printf "\n"
    output "SSH to ${VMNAME}: 'ssh ${LOGIN_USER}@${IP}' or 'ssh ${LOGIN_USER}@${VMNAME}'"
    CONSOLE=$(virsh domdisplay ${VMNAME})
    # Workaround because VNC port number shown by virsh domdisplay is offset from 5900
    if [ "${GRAPHICS}" = 'vnc' ]
    then
        CONSOLE_NO_PORT=$(echo $CONSOLE | cut -d ':' -f 1,2 -)
        CONSOLE_PORT=$(expr 5900 + $(echo $CONSOLE | cut -d ':' -f 3 -))
        output "Console at ${CONSOLE_NO_PORT}:${CONSOLE_PORT}"
    else
        output "Console at ${CONSOLE}"
    fi
    output "DONE"

    popd
}

# Delete VM
function remove ()
{
    # Parse command line arguments
    while getopts ":hv" opt
    do
        case "$opt" in
            v ) VERBOSE=1 ;;
            h ) usage ;;
            * ) die "Unsupported option. Run 'kvm-install-vm help remove'." ;;
        esac
    done

    if [ "$#" != 1 ]
    then
        printf "Please specify a single host to remove.\n"
        printf "Run 'kvm-install-vm help remove' for usage.\n"
        exit 1
    else
        VMNAME=$1
    fi

    # Check if domain exists and set DOMAIN_EXISTS variable.
    domain_exists "${VMNAME}"

    # Check if storage pool exists and set STORPOOL_EXISTS variable.
    storpool_exists "${VMNAME}"

    delete_vm "${VMNAME}"
}

function set_defaults ()
{
    # Defaults are set here. Override using command line arguments.
    AUTOSTART=false                 # Automatically start VM at boot time
    CPUS=${K8_VM_CPU}               # Number of virtual CPUs
    FEATURE=host                    # Use host cpu features to the guest
    MEMORY=${K8_VM_MEMORY}          # Amount of RAM in MB
    DISK_SIZE=${K8_VM_SIZE}         # Disk Size in GB
    DNSDOMAIN=${K8_DOMAIN}          # DNS domain
    GRAPHICS=spice                  # Graphics type
    RESIZE_DISK=false               # Resize disk (boolean)
    IMAGEDIR=${KVM_IMAGES_DIR}      # Directory to store images
    VMDIR=${KVM_VMS_DIR}            # Directory to store virtual machines
    BRIDGE=${K8_VM_BRIDGE}          # Hypervisor bridge
    PUBKEY=""                       # SSH public key
    DISTRO=k8                       # Distribution
    MACADDRESS=""                   # MAC Address
    PORT=-1                         # Console port
    TIMEZONE=${K8_VM_TZ}            # Timezone
    ADDITIONAL_USER=${K8_VM_USER}   # User
    VERBOSE=0                       # Verbosity

    # Reset OPTIND
    OPTIND=1
}

function set_custom_defaults ()
{
    # Source custom defaults, if set
    if [ -f ~/.kivrc ];
    then
        source ${HOME}/.kivrc
    fi
}

function create ()
{
    # Parse command line arguments
    while getopts ":b:c:d:D:f:g:i:k:l:L:m:M:p:s:t:T:u:ahv" opt
    do
        case "$opt" in
            a ) AUTOSTART=${OPTARG} ;;
            b ) BRIDGE="${OPTARG}" ;;
            c ) CPUS="${OPTARG}" ;;
            d ) DISK_SIZE="${OPTARG}" ;;
            D ) DNSDOMAIN="${OPTARG}" ;;
            f ) FEATURE="${OPTARG}" ;;
            g ) GRAPHICS="${OPTARG}" ;;
            i ) IMAGE="${OPTARG}" ;;
            k ) PUBKEY="${OPTARG}" ;;
            l ) IMAGEDIR="${OPTARG}" ;;
            L ) VMDIR="${OPTARG}" ;;
            m ) MEMORY="${OPTARG}" ;;
            M ) MACADDRESS="${OPTARG}" ;;
            p ) PORT="${OPTARG}" ;;
            s ) SCRIPTNAME="${OPTARG}";;
            t ) DISTRO="${OPTARG}" ;;
            T ) TIMEZONE="${OPTARG}" ;;
            u ) ADDITIONAL_USER="${OPTARG}" ;;
            v ) VERBOSE=1 ;;
            h ) usage ;;
            * ) die "Unsupported option. Run 'kvm-install-vm help create'." ;;
        esac
    done
    if [[ "${SCRIPTNAME}" != "" ]]; then
        SCRIPTDATA=$(cat ${SCRIPTNAME})
    fi

    shift $((OPTIND - 1))

    # Resize disk if you specify a disk size either via cmdline option or .kivrc
    if [ -n "${DISK_SIZE}" ]
    then
        RESIZE_DISK=true
        DISK_SIZE="${DISK_SIZE}G"   # Append 'G' for Gigabyte
    fi

    # After all options are processed, make sure only one variable is left (vmname)
    if [ "$#" != 1 ]
    then
        printf "Please specify a single host to create.\n"
        printf "Run 'kvm-install-vm help create' for usage.\n"
        exit 1
    else
        VMNAME=$1
    fi

    # Set cloud-init variables after VMNAME is assigned
    USER_DATA=user-data
    META_DATA=meta-data
    CI_ISO=${VMNAME}-cidata.iso

    # Check for ssh key
    check_ssh_key

    if [ ! -z "${IMAGE+x}" ]
    then
        output "Using custom QCOW2 image: ${IMAGE}."
        OS_VARIANT="auto"
        LOGIN_USER="<use the default account in your custom image>"
    else
        fetch_images
    fi

    # Check if domain already exists
    domain_exists "${VMNAME}"

    if [ "${DOMAIN_EXISTS}" -eq 1 ]; then
        echo -n "[WARNING] ${VMNAME} already exists.  "
        read -p "Do you want to overwrite ${VMNAME} [y/N]? " -r
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            remove ${VMNAME}
        else
            echo -e "\nNot overwriting ${VMNAME}. Exiting..."
            exit 0
        fi
    fi

    # Set network restart command
    set_network_restart_cmd

    # Set cloud init remove command
    set_cloud_init_remove

    # Set package manager
    set_sudo_group

    # Finally, create requested VM
    create_vm
}

function attach-disk ()
{
    # Set default variables
    FORMAT=${storage_type}

    # Parse command line arguments
    while getopts ":d:f:ps:t:h" opt
    do
        case "$opt" in
            d ) DISKSIZE="${OPTARG}G" ;;
            f ) FORMAT="${OPTARG}" ;;
            p ) PERSISTENT="${OPTARG}" ;;
            s ) SOURCE="${OPTARG}" ;;
            t ) TARGET="${OPTARG}" ;;
            h ) usage ;;
            * ) die "Unsupported option. Run 'kvm-install-vm help attach-disk'." ;;
        esac
    done

    shift $((OPTIND - 1))

    [ ! -z ${TARGET} ] || die "You must specify a target device, for e.g. '-t vdb'"
    [ ! -z ${DISKSIZE} ] || die "You must specify a size (in GB) for the new device, for e.g. '-d 5'"

    if [ "$#" != 1 ]
    then
        printf "Please specify a single host to attach a disk to.\n"
        printf "Run 'kvm-install-vm help attach-disk' for usage.\n"
        exit 1
    else
        # Set variables
        VMNAME=$1
        # Directory to create attached disk (Checks both images an vms directories for backward compatibility!)
        [[ -d ${VMDIR}/${VMNAME} ]] && DISKDIR=${VMDIR}/${VMNAME} || DISKDIR=${IMAGEDIR}/${VMNAME}
        DISKNAME=${VMNAME}-${TARGET}-${DISKSIZE}.${FORMAT}

        if [ ! -f "${DISKDIR}/${DISKNAME}" ]
        then
            outputn "Creating new '${TARGET}' disk image for domain ${VMNAME}"
            (qemu-img create -f ${FORMAT} -o size=$DISKSIZE,preallocation=metadata \
                ${DISKDIR}/${DISKNAME} &>> ${DISKDIR}/${VMNAME}.log  && ok ) && \

            outputn "Attaching ${DISKNAME} to domain ${VMNAME}"
            (virsh attach-disk ${VMNAME} \
                --source $DISKDIR/${DISKNAME} \
                --target ${TARGET} \
                --subdriver ${FORMAT} \
                --cache none \
                --persistent &>> ${DISKDIR}/${VMNAME}.log && ok ) \
                || die "Could not attach disk."
        else
            die "Target ${TARGET} is already created or in use."
        fi

    fi

}

#--------------------------------------------------
# Main
#--------------------------------------------------

subcommand="${1:-none}"
[[ "${subcommand}" != "none" ]] && shift

case "${subcommand}" in
    none)
        usage
        ;;
    help)
        if [[ "${1:-none}" == "none" ]]; then
            usage
        elif [[ "$1" =~ ^create$|^remove$|^list$|^attach-disk$ ]]; then
            usage_subcommand "$1"
        else
            printf "'$1' is not a valid subcommand.\n\n"
            usage
        fi
        ;;
    list)
        virsh list --all
        exit 0
        ;;
    create|remove|attach-disk|remove-disk)
        if [[ "${1:-none}" == "none" ]]; then
            usage_subcommand "${subcommand}"
        elif [[ "$1" =~ ^help$ ]]; then
            usage_subcommand "${subcommand}"
        else
            set_defaults
            set_custom_defaults
            "${subcommand}" "$@"
            exit $?
        fi
        ;;
    *)
        die "'${subcommand}' is not a valid subcommand.  See 'kvm-install-vm help' for a list of subcommands."
        ;;
esac

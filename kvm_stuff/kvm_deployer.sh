#!/bin/bash

# Please check out https://github.com/goffinet to see way better code
# Half of this was adapted from his deployment and the resource files would never 
# have been done without having his for reference.

# Script to setup VM environment for KVM
# Tested on debian11 / ubuntu 20.04
# Run with sudo ./kvm_setup.sh to check environment
# Run with one of the following arguments to install a VM
# sudo ./kvm_setup.sh debian|centos|ubuntu name_your_image

## Check if root. We need this for installation purposes
## https://askubuntu.com/questions/258219/how-do-i-make-apt-get-install-less-noisy
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

## Globals
## https://raw.githubusercontent.com/goffinet/virt-scripts/master/auto-install.sh
bridge="virbr0"
bridgeip4="192.168.122.1"
debian_iso="http://ftp.debian.org/debian/dists/stable/main/installer-amd64/"
centos8_iso="http://mirror.centos.org/centos/8-stream/BaseOS/x86_64/os/"
ubuntu_iso="http://en.archive.ubuntu.com/ubuntu/dists/focal/main/installer-amd64/"
autoconsole=""

# Colour mapping yoinked from linpeas as that output is always fucking clean as a whistle
# https://github.com/carlospolop/PEASS-ng/blob/master/linPEAS/builder/linpeas_parts/linpeas_base.sh
C=$(printf '\033')
RED="${C}[1;31m"
GREEN="${C}[1;32m"
YELLOW="${C}[1;33m"

check_args() {
	if [[ $# == 0 ]]; then
		echo $GREEN"[*] Attempting to set the system up for KVM only."
		system_kvm_check
	elif [[ $# != 2 ]]; then
		echo $RED"[!] Please provide 2 arguments: centos|debian|ubuntu and a name of your choosing!"
		echo $RED"[!] Example: sudo ./kvm_setup.sh centos mynewvm" 
		exit
	elif [[ $# == 2 ]]; then
		image=$1
		name=$2
		url_configuration="http://${bridgeip4}/conf/${image}-${name}.cfg"
		if [[ $image != "centos" ]] && [[ $image != "debian" ]] && [[ $image != "ubuntu" ]]; then
    	echo $RED"[!] Invalid image entered! [centos|debian|ubuntu]"
    	exit
		fi
		system_kvm_check
		selection
	fi
}

start_web () {
	apache_status=$(systemctl is-active apache2)
	if [[ $apache_status == "active" ]]; then
		echo $GREEN"[*] Apache service appears to be running!"
		mkdir -p "/var/www/html/conf"
	else
		echo $RED"[!] Apache service not running - Trying to start..."
		apt-get install apache2
		systemctl start apache2
		apache_status_2=$(systemctl is-active apache2)
		if [[ $apache_status_2 == "active" ]]; then
			echo $GREEN"[*] Apache service appears to be running now!"
			mkdir -p "/var/www/html/conf"
		else
			echo $RED"[!] Cannot install or start Apache2!"
		fi
	fi
}

system_kvm_check () {
	## Check if kvm is installed. Install if not.
	kvmcheck=$(which kvm)
	if [[ $kvmcheck == *"kvm"* ]]; then
		echo $GREEN"[*] KVM appears to be installed at $(which kvm)!"
	else
		echo $RED"[!] Cannot find KVM!"
		echo $YELLOW"[?] Try installing with sudo apt-get install qemu-kvm -y?"
		exit
	fi

	## Check processor supports it
	if [[ $(egrep -c '(vmx|svm)' /proc/cpuinfo) > 1 ]]; then
		echo $GREEN"[*] Sufficient hardware detected!"
	else
		echo $RED"[!] Insufficient hardware on the system!"
		echo $YELLOW"[?] Maybe check out how to allow nested virtualization in your hypervisor?"
		exit
	fi

	## Install kvm-ok checker
	## https://askubuntu.com/questions/258219/how-do-i-make-apt-get-install-less-noisy
	echo $YELLOW"[?] Installing cpu-checker..."
	sudo apt-get -qq install cpu-checker -y

	## If last command had no errors, it was installed
	if [[ $? == 0 ]]; then
		echo $GREEN"[*] cpu-checker installed!"
	else
		echo $RED"[!] Failed installing cpu-checker!"
	fi

	## Check kvm-ok says KVM acceleration can be used
	ok_string="KVM acceleration can be used"
	kvm_ok=$(kvm-ok)
	if [[ $kvm_ok == *$ok_string* ]]; then
		echo $GREEN"[*] KVM acceleration can be used!"
	else
		echo $RED"[!] Error checking if KVM acceleration can be used!"
	fi

	## Install pre-requisites checker
	echo $YELLOW"[?] Installing kvm pre-requisites..."
	sudo apt-get -qq install qemu-kvm libvirt-clients libvirt-daemon-system bridge-utils -y
	## If last command had no errors, it was installed
	if [[ $? == 0 ]]; then
		echo $GREEN"[*] Pre-requisites installed!"
	else
		echo $RED"[!] Failed installing KVM Pre-requisites"
		echo $RED"[!] Try running sudo apt-get install qemu-kvm libvirt-clients libvirt-daemon-system bridge-utils manually?"
	fi

	## Check if user already in kvm and libvirt groups
	kvm_group_check=$(cat /etc/group | grep 'kvm:')
	libvirt_group_check=$(cat /etc/group | grep 'libvirt:')

	## Since we're running the script as sudo, our $USER will be set to root
	## Get around it by using $SUDO_USER which appears to be set as the user executing
	## The script on most Linux distros?
	## Could we add a check later?
	## Pseudocode: if [[ $SUDO_USER ]] then ...
	## Works for now
	## https://stackoverflow.com/questions/1629605/getting-user-inside-shell-script-when-running-with-sudo

	if [[ $kvm_group_check == *"$SUDO_USER"* ]]; then 
		echo "[*] User $SUDO_USER is in the kvm group!"
	else 
		echo "[?] User $SUDO_USER is not in the kvm group! Adding now..."
		usermod -aG kvm $SUDO_USER
		if [[ $? == 0 ]]; then
			echo $GREEN"[*] $SUDO_USER added to the kvm group!"
		else
			echo $RED"[!] Failed adding user to the kvm group..."
		fi
	fi

	if [[ $libvirt_group_check == *"$SUDO_USER"* ]]; then 
		echo "[*] User $SUDO_USER is in the libvirt group!"
	else 
		echo "[?] User $SUDO_USER is not in the libvirt group! Adding now..."
		usermod -aG libvirt $SUDO_USER
		if [[ $? == 0 ]]; then
			echo $GREEN"[*] $SUDO_USER added to the libvirt group!"
		else
			echo $RED"[!] Failed adding user to the libvirt group..."
		fi
	fi

	## Install virt-manager
	sudo apt-get -qq install virt-manager -y
	## If last command had no errors, it was installed
	if [[ $? == 0 ]]; then
		echo $GREEN"[*] virt-manager is installed!"
	else
		echo $RED"[!] Failed installing virt-manager!"
		echo $RED"[!] Try running sudo apt-get install virt-manager -y manually?"
	fi

	## Check the service is running, nearly good to go
	libvirt_status=$(systemctl is-active libvirtd)

	## If "active", then it's running. If not, we'll try start it.
	if [[ $libvirt_status == "active" ]]; then
		echo $GREEN"[*] Libvirt service appears to be running!"
	else
		echo $RED"[!] Libvirt service does not appear to be running..."
		echo $YELLOW"[?] Trying to activate the service.."
		systemctl start libvirtd
		libvirt_status_2=$(systemctl is-active libvirtd)
		if [[ $libvirt_status_2 == "active" ]]; then
			echo $GREEN"[*] Libvirt service appears to be running!"
		else
			echo $RED"[!] Failed trying to start libvirt service. Look at the logs with systemctl status libvirtd."
		fi
	fi
}

#https://github.com/goffinet/virt-scripts/blob/master/auto-install.sh
# root:toor will be the login
debian_response_file () {
touch /var/www/html/conf/${image}-${name}.cfg
cat << EOF > /var/www/html/conf/${image}-${name}.cfg
d-i debian-installer/locale string en_GB.UTF-8
d-i keyboard-configuration/xkb-keymap select be
d-i netcfg/choose_interface select auto
d-i netcfg/get_hostname string unassigned-hostname
d-i netcfg/get_domain string unassigned-domain
d-i netcfg/wireless_wep string
d-i mirror/country string manual
d-i mirror/http/hostname string ftp.debian.org
d-i mirror/http/directory string /debian
d-i mirror/http/proxy string
d-i passwd/make-user boolean false
d-i passwd/root-password password toor
d-i passwd/root-password-again password toor
d-i clock-setup/utc boolean true
d-i time/zone string Europe/London
d-i clock-setup/ntp boolean true
d-i partman-auto/method string lvm
d-i partman-auto-lvm/guided_size string max
d-i partman-lvm/device_remove_lvm boolean true
d-i partman-md/device_remove_md boolean true
d-i partman-lvm/confirm boolean true
d-i partman-lvm/confirm_nooverwrite boolean true
d-i partman-auto/choose_recipe select atomic
d-i partman-partitioning/confirm_write_new_label boolean true
d-i partman/choose_partition select finish
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true
tasksel tasksel/first multiselect standard
d-i pkgsel/include string openssh-server vim
d-i pkgsel/upgrade select full-upgrade
popularity-contest popularity-contest/participate boolean false
d-i grub-installer/only_debian boolean true
d-i grub-installer/with_other_os boolean true
d-i grub-installer/bootdev  string /dev/vda
d-i finish-install/keep-consoles boolean true
d-i finish-install/reboot_in_progress note
d-i preseed/late_command string in-target sed -i 's/PermitRootLogin\ without-password/PermitRootLogin\ yes/' /etc/ssh/sshd_config ; in-target wget https://gist.githubusercontent.com/goffinet/f515fb4c87f510d74165780cec78d62c/raw/db89976e8c5028ce5502e272e49c3ed65bbaba8e/ubuntu-grub-console.sh ; in-target chmod +x ubuntu-grub-console.sh && sh ubuntu-grub-console.sh ; in-target shutdown -h now
EOF
}


redhat_response_file () {
read -r -d '' packages <<- EOM
@core
wget
EOM
touch /var/www/html/conf/${image}-${name}.cfg
cat << EOF > /var/www/html/conf/${image}-${name}.cfg
install
reboot
rootpw --plaintext testtest
keyboard --vckeymap=be-oss --xlayouts='be (oss)'
timezone Europe/London --isUtc
lang en_US.UTF-8
url --url="$centos8_iso"
firewall --disabled
network --bootproto=dhcp --device=eth0
network --bootproto=dhcp --device=eth1
network --hostname=$name
text
firstboot --enable
skipx
ignoredisk --only-use=vda
bootloader --location=mbr --boot-drive=vda
zerombr
clearpart --all --initlabel
autopart --type=lvm
%packages
$packages
%end
%post
yum -y update && yum -y upgrade
sed -i 's/console=ttyS0"/console=ttyS0 net.ifnames=0 biosdevname=0"/' /etc/default/grub
grub2-mkconfig > /boot/grub2/grub.cfg
%end
EOF
}

ubuntu_response_file () {
touch /var/www/html/conf/${image}-${name}.cfg
cat << EOF > /var/www/html/conf/${image}-${name}.cfg
d-i debian-installer/language                               string      en_GB:en
d-i debian-installer/country                                string      GB
d-i debian-installer/locale                                 string      en_GB
d-i debian-installer/splash                                 boolean     false
d-i localechooser/supported-locales                         multiselect en_GB.UTF-8
d-i pkgsel/install-language-support                         boolean     true
d-i console-setup/ask_detect                                boolean     false
d-i keyboard-configuration/modelcode                        string      pc105
d-i keyboard-configuration/layoutcode                       string      be
d-i debconf/language                                        string      en_US:en
d-i netcfg/choose_interface                                 select      auto
d-i netcfg/dhcp_timeout                                     string      5
d-i mirror/country                                          string      manual
d-i mirror/http/hostname                                    string      en.archive.ubuntu.com
d-i mirror/http/directory                                   string      /ubuntu
d-i mirror/http/proxy                                       string
d-i time/zone                                               string      Europe/Londom
d-i clock-setup/utc                                         boolean     true
d-i clock-setup/ntp                                         boolean     false
d-i passwd/root-login                                       boolean     false
d-i passwd/make-user                                        boolean     true
d-i passwd/user-fullname                                    string      tobz
d-i passwd/username                                         string      tobz
d-i passwd/user-password                                    password    zbot
d-i passwd/user-password-again                              password    zbot
d-i user-setup/allow-password-weak                          boolean     true
d-i passwd/user-default-groups                              string      adm cdrom dialout lpadmin plugdev sambashare
d-i user-setup/encrypt-home                                 boolean     false
d-i apt-setup/restricted                                    boolean     true
d-i apt-setup/universe                                      boolean     true
d-i apt-setup/backports                                     boolean     true
d-i apt-setup/services-select                               multiselect security
d-i apt-setup/security_host                                 string      security.ubuntu.com
d-i apt-setup/security_path                                 string      /ubuntu
tasksel tasksel/first                                       multiselect openssh-server
d-i pkgsel/include                                          string      openssh-server python-simplejson vim
d-i pkgsel/upgrade                                          select      safe-upgrade
d-i pkgsel/update-policy                                    select      none
d-i pkgsel/updatedb                                         boolean     true
d-i partman/confirm_write_new_label                         boolean     true
d-i partman/choose_partition                                select      finish
d-i partman/confirm_nooverwrite                             boolean     true
d-i partman/confirm                                         boolean     true
d-i partman-auto/purge_lvm_from_device                      boolean     true
d-i partman-lvm/device_remove_lvm                           boolean     true
d-i partman-lvm/confirm                                     boolean     true
d-i partman-lvm/confirm_nooverwrite                         boolean     true
d-i partman-auto-lvm/no_boot                                boolean     true
d-i partman-md/device_remove_md                             boolean     true
d-i partman-md/confirm                                      boolean     true
d-i partman-md/confirm_nooverwrite                          boolean     true
d-i partman-auto/method                                     string      lvm
d-i partman-auto-lvm/guided_size                            string      max
d-i partman-partitioning/confirm_write_new_label            boolean     true
d-i grub-installer/only_debian                              boolean     true
d-i grub-installer/with_other_os                            boolean     true
d-i finish-install/reboot_in_progress                       note
d-i finish-install/keep-consoles                            boolean     false
d-i cdrom-detect/eject                                      boolean     true
d-i preseed/late_command in-target sed -i 's/PermitRootLogin\ prohibit-password/PermitRootLogin\ yes/' /etc/ssh/sshd_config ; in-target wget https://gist.githubusercontent.com/goffinet/f515fb4c87f510d74165780cec78d62c/raw/db89976e8c5028ce5502e272e49c3ed65bbaba8e/ubuntu-grub-console.sh ; in-target sh ubuntu-grub-console.sh ; in-target sed -i 's/ens2/eth0/' /etc/netplan/01-netcfg.yaml ; in-target shutdown -h now
EOF
}

selection() {
case $image in
	debian)
		os="debian10"
		loc=$debian_iso
		config="url=$url_configuration"
		debian_response_file
		install_virt_guest
		interactive
		;;
	centos)
		os="rhel7.0"
		loc=$centos8_iso
		config="ks=$url_configuration"
		redhat_response_file
		install_virt_guest
		interactive
		;;
	ubuntu)
		os="ubuntu20.04"
		loc=$ubuntu_iso
		config="url=$url_configuration"
		ubuntu_response_file
		install_virt_guest
		interactive
		;;
	*)
esac
}

#https://computingforgeeks.com/virsh-commands-cheatsheet/
## We just wanna sit and wait for the user to decide what they want to do now
## start will start the vm they just created
## shutdown will shutdown the vm they just created
## destroy will force shutdown the vm
## reboot will reboot the vm they just created
## list will show all running vms
## rename <new_name> will rename the vm
interactive () {
echo $GREEN"[*] VM was set up!"
echo $YELLOW"[?] Available commands: start, shutdown, reboot, list"
echo $YELLOW"[?] Your VM will be opened in a new tab if you start it."
while true; do
	echo -en "command> "
	read input
	case $input in
		start) 
			virsh start $name --console
			echo $GREEN"[*] $name started! Connect to it with virsh connect $name in a new window."
			;;
		shutdown) 
			virsh shutdown $name
			;;
		reboot) 
			virsh reboot $name 
			;;
		destroy)
			virsh destroy $name
			exit
			;;
		list) 
			virsh list --all  
			;;
		*)
		echo $YELLOW"[?] Available commands: start, shutdown, reboot, list"
		;;
	esac
done
}


install_virt_guest () {
	virt-install \
	--virt-type=kvm \
	--name=$name \
	--disk path=/var/lib/libvirt/images/$name.qcow2,size=30,format=qcow2 \
	--ram="4096" \
	--vcpus="2" \
	--os-variant=$os \
	--network bridge=$bridge \
	--graphics none \
	--noreboot \
	--console pty,target_type=serial \
	--location $loc \
	-x "auto=true hostname=$name domain= $config text console=ttyS0"
}

#https://unix.stackexchange.com/questions/83299/why-is-always-0-in-my-function
check_args "$@"
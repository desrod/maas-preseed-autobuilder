#!/bin/bash
##################
#        _._   
#       /_ _`.      (c) 2016, David A. Desrosiers
#       (.(.)|      david dot desrosiers at canonical dot com
#       |\_/'|   
#       )____`\     FAI (Fully Automated Install) of MAAS
#      //_V _\ \ 
#     ((  |  `(_)   If you find this useful, please drop me 
#    / \> '   / \   an email, or send me bug reports if you find
#    \  \.__./  /   problems with it.
#     `-'    `-' 
#
##################

# Some variable debugging, this gets tricky because virt-install needs 
# a long, single-quoted set of options as a single option to --extra-args
#
# set -x


my_version="0.0.4"			# Just keeping versions intact
timeout="1"				# timeout for the default menu choice in cd installs
language="en"				# Language (used to force past the install menus)
locale="en_US.UTF-8"
country="US"


## Distribution specific details, to later make commandline args
##############################################################################
# distro_name="trusty"
# distro_version="14.04.4"		# Intended distro of Ubuntu to install from
distro_name="bionic"
distro_version="18.04"
arch="amd64"				# Architecture of the ISO or install path
iso_source="ubuntu-$distro_version-server-$arch.iso"

# mirror_host="192.168.1.10"		# eg: us.archive.ubuntu.com
mirror_host="us.archive.ubuntu.com"	# eg: us.archive.ubuntu.com
mirror_path="/ubuntu"			# Where on the MIRROR_HOST is the install path rooted

iso_path="$PWD/"			# Where to create the custom, remastered ISO image to boot from
iso_name="custom.iso"			# Name of the custom, remastered ISO image

remaster_path="$iso_path/remaster"	# Where is the unpacked, original iso
image_path="/var/lib/libvirt/images"	# Location for the disk image for the node


## User settings for the admin user in this maas node, if you do not pass
## these on the commandline, they'll be set to the values below. The password
## is crypted, so just enter the plaintext here. 
##############################################################################
node_username="ubuntu"
node_fullname="Ubuntu User"
node_userpass="openstack"


## Node-specific name and network details
##############################################################################
node_domain="maas"			# Domain of the maas node (foo.DOMAIN)
node_name="maas-test"			# Hostname of your maas node
node_network="cloud"			# Which network will it reside on
node_ip="192.168.100.4"			# IP of the maas node
node_netmask="255.255.255.0"		# Subnet of the maas node
node_nameserver="192.168.1.254"		# Upstream NS of the maas node
node_gateway="192.168.100.1"		# Gatedway of the maas node


## Path to the various preseed files, HTTP (remote) vs. file (local)
##############################################################################
# Remote preseed sitting over HTTP
preseed_http="preseed/url=http://$mirror_host/preseed.cfg"

# Injected preseed into the remastered ISO file
preseed_cdrom="preseed/file=/cdrom/preseed/unattended.seed"

# Local file on same host running this script
# preseed_local="preseed/file=$remaster_path/preseed/unattended.seed"
preseed_local="preseed/file=/tmp/preseed.cfg"


## Additional packages to install in the node when built
##############################################################################
# packages="maas juju tmux screen atop htop nload"
packages="htop nload debconf-utils"


## Build out the array for virt-install to inject into the kernel load line
## These can go on one long line, but separated here for readability
##############################################################################
extra_args=("auto=true priority=critical")
extra_args+=("debian-installer/language=en debian-installer/locale=en_US")
extra_args+=("localechooser/lanuagelist=en kbd-chooser/method=en")
extra_args+=("localechooser/preferred-locale=en_US.UTF-8 debian-installer/country=US")
extra_args+=("console-setup/ask_detect=false")
extra_args+=("netcfg/disable_dhcp=true")
extra_args+=("netcfg/get_ipaddress=$node_ip")
extra_args+=("netcfg/get_netmask=$node_netmask")
extra_args+=("netcfg/get_gateway=$node_gateway")
extra_args+=("netcfg/get_nameservers=$node_nameserver")


## Upstream mirror location when installing via HTTP
##############################################################################
location="http://$mirror_host/ubuntu/dists/$distro_name/main/installer-$arch"


## Hash out the user-supplied username and password
function hash_userpass {
	local salt
	salt=$(strings /dev/urandom | grep -o '[[:alnum:]]' | head -n 30 | tr -d '\n'; echo)
	node_crypted_pass=$(openssl passwd -1 -salt "$salt" "$node_userpass")

	extra_args+=("passwd/user-password-crypted=$node_crypted_pass")

	## Some DEBUG
	#echo "Username: $node_username"
	#echo "Password: $node_userpass"
	#echo "Crypt...: $node_crypted_pass"
}


## Fix permissions on the unpacked, remastered ISO contents, this is so we can
## inject our modified changes to the three files needed for unattended install
##############################################################################
function fix_perms {
	sudo chown "$USER":"$USER" -R "$remaster_path"
	sudo chown "$USER":"$USER" "$iso_path/custom.iso"
	sudo chmod 0644 "$iso_path/custom.iso"
	sudo chmod 0755 "$remaster_path"/preseed "$remaster_path"/isolinux
	sudo chmod 0644 "$remaster_path"/isolinux/txt.cfg "$remaster_path"/isolinux/isolinux.cfg
}


## Build out and insert the modifications into the ISO file
##############################################################################
function build_templates {
	echo "$language" > "$remaster_path"/isolinux/lang
	envsubst < templates/unattended.template > "$remaster_path"/preseed/unattended.seed
	# envsubst < templates/unattended.template > "$$.seed"
	# egrep -v '(^#|^$)' "$$.seed" > "$remaster_path"/preseed/unattended.seed
	envsubst < templates/txt.template > "$remaster_path"/isolinux/txt.cfg
	envsubst < templates/isolinux.template > "$remaster_path"/isolinux/isolinux.cfg
}


## Remaster the CD with the newly-injected files, and create a new custom ISO 
## image from it
##############################################################################
function remaster_cd {
#	mkdir "$iso_path"/$$ && sudo mount -o loop "$iso_source" $$
#	rsync -avP --partial --inplace "$iso_path/$$/." "$remaster_path"
#	sudo umount  "$iso_path/$$" && rm -rf "$iso_path/$$"
	
	sudo mkisofs -r -V "Remastered Ubuntu Install CD" \
		-cache-inodes -R -J -l \
		-b isolinux/isolinux.bin \
		-c isolinux/boot.cat \
		-no-emul-boot \
		-boot-load-size 4 \
		-boot-info-table \
		-iso-level 4 \
		-o "$iso_path"/"$iso_name" \
		"$remaster_path"
}


## Execute the build of the MAAS server with all above modifications and 
## unattended configs
##############################################################################
# Some sample data
#        --connect qemu:///system \
#        --virt-type kvm \
#        --name maas2 \
#	--vcpus 8 \
#        --ram 4096 \
#        --disk /ssd/maas2.qcow2,format=qcow2 \
#	--network bridge=br0,mac=52:54:00:A2:DA:0E \
#        --graphics vnc \
#        -l ftp://ftp.utexas.edu/pub/ubuntu/dists/xenial/main/installer-amd64/ \
#        --os-variant ubuntutrusty


function build_maas() {
	time sudo /usr/bin/virt-install \
		--connect qemu:///system \
		--virt-type kvm \
		--os-type linux \
		--name "$node_name" \
		--vcpus sockets=2,cores=4,threads=2 \
		--ram 8192  \
		--disk path="$image_path"/"$node_name".img,bus=virtio,size=20 \
		--network network="$node_network",model=virtio \
		"${build_options[@]}" \
		-v
}

# read and write the same file in a pipeline: grep -v '^#' file | sponge file
edit_inline() ( 
	tmp=$(mktemp) && cat > "$tmp" && cat -- "$tmp" > "$1" && rm -- "$tmp"; 
) 

push_array() {     
  local arrayname=${1:?Array name required} #val=$2
  shift
  eval "$arrayname=( \"\$@\" \"\${$arrayname[@]}\" )"
}


## Export some variables so the templates can use them
export timeout language locale country distribution arch mirror_host mirror_path iso_path iso_name remaster_path image_path
export node_username node_fullname node_userpass node_crypted_pass
export node_domain node_name node_network node_ip node_netmask node_nameserver
export preseed packages location

PROGNAME="${0##*/}"

function usage() {
cat <<EOF
        Usage: $PROGNAME [options]

        Options: 

        -h|--help	Show this output
        -v|--version	Show version information
        
        -u|--username	Login username of the node user (default: ubuntu)
        -f|--fullname	Full human-readable node user name (default: Ubuntu User)
        -p|--password	Cleartext password of the node user (default: openstack)

	-i|--iso        Execute build from local ISO image
        -H|--http	Execute build from a remote HTTP repository
        
        -r|--remaster   Remaster the CD (unpack, customize, re-roll)

        -d|--distro	Distribution name of the source iso
        -a|--arch	Architecture of the source distro

EOF
}

#!/bin/sh
# POSIX

# Reset all variables that might be set
# file=
# verbose=0 # Variables to be evaluated as shell arithmetic should be initialized to a default or validated beforehand.

while :; do
    case $1 in
        -h|-\?|--help)
            usage
            exit
            ;;
        -u|--user)
		if [ -n "$2" ]; then
			node_username="$2"
			shift
		else
			printf 'ERROR: "--user" requires a non-empty username\n' >&2
			exit 1
		fi
		;;
 	-f|--fullname)
		if [ -n "$2" ]; then
			node_fullname="$2"
			shift
		fi
		;;
 	-p|--password)
		if [ -n "$2" ]; then
			node_userpass="$2"
			shift
		fi
		;;
 	-g|--generate)
        	echo "Generating preseed and templates, injecting into $remaster_path"
        	echo "Please copy $remaster_path/preseed/unattended.seed to $mirror_host before building via HTTP"
		;;
 	-i|--iso)
        	preseed="$preseed_cdrom"
        	extra_args+=("$preseed")
        	build_options=(--cdrom "$iso_path"/"$iso_name")
        	remaster_cd
		fix_perms
        	build_maas
		;;
 	-H|--http)
        	preseed="$preseed_http"
        	push_array extra_args "$preseed"
        	build_options=(--location URL --extra-args "${extra_args[*]}" --location "$location")
        	printf '%s\n\n' "${build_options[@]}"
        	exit
        	build_maas
		;;
 	-a|--arch)
		if [ -n "$2" ]; then
        		arch="$2"
        		echo "Building MAAS for $arch"
        		shift
		else
			printf 'ERROR: "--arch" requires a non-empty architecture\n' >&2
			exit 1
		fi
		;;
 	-d|--dist)
		if [ -n "$2" ]; then
        		distribution="$2"
        		echo "Building MAAS on $distribution"
        		shift
		else
			printf 'ERROR: "--arch" requires a non-empty Ubuntu distro name\n' >&2
			exit 1
		fi
		;;
 	-r|--remaster)
		remaster_cd
		;;
        --) # End of all options.
            shift
            break
            ;;
        -?*)
            printf 'WARN: Unknown option (ignored): %s\n' "$1" >&2
            ;;
        *) # Default case: If no more options then break out of the loop.
            break
    esac

    shift
done

if [ "$node_username" == "ubuntu" ] 
then
printf "Username not supplied, using default: %s\n" "$node_username"
fi

if [ "$node_userpass" == "openstack" ] 
then
printf "Password not supplied, using default: %s\n" "$node_userpass"
fi


fix_perms
hash_userpass "$node_userpass"
build_templates

# vim: tabstop=8 softtabstop=8 shiftwidth=8 noexpandtab

#!/bin/bash

# Give up on failure.
set -e

# Make sure we have the required components installed
apt-get update
apt-get install -y virtualbox mkisofs rdesktop

# Decide on a temporary directory.
TMP_DIR=/tmp/make_ovf.$$
mkdir $TMP_DIR

# Pull down and unpack the Ubuntu LTS ISO.
[ -f ubuntu.iso ] || wget -O ubuntu.iso http://www.ubuntu.com/start-download\?distro=server\&bits=64\&release=lts
mkdir $TMP_DIR/ubuntu
mount ubuntu.iso $TMP_DIR/ubuntu -o loop,ro

# Copy it, ready for remastering.
mkdir $TMP_DIR/ubuntu-remastered
cp -aR $TMP_DIR/ubuntu/. $TMP_DIR/ubuntu-remastered/

# Unmount the old ISO.
umount $TMP_DIR/ubuntu
rm -rf $TMP_DIR/ubuntu

# Overlay the isolinux and preseed configuration.
cp isolinux.cfg $TMP_DIR/ubuntu-remastered/isolinux/
cp ubuntu-server.seed $TMP_DIR/ubuntu-remastered/preseed/

# Build a remastered ISO, and remove the local directory copy.
mkisofs -r -V "Ubuntu Remastered" -cache-inodes -J -l -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -input-charset utf-8 -o $TMP_DIR/ubuntu-remastered.iso $TMP_DIR/ubuntu-remastered/
rm -rf ubuntu-remastered

# Create and configure the virtual machine in VirtualBox.
VBoxManage createvm --name cw-aio --ostype Ubuntu_64 --register --basefolder $TMP_DIR
VBoxManage modifyvm cw-aio --memory 1652 --acpi on --boot1 dvd --nic1 nat --natpf1 "ssh,tcp,,8022,,22" --natpf1 "http,tcp,,8080,,80" --natpf1 "sip,tcp,,8060,,5060"
VBoxManage createhd --filename $TMP_DIR/cw-aio.vmdk --size 8000 --format VMDK
VBoxManage storagectl cw-aio --name "IDE Controller" --add ide
VBoxManage storageattach cw-aio --storagectl "IDE Controller" --port 0 --device 0 --type hdd --medium $TMP_DIR/cw-aio.vmdk
VBoxManage storageattach cw-aio --storagectl "IDE Controller" --port 1 --device 0 --type dvddrive --medium $TMP_DIR/ubuntu-remastered.iso

# Start the virtual machine headless, blocking until the installation is complete and the system powers down.
# If this hangs, it's probably that the installation has failed.
VBoxHeadless --startvm cw-aio

# Tidy up the ISO.
rm $TMP_DIR/ubuntu-remastered.iso

# Export an OVA file.
rm -rf cw-aio.ova
VBoxManage export cw-aio --output cw-aio.ova --manifest --vsys 0 --product Clearwater --producturl http://www.projectclearwater.org/ --vendor "Metaswitch Networks" --vendorurl http://www.metaswitch.com/ --version 1.0-$(date +%y%m%d.%H%M%S)
chmod a+r cw-aio.ova

# Destroy the virtual machine and the temporary directory.
VBoxManage unregistervm cw-aio --delete
rm -rf $TMP_DIR

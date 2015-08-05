#!/bin/bash

# Give up on failure.
set -e

repo=$1
[ -n "$repo" ] || repo=http://repo.cw-ngv.com/stable
echo Building from repo $repo...

# Make sure we have the required components installed
apt-get update
apt-get install -y virtualbox mkisofs rdesktop

# Decide on a temporary directory.
TMP_DIR=/tmp/make_ovf.$$
mkdir $TMP_DIR

# Pull down and unpack the Ubuntu LTS ISO.
os_image=http://releases.ubuntu.com/14.04.2/ubuntu-14.04.2-server-amd64.iso
[ -f ubuntu.iso ] || wget -O ubuntu.iso $os_image
mkdir $TMP_DIR/ubuntu
mount ubuntu.iso $TMP_DIR/ubuntu -o loop,ro

# Copy it, ready for remastering.
mkdir $TMP_DIR/ubuntu-remastered
cp -aR $TMP_DIR/ubuntu/. $TMP_DIR/ubuntu-remastered/

# Unmount the old ISO.
umount $TMP_DIR/ubuntu
rm -rf $TMP_DIR/ubuntu

# Overlay the isolinux and preseed configuration, fixing up the repo server.
cp isolinux.cfg $TMP_DIR/ubuntu-remastered/isolinux/
sed -e "s!repo=...!repo=$repo!g" ubuntu-server.seed > $TMP_DIR/ubuntu-remastered/preseed/ubuntu-server.seed

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

# Start the virtual machine, blocking until the installation is complete and the system powers down.
# If this hangs, it's probably that the installation has failed.
if [ "$DISPLAY" != "" ] ; then
  VirtualBox --startvm cw-aio
else
  VBoxHeadless --startvm cw-aio
fi

# Tidy up the ISO.
rm $TMP_DIR/ubuntu-remastered.iso

# Export an OVF.
mkdir -p $TMP_DIR/cw-aio.ovf
VBoxManage export cw-aio --output $TMP_DIR/cw-aio.ovf/cw-aio.ovf --manifest --vsys 0 --product Clearwater --producturl http://www.projectclearwater.org/ --vendor "Metaswitch Networks" --vendorurl http://www.metaswitch.com/ --version 1.0-$(date +%y%m%d.%H%M%S)

# Destroy the virtual machine to free up some space.
VBoxManage unregistervm cw-aio --delete

# Comment out the VirtualSystemType, as VMware doesn't always accept VirtualBox-generated OVFs.
sed -e 's/<vssd:VirtualSystemType/<!-- <vssd:VirtualSystemType/g
        s/<\/vssd:VirtualSystemType>/<\/vssd:VirtualSystemType> -->/g' < $TMP_DIR/cw-aio.ovf/cw-aio.ovf > $TMP_DIR/cw-aio.ovf/cw-aio.ovf.1
mv $TMP_DIR/cw-aio.ovf/cw-aio.ovf.1 $TMP_DIR/cw-aio.ovf/cw-aio.ovf

# Fix up the manifest.
grep -v cw-aio.ovf $TMP_DIR/cw-aio.ovf/cw-aio.mf > $TMP_DIR/cw-aio.ovf/cw-aio.mf.1
echo 'SHA1 (cw-aio.ovf)= '$(sha1sum $TMP_DIR/cw-aio.ovf/cw-aio.ovf | cut -d ' ' -f 1) >> $TMP_DIR/cw-aio.ovf/cw-aio.mf.1
mv $TMP_DIR/cw-aio.ovf/cw-aio.mf.1 $TMP_DIR/cw-aio.ovf/cw-aio.mf

# Repack the OVF as an OVA file.
rm -f cw-aio.ova
tar cf cw-aio.ova -C $TMP_DIR/cw-aio.ovf cw-aio.ovf cw-aio-disk1.vmdk cw-aio.mf

# Tidy up.
rm -rf $TMP_DIR

# Ubuntu OVF Images

This directory contains a tool for creating Ubuntu-based [OVF](http://dmtf.org/standards/ovf) images running an all-in-one Clearwater node.

You'll need a physical (non-VM-ed) 64-bit Ubuntu box.  This is because we generate the OVF within a VirtualBox instance, and VirtualBox does not run under virtualization.  It will probably run under any recent Ubuntu, but it has only been tested under Ubuntu 12.04.

To run the tool, change to this directory and run `sudo ./make_ovf.sh`.  If all goes well, it should

*   install VirtualBox (if not already installed)
*   download the Ubuntu 12.04 ISO (if not already downloaded)
*   remaster it so that it automatically installs Clearwater and then powers down
*   create a virtual machine under VirtualBox
*   boot the virtual machine off the remastered ISO
*   wait for it to install and power down
*   build an OVF from the virtual machine
*   tweak the OVF configuration file to make it compatible with VMware
*   build an OVA archive from the OVF.

The resulting OVA file is `cw-aio.ova`, in this directory.

Note that the installation process can take around half an hour, and will hang if it fails.  Generally, installation shouldn't fail as long as the Clearwater packages install OK on other platforms.  However, if this does happen you can see what's going on by looking at the VM console window (which should be on screen).  It's most likely you'll be at a login prompt, in which case Ubuntu has installed but Clearwater has failed.  You can log in as `ubuntu`/`cw-aio` and then run `sudo /etc/rc2.d/S99zclearwater-aio-first-boot` to retry the install (and see the error message).

`make_ovf.sh` accepts an optional command-line parameter that specifies which repo to build from.  The default is http://repo.cw-ngv.com/stable.

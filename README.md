# maas-preseed-autobuilder

Note: You will need to make sure to mount the ISO and copy its contents into
./remaster/, so the injection of the preseed files into that ISO image can
succeed. The easiest way to do that is: 

```
mkdir -p tmp remaster
sudo mount -oloop ubuntu-18.04-server-amd64.iso tmp
rsync -avP --partial tmp/. remaster/
sudo umount tmp
```

From there, you can then use ./build_maas.sh -r to remaster the CD, which
will produce a 'custom.iso' file in the current directory, with the preseed
files injected.

Then just run: 

```./build_maas.sh --iso``` 

This will boot from that ISO image and do the unattended install.


## Syntax
```
  Usage: build_maas.sh [options]

  Options: 

  -h|--help       Show this output
  -v|--version    Show version information
        
  -u|--username   Login username of the node user (default: ubuntu)
  -f|--fullname   Full human-readable node user name (default: Ubuntu User)
  -p|--password   Cleartext password of the node user (default: openstack)

  -i|--iso        Execute build from local ISO image
  -H|--http       Execute build from a remote HTTP repository
        
  -r|--remaster   Remaster the CD (unpack, customize, re-roll)

  -d|--distro     Distribution name of the source iso
  -a|--arch       Architecture of the source distro
```

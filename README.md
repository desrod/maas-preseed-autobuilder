# maas-preseed-autobuilder


## Building with a locally-remastered ISO: 

 Note: You will need to make sure to mount the ISO and copy its contents
 into ./remaster/, so the injection of the preseed files into that ISO image
 can succeed.  The easiest way to do that is:

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

## Building with a local mirror or remote repository over HTTP

 For this to work, you will need to copy your modified/customized
 preseed.cfg file to the remote webserver, so it can be referenced in the
 bootstrap.  

 In my case, I have a local Ubuntu mirror sitting at 192.168.1.10, mounted
 from a NAS.  In the root of that webserver, I've copied my preseed.cfg,
 which this bootstrap is configured to look for and use.

 You _can_ have the preseed.cfg and the remote mirror of the content on
 different servers, but I haven't tried that configuration.  YMMV, of
 course, and patches are welcome!


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

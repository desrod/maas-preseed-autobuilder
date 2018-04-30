# maas-preseed-autobuilder


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

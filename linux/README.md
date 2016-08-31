# Miscelaneous scripts

A collection of small scripts to simplify common tasks.

* add-ssh-key.sh - add SSH public keys to authorized_keys. The keys to add are read from a file and there is a check if a key with the same comment already exists in the authorized_keys file.
* reencrypt-ssh-key.sh - re-encrypts SSH private keys using 3DES in a PKCS#8 container
* getsysctl-values.sh - a short script to get all entries for net.* from /etc/sysctl.conf and print their current values from /proc/sys/net/*
* transfer-terminfo.sh - tranfer terminfo from one system to another using SSH. Useful when a remote server is missing an entry for your terminal emulator (eg. rxvt-unicode-256color).

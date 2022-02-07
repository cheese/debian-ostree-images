# Silverblue-compatible OSTree image of Debian Bookworm with GNOME

This project provides a makefile to build an OSTree image of Debian Bookworm with GNOME.
Silverblue and similar systems can be rebased to that image.

The final image is the `gnome` ref in the repo of `debian-repo` directory.

Cautions:

1. It is just a proof of concept. Only try it in a virtual machine.
2. Some manual steps are required after deploy and before reboot:
   a. OpenSSH of Debian doesn't accept the `ssh_keys` group.
   b. Manual regenerating /etc/shadow, which is too different from one of Fedora
```
sudo su
cd /ostree/deploy/fedora/deploy/DEPLOY_ID/ # replace DEPLOY_ID with the actual deploy id
cp usr/etc/shadow etc/ ; grep USER /etc/shadow >> etc/shadow ; chmod 600 etc/ssh/ssh*key # replace USER with the actual user name
```
3. Don't run any subcommand of `ostree admin` with side effect on the Debian deploy.

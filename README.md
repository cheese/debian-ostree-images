# Silverblue-compatible OSTree image of Arch Linux with DDE

This project provides a makefile to build an OSTree image of Arch Linux with DDE.
Silverblue and similar systems can be rebased to that image.

Cautions:

1. It is just a proof of concept. I won't further maintain this image. The DDE
   installation is neither complete nor tested. Only try it in a virtual machine.
2. Run `chmod 600 /etc/ssh/*key` before swithing to the new deploy, since
   OpenSSH of Arch Linux doesn't accept the `ssh_keys` group.
3. Don't run any subcommand of `ostree admin` with side effect on the Arch Linux deploy.

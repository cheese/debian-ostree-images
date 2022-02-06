DISTRO=debian
RELEASE=bookworm
REPO=$(DISTRO)-repo
REPO_TEMP=$(DISTRO)-temp-repo
ROOT=$(DISTRO)-root
HEADS=$(REPO_TEMP)/refs/heads

BRANCH=gnome
EXTRA_PKGS=gnome-core ssh-askpass-gnome

all: $(REPO)/refs/heads/$(BRANCH)

$(REPO)/refs/heads/$(BRANCH): $(HEADS)/extra $(REPO)/config
	rm -fr $(ROOT)
	ostree --repo=$(REPO_TEMP) checkout extra $(ROOT)

	#cp 90-ostree.preset $(ROOT)/usr/lib/systemd/system-preset
	#systemd-nspawn -D $(ROOT) systemctl preset-all

	cp -a nss-altfiles $(ROOT)
	systemd-nspawn -D $(ROOT) sh -c 'cd nss-altfiles; ./configure --prefix=/usr; make; mv libnss_altfiles.so.2  /usr/lib/x86_64-linux-gnu'
	rm -fr $(ROOT)/nss-altfiles

	systemd-nspawn -D $(ROOT) sh -c 'KVER=$$(basename $$(echo /lib/modules/*)); dracut --force --add-driver "virtio_blk virtio_scsi virtio_console virtio_pci nvme" /lib/modules/$$KVER/initramfs.img $$KVER; mv /boot/vmlinuz-$$KVER /lib/modules/$$KVER/vmlinuz; mv /boot/System.map-$$KVER /lib/modules/$$KVER/System.map; mv /boot/config-$$KVER /lib/modules/$$KVER/config'

	rpmdb --initdb --root $$(readlink -f $(ROOT)) --dbpath /usr/share/rpm
	rpm -Uvh --root $$(readlink -f $(ROOT)) --dbpath /usr/share/rpm fakeprovide-filesystem-20220111134517-1.fc34.noarch.rpm

	rm $(ROOT)/initrd.img* $(ROOT)/vmlinuz*
	rmdir $(ROOT)/home && ln -s var/home $(ROOT)/home
	rmdir $(ROOT)/mnt && ln -s var/mnt $(ROOT)/mnt
	rmdir $(ROOT)/opt && ln -s var/opt $(ROOT)/opt
	rm -fr $(ROOT)/root && ln -s var/roothome $(ROOT)/root
	rm -fr $(ROOT)/usr/local && ln -sf ../var/usrlocal $(ROOT)/usr/local
	rm -fr $(ROOT)/srv && ln -s var/srv $(ROOT)/srv
	mkdir $(ROOT)/sysroot
	ln -s sysroot/ostree $(ROOT)/ostree
	# There exits /usr/share/pacman, so I use /usr/share/pacmandb
	mv $(ROOT)/var/lib/dpkg $(ROOT)/usr/share/dpkgdb
	mv $(ROOT)/var/lib/apt $(ROOT)/usr/share/apt
	# add altfiles to passwd and group
	sed -i -r 's/(passwd:.*)/\1 altfiles/; s/(group:.*)/\1 altfiles/' $(ROOT)/etc/nsswitch.conf
	# allow user in wheel group to run sudo like on Fedora
	echo '%wheel  ALL=(ALL)       ALL' > $(ROOT)/etc/sudoers.d/wheel

	mv -v $(ROOT)/etc/ $(ROOT)/usr/
	cp $(ROOT)/usr/etc/passwd $(ROOT)/usr/etc/group $(ROOT)/usr/lib -v
	#cp grub2-15_ostree $(ROOT)/usr/etc/grub.d/
	cp ostree-0-integration.conf $(ROOT)/usr/lib/tmpfiles.d
	rm -fr $(ROOT)/var && mkdir $(ROOT)/var

	ostree --repo=$(REPO) commit --branch=$(BRANCH) $(ROOT)

$(HEADS)/extra: $(HEADS)/bootstrap
	rm -fr $(ROOT)
	ostree --repo=$(REPO_TEMP) checkout bootstrap $(ROOT)
	#mv $(ROOT)/etc/pacman.d/mirrorlist $(ROOT)/etc/pacman.d/mirrorlist.bak
	#echo 'Server = https://mirrors.sustech.edu.cn/archlinux/$$repo/os/$$arch' > $(ROOT)/etc/pacman.d/mirrorlist
	rm -fr $(ROOT)/var/cache/apt
	mkdir apt ||:
	mv apt $(ROOT)/var/cache
	systemd-nspawn -D $(ROOT) apt update
	systemd-nspawn -D $(ROOT) apt upgrade -y
	systemd-nspawn -D $(ROOT) apt install -y gcc make linux-image-amd64 dracut ostree-boot grub2 podman podman-toolbox sudo openssh-client btrfs-progs network-manager xorg vim openssh-server strace ibus-table-wubi ibus-anthy libvirt-daemon-driver-qemu virt-manager gdb task-english task-ssh-server systemd-timesyncd libnss-systemd dmraid- exim4-base- firefox-esr $(EXTRA_PKGS)  # interactive

	systemd-nspawn -D $(ROOT) dpkg-reconfigure locales
	mkdir -p $(ROOT)/var/lib/pam
	systemd-nspawn -D $(ROOT) pam-auth-update --force

	#systemd-nspawn -D $(ROOT) apt remove -y dmraid
	#systemd-nspawn -D $(ROOT) apt autoremove -y
	mv $(ROOT)/var/cache/apt .
	rm $(ROOT)/var/lib/dracut/console-setup-dir/etc/console-setup/null
	#mv $(ROOT)/etc/pacman.d/mirrorlist.bak $(ROOT)/etc/pacman.d/mirrorlist
	rm -f /boot/init*
	ostree --repo=$(REPO_TEMP) commit --branch=extra $(ROOT)

$(HEADS)/bootstrap: $(REPO_TEMP)/config
	rm -fr $(ROOT)
	debootstrap $(RELEASE) $(ROOT) https://mirrors.sustech.edu.cn/debian
	rm -vfr $(ROOT)/dev/*
	ostree --repo=$(REPO_TEMP) commit --branch=bootstrap $(ROOT)

$(REPO_TEMP)/config:
	ostree --repo=$(REPO_TEMP) init --mode=bare

$(REPO)/config:
	ostree --repo=$(REPO) init --mode=archive

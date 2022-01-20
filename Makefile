REPO=arch-repo
REPO_TEMP=temp-repo
ROOT=arch-root
HEADS=$(REPO_TEMP)/refs/heads

BRANCH=dde
EXTRA_PKGS=deepin deepin-extra deepin-anything-arch gnome-keyring lightdm

all: $(REPO)/refs/heads/$(BRANCH)

$(REPO)/refs/heads/$(BRANCH): $(HEADS)/extra $(REPO)/config
	rm -fr $(ROOT)
	ostree --repo=$(REPO_TEMP) checkout extra $(ROOT)

	cp 90-ostree.preset $(ROOT)/usr/lib/systemd/system-preset
	systemd-nspawn -D $(ROOT) systemctl preset-all

	cp -a nss-altfiles $(ROOT)
	systemd-nspawn -D $(ROOT) sh -c 'cd nss-altfiles; ./configure --prefix=/usr; make; make install'
	rm -fr $(ROOT)/nss-altfiles

	systemd-nspawn -D $(ROOT) sh -c 'KVER=$$(basename $$(echo /lib/modules/*)); dracut /lib/modules/$$KVER/initramfs.img $$KVER'

	rpmdb --initdb --root $$(readlink -f $(ROOT)) --dbpath /usr/share/rpm
	rpm -Uvh --root $$(readlink -f $(ROOT)) --dbpath /usr/share/rpm fakeprovide-filesystem-20220111134517-1.fc34.noarch.rpm

	rmdir $(ROOT)/home && ln -s var/home $(ROOT)/home
	rmdir $(ROOT)/mnt && ln -s var/mnt $(ROOT)/mnt
	# Arch installs files to /opt
	mv $(ROOT)/opt $(ROOT)/usr && ln -s usr/opt $(ROOT)/opt
	rm -fr $(ROOT)/root && ln -s var/roothome $(ROOT)/root
	rm -fr $(ROOT)/usr/local && ln -sf ../var/usrlocal $(ROOT)/usr/local
	rm -fr $(ROOT)/srv && ln -s var/srv $(ROOT)/srv
	mkdir $(ROOT)/sysroot
	ln -s sysroot/ostree $(ROOT)/ostree
	# There exits /usr/share/pacman, so I use /usr/share/pacmandb
	mv $(ROOT)/var/lib/pacman $(ROOT)/usr/share/pacmandb
	# add altfiles to passwd and group
	sed -i -r 's/(passwd:.*)/\1 altfiles/; s/(group:.*)/\1 altfiles/' $(ROOT)/etc/nsswitch.conf
	# allow user in wheel group to run sudo like on Fedora
	echo '%wheel  ALL=(ALL)       ALL' > $(ROOT)/etc/sudoers.d/wheel

	mv -v $(ROOT)/etc/ $(ROOT)/usr/
	cp $(ROOT)/usr/etc/passwd $(ROOT)/usr/etc/group $(ROOT)/usr/lib -v
	cp grub2-15_ostree $(ROOT)/usr/etc/grub.d/
	cp ostree-0-integration.conf $(ROOT)/usr/lib/tmpfiles.d
	rm -fr $(ROOT)/var && mkdir $(ROOT)/var

	ostree --repo=$(REPO) commit --branch=$(BRANCH) $(ROOT)

$(HEADS)/extra: $(HEADS)/bootstrap
	rm -fr $(ROOT)
	ostree --repo=$(REPO_TEMP) checkout bootstrap $(ROOT)
	mv $(ROOT)/etc/pacman.d/mirrorlist $(ROOT)/etc/pacman.d/mirrorlist.bak
	echo 'Server = https://mirrors.sustech.edu.cn/archlinux/$$repo/os/$$arch' > $(ROOT)/etc/pacman.d/mirrorlist
	rm -fr $(ROOT)/var/cache/pacman
	mkdir pacman ||:
	mv pacman $(ROOT)/var/cache
	systemd-nspawn -D $(ROOT) pacman -Syu --noconfirm
	systemd-nspawn -D $(ROOT) pacman -Sy --noconfirm gcc linux dracut ostree grub podman sudo openssh btrfs-progs networkmanager xorg vi $(EXTRA_PKGS)
	cp deepin-session-shell-5.4.58-2-x86_64.pkg.tar.zst $(ROOT)
	systemd-nspawn -D $(ROOT) pacman -U --noconfirm /deepin-session-shell-5.4.58-2-x86_64.pkg.tar.zst
	rm $(ROOT)/deepin-session-shell-5.4.58-2-x86_64.pkg.tar.zst
	mv $(ROOT)/var/cache/pacman .
	mv $(ROOT)/etc/pacman.d/mirrorlist.bak $(ROOT)/etc/pacman.d/mirrorlist
	ostree --repo=$(REPO_TEMP) commit --branch=extra $(ROOT)

$(HEADS)/bootstrap: $(REPO_TEMP)/config
	rm -fr $(ROOT)
	#cp -a ../myarch-builder $(ROOT)  # TODO
	./arch-bootstrap/arch-bootstrap.sh $(ROOT)
	rm -vf $(ROOT)/dev/*
	ostree --repo=$(REPO_TEMP) commit --branch=bootstrap $(ROOT)

$(REPO_TEMP)/config:
	ostree --repo=$(REPO_TEMP) init --mode=bare

$(REPO)/config:
	ostree --repo=$(REPO) init --mode=archive

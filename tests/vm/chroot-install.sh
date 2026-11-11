#!/usr/bin/env bash
# Inside the acceptance VM: put a fresh Arch on the blank second disk the way
# archinstall leaves one (an account, sudo for wheel, a bootloader), then
# follow docs/INSTALL.md's chroot steps as root. Boot the result with
# tools/vm/bloom-vm.sh boot-target. The account's password is "bloom" (VM only).
set -euo pipefail
DISK=/dev/vdb
sudo pacman -Sy --noconfirm --needed arch-install-scripts parted >/dev/null
sudo parted -s "$DISK" mklabel msdos mkpart primary ext4 1MiB 100% set 1 boot on
sudo mkfs.ext4 -qF "${DISK}1"
sudo mount "${DISK}1" /mnt
sudo pacstrap -K /mnt base linux grub sudo openssh >/dev/null
genfstab -U /mnt | sudo tee -a /mnt/etc/fstab >/dev/null
sudo install -Dm600 "$HOME/id_ed25519.pub" /mnt/home/bloom-key.pub
sudo arch-chroot /mnt bash -e <<'SETUP'
useradd -m -G wheel -s /bin/bash bloom
echo 'bloom:bloom' | chpasswd
echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/wheel
echo bloom-fresh > /etc/hostname
install -d -m700 -o bloom -g bloom /home/bloom/.ssh
install -m600 -o bloom -g bloom /home/bloom-key.pub /home/bloom/.ssh/authorized_keys
rm /home/bloom-key.pub
systemctl enable sshd >/dev/null 2>&1
grub-install --target=i386-pc /dev/vdb >/dev/null 2>&1
grub-mkconfig -o /boot/grub/grub.cfg >/dev/null 2>&1
SETUP
sudo cp "$HOME/bloom-dots.bundle" /mnt/root/
echo "== bloom install inside arch-chroot"
sudo arch-chroot /mnt bash -e <<'INSTALL'
pacman -S --needed --noconfirm git >/dev/null
git clone -q /root/bloom-dots.bundle /home/bloom/.local/share/bloom
git -C /home/bloom/.local/share/bloom checkout -q -B main
/home/bloom/.local/share/bloom/bin/bloom install --yes
INSTALL
# pacman's keyring agent outlives the chroot; stop it so the disk unmounts cleanly.
sudo arch-chroot /mnt gpgconf --homedir /etc/pacman.d/gnupg --kill gpg-agent 2>/dev/null || true
sync
sudo umount -R /mnt
echo "CHROOT_INSTALL=ok"

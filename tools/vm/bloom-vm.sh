#!/usr/bin/env bash
# Disposable Arch VM for Bloom's release acceptance (H6). Nothing here touches
# the host's packages or desktop: everything lives in $BLOOM_VM_DIR.
#
#   bloom-vm.sh up        create a fresh overlay on the verified base image and boot it
#   bloom-vm.sh up --screen  the same, in a window on the host desktop
#   bloom-vm.sh desktop   install Hyprland and kitty and log tty1 straight into Hyprland
#   bloom-vm.sh paste     copy the host clipboard into the VM's (then Ctrl+Shift+V in kitty)
#   bloom-vm.sh ssh ...   run a command in the VM as the test user
#   bloom-vm.sh push      copy this checkout (as a git bundle) into the VM
#   bloom-vm.sh down      power off and delete the overlay
#
# The base image is the official arch-boxes cloud image, checked against its
# published SHA-256 before use. The test user has passwordless sudo inside the
# VM only, so package steps run unattended; no host password is involved.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VM="${BLOOM_VM_DIR:-$HOME/Projects/bloom-vm}"
BASE="$VM/Arch-Linux-x86_64-cloudimg.qcow2"
DISK="$VM/acceptance.qcow2"
PORT="${BLOOM_VM_SSH_PORT:-2222}"
KEY="$VM/id_ed25519"

die() { echo "bloom-vm: $*" >&2; exit 1; }
ssh_vm() {
	ssh -i "$KEY" -p "$PORT" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
		-o LogLevel=ERROR -o ConnectTimeout=5 bloom@127.0.0.1 "$@"
}

up() {
	local display=(-vga std -display none) detach=(-daemonize)
	if [[ "${1:-}" == --screen ]]; then
		# virtio-vga in a GTK window; Hyprland renders with Mesa's software driver.
		display=(-device virtio-vga -display gtk,zoom-to-fit=on)
		detach=()
	fi
	[[ -f "$BASE" ]] || die "missing base image $BASE"
	(cd "$VM" && sha256sum -c --quiet Arch-Linux-x86_64-cloudimg.qcow2.SHA256) || die "base image checksum mismatch"
	[[ -f "$VM/qemu.pid" ]] && kill -0 "$(cat "$VM/qemu.pid")" 2>/dev/null && die "VM already running"
	[[ -f "$KEY" ]] || ssh-keygen -q -t ed25519 -N "" -C bloom-vm -f "$KEY"
	rm -f "$DISK"
	qemu-img create -q -f qcow2 -F qcow2 -b "$BASE" "$DISK" 24G
	mkdir -p "$VM/seed"
	printf 'instance-id: bloom-%s\nlocal-hostname: bloom-vm\n' "$(date +%s)" > "$VM/seed/meta-data"
	cat > "$VM/seed/user-data" <<EOF
#cloud-config
users:
  - name: bloom
    groups: [wheel, video, input]
    shell: /bin/bash
    sudo: "ALL=(ALL) NOPASSWD:ALL"
    lock_passwd: true
    ssh_authorized_keys: ["$(cat "$KEY.pub")"]
growpart: { mode: auto, devices: ["/"] }
EOF
	printf '' > "$VM/seed/vendor-data"
	# cloud-init's NoCloud source over HTTP from the host (QEMU's 10.0.2.2).
	python3 -m http.server --bind 127.0.0.1 --directory "$VM/seed" 8765 > "$VM/seed.log" 2>&1 &
	echo $! > "$VM/seed.pid"
	local qemu=(qemu-system-x86_64 -enable-kvm -cpu host -smp 2 -m 3072
		-drive file="$DISK",if=virtio,format=qcow2
		-netdev user,id=n0,hostfwd=tcp:127.0.0.1:"$PORT"-:22 -device virtio-net-pci,netdev=n0
		"${display[@]}" -serial file:"$VM/console.log"
		-smbios type=1,serial=ds='nocloud;s=http://10.0.2.2:8765/'
		-pidfile "$VM/qemu.pid" "${detach[@]}")
	if [[ ${#detach[@]} -eq 0 ]]; then
		# A window can't daemonize; run it detached so closing this shell keeps it.
		setsid -f "${qemu[@]}" > "$VM/qemu.log" 2>&1
	else
		"${qemu[@]}"
	fi
	for _ in $(seq 1 120); do
		ssh_vm true 2>/dev/null && { echo "VM is up (ssh port $PORT)"; ssh_vm 'cloud-init status --wait >/dev/null 2>&1 || true'; kill "$(cat "$VM/seed.pid")" 2>/dev/null || true; return 0; }
		sleep 2
	done
	kill "$(cat "$VM/seed.pid")" 2>/dev/null || true
	die "VM did not come up; see $VM/console.log"
}

push() {
	local bundle="$VM/bloom-dots.bundle"
	git -C "$ROOT" bundle create "$bundle" HEAD 2>/dev/null
	scp -i "$KEY" -P "$PORT" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
		"$bundle" "$ROOT/tests/vm/acceptance.sh" bloom@127.0.0.1:
	echo "pushed $(git -C "$ROOT" rev-parse --short HEAD)"
}

desktop() {
	ssh_vm 'sudo pacman -Syu --noconfirm --needed hyprland kitty git noto-fonts ttf-dejavu wl-clipboard' >/dev/null || die "package install failed"
	ssh_vm 'sudo mkdir -p /etc/systemd/system/getty@tty1.service.d && sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf >/dev/null' <<'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty -o '-p -f -- \\u' --noclear --autologin bloom %I $TERM
EOF
	# Software rendering: the VM has no GPU acceleration.
	ssh_vm 'cat > ~/.bash_profile' <<'EOF'
[[ -f ~/.bashrc ]] && . ~/.bashrc
if [[ "$(tty)" == /dev/tty1 && -z "$WAYLAND_DISPLAY" ]]; then
	export LIBGL_ALWAYS_SOFTWARE=1
	exec Hyprland
fi
EOF
	ssh_vm 'sudo systemctl daemon-reload && sudo systemctl restart getty@tty1'
	echo "tty1 now logs into Hyprland (Super+Q opens kitty)"
}

paste() {
	# wl-copy stays behind to serve the selection, so detach it from the SSH session.
	wl-paste --no-newline | ssh_vm 'export XDG_RUNTIME_DIR=/run/user/$(id -u); export WAYLAND_DISPLAY=$(cd "$XDG_RUNTIME_DIR" && ls wayland-* | grep -v lock | head -1); setsid -f wl-copy >/dev/null 2>&1'
	echo "copied into the VM clipboard"
}

down() {
	if [[ -f "$VM/qemu.pid" ]] && kill -0 "$(cat "$VM/qemu.pid")" 2>/dev/null; then
		ssh_vm 'sudo systemctl poweroff' 2>/dev/null || true
		for _ in $(seq 1 30); do kill -0 "$(cat "$VM/qemu.pid")" 2>/dev/null || break; sleep 1; done
		kill "$(cat "$VM/qemu.pid")" 2>/dev/null || true
	fi
	rm -f "$VM/qemu.pid" "$DISK"
	echo "VM removed (base image kept)"
}

case "${1:-}" in
	up) shift; up "$@" ;;
	desktop) desktop ;;
	paste) paste ;;
	ssh) shift; ssh_vm "$@" ;;
	push) push ;;
	down) down ;;
	*) echo "usage: $0 up [--screen]|desktop|paste|ssh CMD|push|down" >&2; exit 2 ;;
esac

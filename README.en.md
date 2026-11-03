# Linux driver for MacroSilicon USB display adapters (MS912x)

**[Leia em português](README.md)** | **English**

Kernel driver (DRM/KMS) for USB → VGA/HDMI adapters with a **MacroSilicon MS912x** chip,
installed through **DKMS** (rebuilt automatically when the kernel updates).

This repository is a **fork** of [rhgndf/ms912x](https://github.com/rhgndf/ms912x), the original
reverse-engineered driver. The original works, but in my setup (X11 + AMD GPU, USB 2.0 adapter
with VGA output) it stalled the whole desktop, made the cursor stutter and came back with a broken
picture after unplugging and replugging the cable. This fork fixes that. The changes are explained
below.

---

## What this fork changes compared to the original

| Problem in the original | Cause | What this fork does | Commit |
|---|---|---|---|
| Cursor and **every screen** froze while the USB monitor updated | Each update converted the image and **waited up to 10 ms on USB inside Xorg**. If the buffer was busy, the damage was dropped and the screen kept stale parts | Keeps a shadow copy of the screen, sends **only what really changed**, and runs USB in its own worker. Xorg never waits and nothing is dropped (based on PR [#45](https://github.com/rhgndf/ms912x/pull/45) by d093w1z) | `a4391b8` |
| Desktop froze ~1.5 s on every monitor probe | The EDID was read one byte per request (~6 ms each) inside Xorg, and an invalid EDID was read again and again | The driver polls HPD itself and reads the EDID in the background, four bytes per request, with a cache (based on PR [#46](https://github.com/rhgndf/ms912x/pull/46) by brainrom) | `613ff1d` |
| Idle Xorg at ~80% CPU | When another GPU renders the screen (reverse PRIME), the framebuffer lives in *write-combined* video memory, and reading it with plain `memcpy` took **~30 ms per frame** | Reads it with `drm_memcpy_from_wc()`, made for that kind of memory: **~30 ms → ~1 ms** per frame, idle Xorg at ~15% | `93fd9d0` |
| Does not build on kernel 7.2+ | Linux 7.2 renamed `drm_atomic_state` to `drm_atomic_commit` | Picks the right type from the kernel version, so DKMS keeps working after kernel updates | `5202575` |
| Duplicated, fragile install | The old script copied the `.ko` by hand **and** installed it through DKMS, and copied the whole folder to `/usr/src` | New install/uninstall scripts, DKMS only, removing old versions. The build uses the same compiler the kernel was built with | `042b421`, `8a7b3d9` |
| After replugging the cable, the monitor came back **with part of the picture black** | A mode set is several USB requests, and the background HPD/EDID reads were interleaved with that sequence | The mode set sequence now runs without interruption (`seq_lock`) | `8d12ac0` |
| After replugging, the VGA monitor sometimes came back as **"HDMI"**, and the desktop lost the screen layout | Right after power-up the chip reports "HDMI" until it detects the monitor (up to ~4 s) | The driver waits for the monitor to be detected (up to 5 s) before reading the port type. Probe is asynchronous, so the wait does not hold up the other USB ports | `8d12ac0` |

Tested on: Linux Mint 22.3 (kernel 7.0), Cinnamon on X11, AMD Ryzen 5700G (Radeon Vega),
`534d:6021` adapter (USB 2.0, VGA output) with a 1920×1080 monitor, next to two monitors on the
GPU itself. Kernel 7.2+ compatibility was checked against the kernel source, but not tested on a
real 7.2 kernel.

---

## Supported devices

| USB ID (`lsusb`) | USB | Device |
|---|---|---|
| `534d:6021` | 2.0 | MacroSilicon VGA/HDMI Display Adapter (the one tested here) |
| `534d:0821` | 2.0 | MacroSilicon Display Adapter |
| `345f:9132`, `345f:9133`, `345f:9135` | 3.0 | MacroSilicon MS913x Display Adapter |

---

## Installation

### 1. Dependencies

Debian, Ubuntu, Linux Mint and derivatives:

```bash
sudo apt install -y build-essential dkms linux-headers-$(uname -r)
```

Fedora: `sudo dnf install -y gcc make kernel-devel dkms`. Arch: `sudo pacman -S --needed base-devel linux-headers dkms`.

### 2. Download and install

```bash
git clone https://github.com/Davicjc/MacroSilicon-USBDisplay_Adapters-MS912.git
cd MacroSilicon-USBDisplay_Adapters-MS912
sudo bash instalar.sh
```

The script removes old versions, installs through DKMS and loads the driver. If the driver is
already loaded, the new version is used from the next boot. (The scripts print their messages in
Portuguese.)

### 3. Resolution

If the monitor does not report its resolutions (common with VGA, see below), pick the right
resolution once in your desktop's display settings. The desktop remembers it.

---

## Uninstall

```bash
sudo bash desinstalar.sh
```

---

## Known limitations and warnings

- **USB 2.0 (`534d:6021`)**: about 31 MB/s. Text, windows and the cursor are smooth because only
  the changed area is sent. Full-screen changes (full-screen 1920×1080 video) run at ~7 frames per
  second. That is the physical limit of the port.
- **VGA without EDID**: if the monitor or the VGA cable does not provide an EDID, the driver offers
  the standard modes (up to 1920×1200) and the desktop starts at 1024×768.
- **X11 with an AMD GPU (amdgpu): do not turn TearFree off.** With `Option "TearFree" "off"`, the
  USB monitor comes back with its top part black when it is replugged during a session. Keep the
  default ("auto").
- **Driver "CD"**: the first time a driver talks to it, the adapter hides its storage partition
  (with the Windows/macOS/Android installers) and re-enumerates on USB by itself. This is factory
  behaviour and only happens once.
- **`module verification failed ... tainting kernel` at boot**: DKMS signs the driver, but the
  kernel only trusts that key with Secure Boot on and the key enrolled on that PC
  (`mokutil --import`). With Secure Boot off, the driver works normally and the kernel is only
  marked as "tainted". The same happens with any out-of-tree driver, such as VirtualBox.

---

## For developers

- `insmod.sh` builds and loads the driver from this folder without installing it. For testing
  only; it is gone after a reboot.
- `re_notes/` holds the original author's reverse-engineering notes and scripts: how the USB
  commands, registers and image format were found.
- Code comments (`*.c`, `*.h`) stay in English, following the Linux kernel and the original
  project, so the changes remain easy to compare with it.

---

## Credits and license

- [rhgndf](https://github.com/rhgndf/ms912x): original driver and reverse engineering.
- [d093w1z](https://github.com/d093w1z): asynchronous sending with a shadow copy (PR #45).
- [brainrom](https://github.com/brainrom): background HPD and EDID (PR #46).
- Davi Castro: this fork, the WC-optimized read, reliable replug, kernel 7.2+ compatibility and
  the DKMS install.

GPL-2.0, same as the original (see `LICENSE`).

# Linux Driver for MacroSilicon USB Display Adapters (MS912x / MS912C)

**[Read in English](README.md)** | **[Leia em Português](README.pt-BR.md)**

---

Linux DRM/KMS kernel driver with **DKMS** support for external USB-to-VGA and USB-to-HDMI display adapters based on **MacroSilicon MS912x** chipsets.

Many of these adapters ship with an internal flash storage volume (~8 MB) containing drivers only for Windows (`.exe`), macOS (`.dmg`), and Android (`.apk`). This driver adds native Linux kernel support, enabling external displays to work seamlessly in desktop environments (GNOME, Cinnamon, KDE, XFCE, etc.).

---

## Supported Devices

| USB ID (`lsusb`) | Bus Speed | Device / Chipset |
|---|---|---|
| `534d:6021` | USB 2.0 | MacroSilicon VGA / HDMI Display Adapter |
| `534d:0821` | USB 2.0 | MacroSilicon Display Adapter |
| `345f:9132` | USB 3.0 | MacroSilicon MS913x Display Adapter |
| `345f:9133` | USB 3.0 | MacroSilicon MS913x Display Adapter |
| `345f:9135` | USB 3.0 | MacroSilicon MS913x Display Adapter |

---

## Features

- **Modern Kernel Compatibility**: Fixes DRM atomic helper signatures (`struct drm_atomic_state`) for Linux kernels 6.x and 7.x.
- **No desktop stalls** (upstream [PR #45](https://github.com/rhgndf/ms912x/pull/45)): shadow copy of the screen, only changed pixels are sent, USB runs in its own worker. Xorg commits never wait on USB and no damage is dropped.
- **Non-blocking hotplug** ([PR #46](https://github.com/rhgndf/ms912x/pull/46)): the driver polls HPD itself and prefetches the EDID in the background, four bytes per request, with a cache.
- **Fast reverse PRIME reads**: framebuffers imported from another GPU (write-combined memory) are read with `drm_memcpy_from_wc()`. On an AMD Cezanne each update went from ~30 ms to ~1 ms.
- **DKMS Support**: rebuilt automatically for new kernels, with the same compiler the kernel was built with.

---

## Installation

### 1. Install Build Dependencies

On Debian, Ubuntu, Linux Mint, and derivatives:

```bash
sudo apt update
sudo apt install -y build-essential linux-headers-$(uname -r) dkms
```

On Fedora / RHEL:

```bash
sudo dnf install -y gcc make kernel-devel dkms
```

On Arch Linux:

```bash
sudo pacman -S --needed base-devel linux-headers dkms
```

### 2. Clone & Install

```bash
git clone https://github.com/Davicjc/MacroSilicon-USBDisplay_Adapters-MS912.git
cd MacroSilicon-USBDisplay_Adapters-MS912
sudo bash install.sh
```

*(If you prefer Portuguese terminal output, you can run `sudo bash instalar.sh` instead).*

The script removes old versions, installs through DKMS and loads the driver.

### 3. X11 with an AMD GPU (amdgpu): turn TearFree off

On X11, the `amdgpu` driver enables TearFree automatically ("auto") for secondary outputs such as this adapter, and copies the whole screen every frame even when nothing changes. On the AMD's own outputs "auto" already means off, so this only affects the USB monitor:

```bash
sudo install -m 644 xorg/20-amdgpu-tearfree.conf /etc/X11/xorg.conf.d/
```

Then log out and back in. Not needed on Wayland or with Intel/NVIDIA GPUs.

---

## Known limitations

- **USB 2.0 (`534d:6021`)**: about 31 MB/s. Text, windows and the cursor are smooth because only changed areas are sent. Full-screen changes (full-screen 1920×1080 video) run at ~7 fps.
- **VGA adapters without EDID**: if the monitor or cable does not provide an EDID, the driver offers the standard modes (up to 1920×1200) and the desktop starts at 1024×768. Pick the right resolution once in the display settings.
- **Driver "CD"**: on the first command from a driver, the adapter hides its storage partition and re-enumerates on USB. This is factory behaviour.

---

## Uninstallation

To remove the driver from your system:

```bash
sudo bash uninstall.sh
sudo rm -f /etc/X11/xorg.conf.d/20-amdgpu-tearfree.conf   # if installed
```

---

## License

GPL-2.0. Based on community reverse engineering of MacroSilicon hardware protocols.

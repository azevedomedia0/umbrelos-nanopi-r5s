<img width="1200" height="520" alt="umbrel2" src="https://github.com/user-attachments/assets/54c9fb6f-068c-4744-9a1e-df70e8c333f5" />

# umbrelOS 2.0 for FriendlyElec NanoPi R5S (RK3568)

> [!WARNING]
> ### ⚠️ UNOFFICIAL COMMUNITY-MADE BUILD
> **This is an UNOFFICIAL, COMMUNITY-MADE BUILD of umbrelOS 2.0 for the FriendlyElec NanoPi R5S (Rockchip RK3568).**
> 
> * This project is **NOT** affiliated with, maintained by, sponsored by, or endorsed by **Umbrel, Inc.**
> * "Umbrel" and "umbrelOS" are trademarks of Umbrel, Inc.
> * For the official umbrelOS releases and officially supported hardware, please visit [umbrel.com](https://umbrel.com) and the official repository at [github.com/getumbrel/umbrel](https://github.com/getumbrel/umbrel).

---

## Overview

This repository provides custom, fully bootable images and build scripts to run **umbrelOS 2.0** on the **FriendlyElec NanoPi R5S** single-board computer (Rockchip RK3568 SoC).

### Key Features of this Build
* **umbrelOS 2.0 Core**: Official `umbreld` 2.0.0 daemon, redesigned Web UI, Photos app, Multi-user support, MCP AI Agent server, and App Store framework.
* **Rockchip 6.1 LTS Kernel**: Upstream Rockchip `6.1.141` kernel with complete device trees for all NanoPi R5S board revisions (`rev01` through `rev07`).
* **Multi-Gigabit Networking**: Full support for all 3 physical Ethernet ports:
  * 1× 1 Gbps WAN (`eth0`, Realtek RTL8211F)
  * 2× 2.5 Gbps LAN (`eth1` & `eth2`, Realtek RTL8125B)
  * Kernel multi-queue SMP interrupt affinity tuning (`setup-eth-smp`) enabled for line-rate 2.5 Gbps throughput.
* **Hardware Acceleration**: Rockchip Mali-G52 GPU userspace (`libmali`) and Rockchip NPU runtime (`rknpu`) pre-configured.
* **Onboard LEDs**: Configured with `friendlyelec_leds` service to drive SYS, WAN, and LAN activity indicators.
* **Automatic Storage Expansion**: Root partition auto-expands on initial boot via `systemd-growfs` to utilize 100% of available storage.
* **Local mDNS Discovery**: Avahi daemon enabled out of the box for instant discovery at `http://umbrel.local`.

---

## Specifications & Requirements

| Specification | Detail |
| :--- | :--- |
| **Target Board** | FriendlyElec NanoPi R5S |
| **Processor** | Rockchip RK3568 (Quad-Core ARM Cortex-A55 @ 2.0 GHz) |
| **Base Distribution** | Debian GNU/Linux 13 (Trixie) ARM64 |
| **Kernel** | Linux 6.1.141-rockchip-rk3568 |
| **Docker Engine** | 28.5.0 (with containerd) |
| **Node.js** | 22.13.0 LTS |
| **Default User** | `umbrel` (Password: `umbrel`) |
| **Web Dashboard** | `http://umbrel.local` |

---

## Installation Methods

Two image flavors are provided:

### Method 1: Install to Internal eMMC via eFlasher (Recommended)
This method installs umbrelOS 2.0 directly onto the NanoPi R5S's onboard 32 GB eMMC module for maximum speed and reliability.

1. Download **`umbrelos-2.0.0-nanopi-r5s-eflasher.img`** (or `umbrelos-2.0.0-nanopi-r5s-installer.iso`).
2. Flash the image to a MicroSD card using [Balena Etcher](https://etcher.balena.io/), [Raspberry Pi Imager](https://www.raspberrypi.com/software/), or `dd`:
   ```bash
   sudo dd if=umbrelos-2.0.0-nanopi-r5s-eflasher.img of=/dev/sdX bs=4M status=progress conv=fsync
   ```
3. Insert the MicroSD card into the NanoPi R5S, connect an Ethernet cable to your local network, and plug in the power supply.
4. The board will boot into FriendlyElec eFlasher and automatically flash umbrelOS 2.0 onto the internal eMMC.
5. When the flashing is complete, the onboard LEDs will turn solid.
6. Power off the board, remove the MicroSD card, and power it back on.
7. The device will boot umbrelOS 2.0 from eMMC.

### Method 2: Direct-Boot MicroSD Card Live Image
This method boots and runs umbrelOS 2.0 entirely off the MicroSD card without touching the internal eMMC storage.

1. Download **`umbrelos-2.0.0-nanopi-r5s-sd.img`** (or `umbrelos-2.0.0-nanopi-r5s.iso`).
2. Flash the image to a high-speed MicroSD card (A1/A2 rated, 16 GB or larger recommended):
   ```bash
   sudo dd if=umbrelos-2.0.0-nanopi-r5s-sd.img of=/dev/sdX bs=4M status=progress conv=fsync
   ```
3. Insert the MicroSD card into the NanoPi R5S and power on.
4. The system boots directly from the MicroSD card and automatically expands the root filesystem to fill the card.

---

## Getting Started

1. **Access the Dashboard**:
   Once booted, open a browser on any computer connected to the same local network and visit:
   ```
   http://umbrel.local
   ```
   *(If your network does not support mDNS, navigate to the IP address assigned by your router).*

2. **Complete First-Time Setup**:
   Follow the on-screen umbrelOS wizard to create your account and set up your personal server.

3. **SSH Access**:
   You can access the command line via SSH:
   ```bash
   ssh umbrel@umbrel.local
   # Default password: umbrel
   ```

---

## Building From Source

To rebuild the image from scratch, use the provided `build.sh` script:

```bash
# Clone this repository
git clone https://github.com/azevedomedia0/umbrelos-nanopi-r5s.git
cd umbrelos-nanopi-r5s

# Run the build script (requires Linux arm64 environment with root / sudo)
sudo ./build.sh
```

---

## Disclaimer

This software is provided "as is", without warranty of any kind, express or implied. In no event shall the authors or copyright holders be liable for any claim, damages, or other liability arising from the use of this software. umbrelOS is licensed by Umbrel, Inc. under the terms specified in their official repository.

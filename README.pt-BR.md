# Driver Linux para Adaptadores de Vídeo USB MacroSilicon (MS912x / MS912C)

**[Read in English](README.md)** | **[Leia em Português](README.pt-BR.md)**

---

Driver de kernel Linux (DRM/KMS) com suporte a **DKMS** para adaptadores externos USB para HDMI/VGA baseados nos chips **MacroSilicon MS912x**.

Esses adaptadores costumam vir de fábrica com uma pequena partição de armazenamento (~8 MB) contendo instaladores apenas para Windows (`.exe`), macOS (`.dmg`) e Android (`.apk`). Este driver adiciona suporte nativo no Linux, fazendo com que o monitor conectado pelo adaptador USB seja reconhecido normalmente nas configurações de tela do sistema (Cinnamon, GNOME, KDE, XFCE, etc.).

---

## Dispositivos suportados

| ID USB (`lsusb`) | Barramento | Chip / Dispositivo |
|---|---|---|
| `534d:6021` | USB 2.0 | MacroSilicon VGA / HDMI Display Adapter |
| `534d:0821` | USB 2.0 | MacroSilicon Display Adapter |
| `345f:9132` | USB 3.0 | MacroSilicon MS913x Display Adapter |
| `345f:9133` | USB 3.0 | MacroSilicon MS913x Display Adapter |
| `345f:9135` | USB 3.0 | MacroSilicon MS913x Display Adapter |

---

## Destaques desta versão

- **Compatibilidade com Kernel 6.x e 7.x**: correções nas assinaturas de callbacks DRM (`drm_atomic_state` nos helpers de CRTC e Plane).
- **Sem travar o desktop** ([PR #45](https://github.com/rhgndf/ms912x/pull/45) do upstream): cópia da tela (shadow), envio só do que mudou e USB num worker próprio. O commit do Xorg nunca espera a USB e nenhuma área alterada é descartada.
- **Detecção sem congelar** ([PR #46](https://github.com/rhgndf/ms912x/pull/46)): o próprio driver acompanha a conexão do monitor e lê o EDID em segundo plano, 4 bytes por requisição, com cache.
- **Leitura rápida em reverse PRIME**: o framebuffer vindo de outra GPU (memória write-combined) é lido com `drm_memcpy_from_wc()`. Numa AMD Cezanne, cada atualização caiu de ~30 ms para ~1 ms, e o Xorg parado de ~80% para ~15% de CPU.
- **Reconexão estável**: a troca de resolução (vários comandos USB) não é mais interrompida pelas leituras de HPD/EDID, e o driver espera o chip detectar o monitor antes de ler o tipo de porta (logo após ligar ele informa HDMI num adaptador VGA, e o desktop achava que era outro monitor). Probe assíncrono, para essa espera não segurar a USB.
- **Instalação com DKMS**: recompila sozinho a cada kernel novo, com o mesmo compilador usado no kernel.

---

## Como instalar

### 1. Pré-requisitos de compilação

No Debian, Ubuntu, Linux Mint e derivados:

```bash
sudo apt update
sudo apt install -y build-essential linux-headers-$(uname -r) dkms
```

No Fedora / RHEL:

```bash
sudo dnf install -y gcc make kernel-devel dkms
```

No Arch Linux:

```bash
sudo pacman -S --needed base-devel linux-headers dkms
```

### 2. Clonar e instalar

```bash
git clone https://github.com/Davicjc/MacroSilicon-USBDisplay_Adapters-MS912.git
cd MacroSilicon-USBDisplay_Adapters-MS912
sudo bash instalar.sh
```

*(Caso prefira mensagens em inglês no terminal, execute `sudo bash install.sh`).*

O script remove versões antigas, instala pelo DKMS e carrega o driver.

---

## Limitações conhecidas

- **USB 2.0 (`534d:6021`)**: cerca de 31 MB/s. Texto, janelas e mouse ficam lisos, porque só a área alterada é enviada. A tela inteira mudando (vídeo em tela cheia a 1920×1080) fica em ~7 quadros por segundo.
- **Adaptador VGA sem EDID**: se o monitor ou o cabo não entregam o EDID, o driver oferece os modos padrão (até 1920×1200) e o desktop começa em 1024×768. Escolha a resolução certa uma vez nas configurações de tela.
- **X11 com amdgpu: não desligue o TearFree.** Com `Option "TearFree" "off"` o monitor USB volta com a parte de cima preta quando é reconectado com a sessão aberta. Deixe o padrão ("auto").
- **"CD" de instalação**: ao receber o primeiro comando de um driver, o adaptador esconde a partição de armazenamento e reconecta sozinho na USB. Isso é comportamento de fábrica.

---

## Desinstalação

Caso queira remover o driver do sistema:

```bash
sudo bash desinstalar.sh
```

---

## Licença

GPL-2.0. Baseado no trabalho de engenharia reversa da comunidade para os chips MacroSilicon.

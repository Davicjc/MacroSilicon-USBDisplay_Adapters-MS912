# Driver Linux para adaptadores de vídeo USB MacroSilicon (MS912x)

Driver de kernel (DRM/KMS) para adaptadores USB → VGA/HDMI com chip **MacroSilicon MS912x**,
instalado pelo **DKMS** (recompila sozinho quando o kernel atualiza).

Este repositório é um **fork** do [rhgndf/ms912x](https://github.com/rhgndf/ms912x), o driver
original feito por engenharia reversa. O original funciona, mas no meu uso (X11 + placa AMD,
adaptador USB 2.0 com VGA) ele travava o desktop, fazia o mouse engasgar e voltava com a imagem
quebrada ao tirar e recolocar o cabo. Este fork corrige isso. O que mudou está explicado abaixo.

---

## O que este fork muda em relação ao original

| Problema no original | Causa | O que este fork faz | Commit |
|---|---|---|---|
| Mouse e **todas as telas** travavam enquanto o monitor USB atualizava | Cada atualização convertia a imagem e **esperava até 10 ms pela USB dentro do Xorg**. Se o buffer estava ocupado, a área alterada era descartada e a tela ficava com pedaços velhos | Guarda uma cópia da tela, envia **só o que mudou de verdade** e faz a USB num worker separado. O Xorg nunca espera e nada é descartado (base: PR [#45](https://github.com/rhgndf/ms912x/pull/45), de d093w1z) | `a4391b8` |
| Desktop congelava ~1,5 s a cada detecção de monitor | O EDID era lido um byte por vez (~6 ms cada) dentro do Xorg, e com EDID inválido a leitura ainda se repetia | O driver acompanha a conexão do monitor sozinho e lê o EDID em segundo plano, 4 bytes por vez, com cache (base: PR [#46](https://github.com/rhgndf/ms912x/pull/46), de brainrom) | `613ff1d` |
| Xorg em ~80% de CPU com o desktop parado | Com outra placa desenhando a tela (reverse PRIME), a imagem fica em memória de vídeo *write-combined*, e ler isso com `memcpy` comum levava **~30 ms por quadro** | Leitura com `drm_memcpy_from_wc()`, feita para esse tipo de memória: **~30 ms → ~1 ms** por quadro, Xorg parado em ~15% | `93fd9d0` |
| Não compila no kernel 7.2+ | O Linux 7.2 renomeou `drm_atomic_state` para `drm_atomic_commit` | Escolhe o tipo certo pela versão do kernel, então o DKMS continua funcionando quando o kernel atualiza | `5202575` |
| Instalação duplicada e frágil | O script antigo copiava o `.ko` à mão **e também** instalava pelo DKMS, e jogava a pasta inteira em `/usr/src` | Instalador e desinstalador novos, só pelo DKMS, removendo versões antigas. O build usa o mesmo compilador do kernel | `042b421`, `8a7b3d9` |
| Ao tirar e recolocar o cabo, o monitor voltava **com parte da imagem preta** | A troca de resolução são vários comandos USB, e as leituras de HPD/EDID em segundo plano entravam no meio da sequência | A sequência de troca de resolução roda inteira, sem interrupção (`seq_lock`) | `8d12ac0` |
| Ao recolocar o cabo, o monitor VGA às vezes voltava como **"HDMI"**, e o desktop perdia o arranjo das telas | Logo depois de ligar, o chip informa "HDMI" até detectar o monitor (até ~4 s) | O driver espera o monitor ser detectado (até 5 s) antes de ler o tipo de porta. O probe é assíncrono, então essa espera não segura as outras portas USB | `8d12ac0` |

Testado em: Linux Mint 22.3 (kernel 7.0), Cinnamon em X11, AMD Ryzen 5700G (Radeon Vega),
adaptador `534d:6021` (USB 2.0, saída VGA) com monitor 1920×1080, junto com dois monitores na
própria placa. A compatibilidade com o kernel 7.2+ foi conferida no código do kernel, mas não
testada num kernel 7.2 de verdade.

---

## Dispositivos suportados

| ID USB (`lsusb`) | USB | Dispositivo |
|---|---|---|
| `534d:6021` | 2.0 | MacroSilicon VGA/HDMI Display Adapter (o testado aqui) |
| `534d:0821` | 2.0 | MacroSilicon Display Adapter |
| `345f:9132`, `345f:9133`, `345f:9135` | 3.0 | MacroSilicon MS913x Display Adapter |

---

## Instalação

### 1. Dependências

Debian, Ubuntu, Linux Mint e derivados:

```bash
sudo apt install -y build-essential dkms linux-headers-$(uname -r)
```

Fedora: `sudo dnf install -y gcc make kernel-devel dkms`. Arch: `sudo pacman -S --needed base-devel linux-headers dkms`.

### 2. Baixar e instalar

```bash
git clone https://github.com/Davicjc/MacroSilicon-USBDisplay_Adapters-MS912.git
cd MacroSilicon-USBDisplay_Adapters-MS912
sudo bash instalar.sh
```

O script remove versões antigas, instala pelo DKMS e carrega o driver. Se o driver já estiver
carregado, a versão nova passa a valer no próximo boot.

### 3. Resolução

Se o monitor não informar as resoluções dele (comum em VGA, veja abaixo), escolha a resolução
certa uma vez em **Configurações → Monitores**. O desktop guarda a escolha.

---

## Desinstalação

```bash
sudo bash desinstalar.sh
```

---

## Limitações e avisos conhecidos

- **USB 2.0 (`534d:6021`)**: cerca de 31 MB/s. Texto, janelas e mouse ficam lisos porque só a
  área alterada é enviada. A tela inteira mudando (vídeo em tela cheia a 1920×1080) fica em
  ~7 quadros por segundo. Isso é limite físico da porta.
- **VGA sem EDID**: se o monitor ou o cabo VGA não entregam o EDID, o driver oferece os modos
  padrão (até 1920×1200) e o desktop começa em 1024×768.
- **X11 com placa AMD (amdgpu): não desligue o TearFree.** Com `Option "TearFree" "off"`, o
  monitor USB volta com a parte de cima preta quando é reconectado com a sessão aberta. Deixe o
  padrão ("auto").
- **"CD" de instalação**: na primeira vez que um driver fala com ele, o adaptador esconde a
  partição de armazenamento (com os instaladores de Windows/macOS/Android) e reconecta sozinho
  na USB. É comportamento de fábrica e acontece uma vez só.
- **Aviso `module verification failed ... tainting kernel` no boot**: o DKMS assina o driver,
  mas o kernel só confia na chave com o Secure Boot ligado e a chave cadastrada no PC
  (`mokutil --import`). Com o Secure Boot desligado, o driver funciona normalmente e o kernel
  só fica marcado como "tainted". O mesmo acontece com qualquer driver externo, como o do
  VirtualBox.

---

## Para quem for mexer no código

- `insmod.sh` compila e carrega o driver da pasta, sem instalar. Use só para testes; ele some no
  reboot.
- `re_notes/` tem as anotações e os scripts de engenharia reversa do autor original (em inglês):
  como os comandos USB, os registradores e o formato da imagem foram descobertos.
- Os comentários dentro do código (`*.c`, `*.h`) seguem em inglês, padrão do kernel Linux e do
  projeto original, para que as mudanças continuem fáceis de comparar com ele.

---

## Créditos e licença

- [rhgndf](https://github.com/rhgndf/ms912x): driver original e engenharia reversa.
- [d093w1z](https://github.com/d093w1z): envio assíncrono com cópia da tela (PR #45).
- [brainrom](https://github.com/brainrom): HPD e EDID em segundo plano (PR #46).
- Davi Castro: este fork, a leitura otimizada para memória WC, a reconexão estável, a
  compatibilidade com kernel 7.2+ e a instalação pelo DKMS.

Licença GPL-2.0, igual ao original (veja `LICENSE`).

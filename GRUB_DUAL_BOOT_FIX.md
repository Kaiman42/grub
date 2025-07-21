# Correção do GRUB em Dual Boot Fedora/Windows

## 📋 Resumo do Problema

Sistema com dual boot Fedora Linux 41 + Windows não exibia o menu do GRUB na inicialização, iniciando diretamente no Windows após a recriação da partição EFI do Windows.

## 🔍 Diagnóstico

### Sistema Operacional
- **OS**: Fedora Linux 41
- **Kernel**: 6.15.6-100.fc41.x86_64 (64-bit)
- **Desktop**: KDE Plasma 6.4.2
- **Hardware**: AMD Ryzen 5 5600GT, 16GB RAM, AMD Radeon RX 7600

### Estrutura de Partições Identificada
```bash
/dev/sdb2  300M  EFI System  # Partição EFI do Windows (recriada)
/dev/sdb3  600M  EFI System  # Partição EFI do Fedora
/dev/sdb4  ext4  /boot       # Boot do Fedora
/dev/sdb5  btrfs /           # Sistema Fedora
```

### Problema Identificado
- **Duas partições EFI separadas** causando conflito
- BIOS configurado para ler apenas a primeira partição EFI (`/dev/sdb2`)
- Windows Boot Manager tinha prioridade na ordem de boot
- Fedora instalado em partição EFI diferente (`/dev/sdb3`)

## 🛠️ Soluções Aplicadas

### 1. Verificação Inicial
```bash
# Verificar partições
lsblk -f

# Verificar ordem de boot EFI
efibootmgr -v

# Verificar conteúdo das partições EFI
sudo ls -la /boot/efi/EFI/
sudo mount /dev/sdb2 /mnt/efi2
sudo ls -la /mnt/efi2/EFI/
```

### 2. Tentativas Iniciais (Não Resolveram)
```bash
# Alterar ordem de boot
sudo efibootmgr -o 0007,0000

# Reinstalar GRUB
sudo dnf reinstall grub2-efi-x64 shim-x64

# Regenerar configuração
sudo grub2-mkconfig -o /boot/grub2/grub.cfg
```

### 3. Solução Final: Consolidação das Partições EFI

#### Passo 1: Mover Windows para a Partição EFI Maior
```bash
# Montar partição EFI do Windows
sudo mkdir -p /mnt/efi2
sudo mount /dev/sdb2 /mnt/efi2

# Copiar arquivos do Windows para a partição do Fedora (600MB)
sudo cp -r /mnt/efi2/EFI/Microsoft /boot/efi/EFI/
sudo cp -r /mnt/efi2/EFI/Boot /boot/efi/EFI/
```

#### Passo 2: Reconfigurar Entradas de Boot
```bash
# Criar nova entrada do Windows na partição correta
sudo efibootmgr -c -d /dev/sdb -p 3 -L "Windows Boot Manager" \
  -l "\\EFI\\Microsoft\\Boot\\bootmgfw.efi"

# Remover entrada antiga
sudo efibootmgr -b 0000 -B

# Configurar ordem: Fedora primeiro
sudo efibootmgr -o 0007,0001

# Aumentar timeout
sudo efibootmgr -t 10
```

#### Passo 3: Regenerar GRUB
```bash
# Regenerar configuração final
sudo grub2-mkconfig -o /boot/grub2/grub.cfg
```

## ✅ Resultados

### Antes da Correção
- ❌ Sistema iniciava diretamente no Windows
- ❌ GRUB não aparecia
- ❌ Duas partições EFI conflitantes
- ❌ Windows Boot Manager com prioridade

### Após a Correção
- ✅ Menu GRUB aparece na inicialização
- ✅ Timeout de 10 segundos para escolha
- ✅ Fedora como primeira opção
- ✅ Windows detectado corretamente
- ✅ Ambos sistemas na mesma partição EFI (600MB)
- ✅ 580MB livres para futuras atualizações

### Configuração Final
```bash
BootOrder: 0007,0001
Boot0007* Fedora        HD(3,GPT,.../SHIM.EFI
Boot0001* Windows Boot Manager  HD(3,GPT,.../bootmgfw.efi
Timeout: 10 seconds
```

## 🔧 Scripts Utilizados

### Script de Correção Automática
Localizado em: `/home/kaiman/fix_grub.sh`

## 📚 Recomendações

1. **Múltiplas partições EFI** podem causar conflitos em dual boot
2. **Recriação de partições EFI** pode alterar a ordem de boot
3. **Consolidação em uma única partição EFI** é mais estável
4. **Partição EFI maior** oferece mais espaço para atualizações
5. **efibootmgr** é essencial para gerenciar boot EFI

## 🚨 Prevenção

Para evitar problemas futuros:
- Manter ambos os sistemas na mesma partição EFI
- Fazer backup da configuração EFI antes de alterações
- Verificar ordem de boot após atualizações do Windows
- Desabilitar Fast Boot no Windows se necessário

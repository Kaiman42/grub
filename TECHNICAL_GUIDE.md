# Guia Técnico: Gerenciamento de Boot EFI em Dual Boot

## 🎯 Objetivo

Este guia fornece comandos e procedimentos técnicos para diagnosticar e corrigir problemas de boot EFI em sistemas dual boot Linux/Windows.

## 🔧 Comandos de Diagnóstico

### Verificação de Partições
```bash
# Listar todas as partições com filesystem
lsblk -f

# Verificar partições EFI especificamente
sudo fdisk -l | grep -i efi

# Verificar uso de espaço nas partições EFI
sudo df -h /boot/efi
```

### Análise do Boot EFI
```bash
# Listar entradas de boot EFI
efibootmgr -v

# Verificar ordem atual de boot
efibootmgr | grep BootOrder

# Verificar timeout atual
efibootmgr | grep Timeout
```

### Verificação de Arquivos EFI
```bash
# Conteúdo da partição EFI principal
sudo ls -la /boot/efi/EFI/

# Verificar arquivos do GRUB
sudo ls -la /boot/efi/EFI/fedora/

# Verificar arquivos do Windows (se presentes)
sudo ls -la /boot/efi/EFI/Microsoft/
```

## 🛠️ Comandos de Correção

### Gerenciamento de Ordem de Boot
```bash
# Definir Fedora como primeira opção (substitua 0007 pelo ID correto)
sudo efibootmgr -o 0007,0001

# Aumentar timeout para 10 segundos
sudo efibootmgr -t 10

# Remover entrada específica (substitua 0000 pelo ID)
sudo efibootmgr -b 0000 -B
```

### Criação de Entradas de Boot
```bash
# Criar entrada para Fedora
sudo efibootmgr -c -d /dev/sdb -p 3 -L "Fedora" \
  -l "\\EFI\\fedora\\shim.efi"

# Criar entrada para Windows
sudo efibootmgr -c -d /dev/sdb -p 3 -L "Windows Boot Manager" \
  -l "\\EFI\\Microsoft\\Boot\\bootmgfw.efi"
```

### Reinstalação e Configuração do GRUB
```bash
# Reinstalar pacotes GRUB EFI
sudo dnf reinstall grub2-efi-x64 shim-x64

# Regenerar configuração do GRUB
sudo grub2-mkconfig -o /boot/grub2/grub.cfg

# Verificar detecção de outros sistemas
sudo os-prober
```

## 📁 Gerenciamento de Partições EFI

### Montagem de Partições EFI Adicionais
```bash
# Criar ponto de montagem
sudo mkdir -p /mnt/efi2

# Montar partição EFI adicional
sudo mount /dev/sdb2 /mnt/efi2

# Verificar conteúdo
sudo ls -la /mnt/efi2/EFI/

# Desmontar quando terminar
sudo umount /mnt/efi2
sudo rmdir /mnt/efi2
```

### Consolidação de Partições EFI
```bash
# Copiar arquivos entre partições EFI
sudo cp -r /mnt/efi2/EFI/Microsoft /boot/efi/EFI/
sudo cp -r /mnt/efi2/EFI/Boot /boot/efi/EFI/

# Verificar espaço após cópia
sudo df -h /boot/efi
```

## 🔍 Troubleshooting

### Problemas Comuns

#### 1. Sistema inicia direto no Windows
**Diagnóstico:**
```bash
efibootmgr -v | head -5
```

**Solução:**
```bash
sudo efibootmgr -o [ID_LINUX],[ID_WINDOWS]
```

#### 2. GRUB não detecta Windows
**Diagnóstico:**
```bash
sudo os-prober
ls /boot/efi/EFI/
```

**Solução:**
```bash
sudo grub2-mkconfig -o /boot/grub2/grub.cfg
```

#### 3. Múltiplas partições EFI
**Diagnóstico:**
```bash
sudo fdisk -l | grep -i efi
mount | grep efi
```

**Solução:** Consolidar em uma única partição (ver seção anterior)

#### 4. Timeout muito baixo
**Diagnóstico:**
```bash
efibootmgr | grep Timeout
```

**Solução:**
```bash
sudo efibootmgr -t 10
```

## 🚨 Comandos de Emergência

### Restaurar Boot de Emergência
```bash
# Se o sistema não inicializar, use um Live USB e execute:

# Montar partições
sudo mount /dev/sdb5 /mnt  # Partição root do Linux
sudo mount /dev/sdb4 /mnt/boot  # Partição boot
sudo mount /dev/sdb3 /mnt/boot/efi  # Partição EFI

# Chroot no sistema
sudo chroot /mnt

# Reinstalar GRUB
grub2-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=fedora
grub2-mkconfig -o /boot/grub2/grub.cfg

# Sair do chroot
exit

# Desmontar
sudo umount /mnt/boot/efi /mnt/boot /mnt
```

## 📚 Referências

- [Fedora GRUB Documentation](https://docs.fedoraproject.org/en-US/fedora/latest/system-administrators-guide/kernel-module-driver-configuration/Working_with_the_GRUB_2_Boot_Loader/)
- [UEFI Boot Management](https://wiki.archlinux.org/title/Unified_Extensible_Firmware_Interface)
- [efibootmgr Manual](https://linux.die.net/man/8/efibootmgr)

---
**Última Atualização**: 21/07/2025  
**Versão**: 1.0  
**Compatibilidade**: Fedora 41, sistemas EFI

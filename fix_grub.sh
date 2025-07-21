#!/bin/bash

# Script para corrigir problemas do GRUB no dual boot

echo "=== Corrigindo problemas do GRUB ==="

# 1. Definir Fedora como primeira opção de boot
echo "1. Configurando ordem de boot..."
sudo efibootmgr -o 0007,0000

# 2. Aumentar timeout para dar tempo de escolher
echo "2. Aumentando timeout..."
sudo efibootmgr -t 10

# 3. Regenerar configuração do GRUB
echo "3. Regenerando configuração do GRUB..."
sudo grub2-mkconfig -o /boot/grub2/grub.cfg

# 4. Verificar se o Windows está detectado
echo "4. Verificando detecção do Windows..."
sudo os-prober

# 5. Mostrar configuração atual
echo "5. Configuração atual:"
efibootmgr -v

echo "=== Correção concluída ==="
echo "Reinicie o computador para testar."
echo "Se o problema persistir, pode ser necessário desabilitar o Fast Boot no Windows."

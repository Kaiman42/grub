#!/bin/bash

set -euo pipefail

echo "=== Corrigindo problemas do GRUB ==="

SUDO=""
if [[ $EUID -ne 0 ]]; then
	SUDO=sudo
fi

command -v efibootmgr >/dev/null 2>&1 || { echo "efibootmgr não encontrado. Instale-o antes de rodar o script." >&2; exit 1; }

echo "1) Lendo BootOrder e entradas..."
bootorder_raw=$($SUDO efibootmgr | awk -F': ' '/BootOrder/ {print $2}') || bootorder_raw=""
bootorder=${bootorder_raw// /}
if [[ -z "$bootorder" ]]; then
	echo "Não foi possível obter BootOrder." >&2
else
	echo "BootOrder atual: $bootorder"
fi

declare -A label_by_id
declare -A seen_label
boot_ids=()
while IFS= read -r line; do
	if [[ $line =~ ^(Boot[0-9A-Fa-f]{4})\*?[[:space:]]+(.*)$ ]]; then
		id=${BASH_REMATCH[1]}
		id=${id^^}
		label=${BASH_REMATCH[2]}
		label=$(echo "$label" | sed -E 's/\s+HD\(.*$//I' | sed -E 's/\s+File\(.*$//I' | sed -E 's/\s+$//')
		if [[ -z "$label" ]]; then
			continue
		fi

		if [[ -n "${label_by_id[$id]:-}" ]]; then
			continue
		fi
		lbl_lc=$(echo "$label" | tr '[:upper:]' '[:lower:]')

		if [[ $lbl_lc == *pxe* || $lbl_lc == *ipv4* || $lbl_lc == *ipv6* || $lbl_lc == *realtek* || $lbl_lc == *network* ]]; then
			continue
		fi
		if [[ -n "${seen_label[$lbl_lc]:-}" ]]; then
			continue
		fi
		seen_label[$lbl_lc]=1
		label_by_id[$id]="$label"
		boot_ids+=("$id")
	fi
done < <($SUDO efibootmgr -v)

if [[ ${#@} -gt 0 && "$1" == "--list" ]]; then
	echo "Entradas detectadas:" 
	for id in "${boot_ids[@]}"; do
		echo "  $id -> ${label_by_id[$id]}"
	done
	exit 0
fi

AUTO_RECREATE=0
TARGET=""

for a in "$@"; do
	case "$a" in
		--recreate|--persistent|--auto)
			AUTO_RECREATE=1
			;;
		--list)

			;;
		*)
			if [[ -z "$TARGET" ]]; then
				TARGET="$a"
			fi
			;;
	esac
done

normalize_id() {
	local v="$1"
	v=$(echo "$v" | sed -E 's/^boot//I')
	if [[ "$v" =~ ^[0-9]+$ ]]; then
		printf "%04X" "$v"
	else
		v=$(echo "$v" | tr '[:lower:]' '[:upper:]')
		if [[ ${#v} -lt 4 ]]; then
			printf "%04s" "$v" | sed 's/ /0/g'
		else
			echo "$v"
		fi
	fi
}

chosen_id=""
if [[ -n "$TARGET" ]]; then
	raw="$TARGET"
	raw_n=$(echo "$raw" | sed -E 's/^Boot//I')
	if [[ $raw_n =~ ^[0-9A-Fa-f]+$ ]]; then
		norm=$(normalize_id "$raw_n")
		for id in "${boot_ids[@]}"; do
			if [[ ${id^^} == *$norm ]]; then
				chosen_id=$id
				break
			fi
		done
	fi
	if [[ -z "$chosen_id" ]]; then
		targ_lc=$(echo "$TARGET" | tr '[:upper:]' '[:lower:]')
	for id in "${boot_ids[@]}"; do
			lbl=${label_by_id[$id]}
			lbl_lc=$(echo "$lbl" | tr '[:upper:]' '[:lower:]')
			if [[ $lbl_lc == *$targ_lc* ]]; then
				chosen_id=$id
				break
			fi
		done
	fi
	if [[ -z "$chosen_id" ]]; then
		echo "Alvo '$TARGET' não encontrado entre as entradas." >&2
		exit 2
	fi
else
	if [[ -t 0 ]]; then
		echo
		echo "Escolha a entrada que deve vir primeiro (digite o número) :"
		i=1
		for id in "${boot_ids[@]}"; do
			echo "  $i) $id -> ${label_by_id[$id]}"
			((i++))
		done
		read -rp "Número, ID (ex: Boot0001) ou texto (ou Enter para cancelar): " choice
		choice=$(echo -n "$choice" | tr -d ' \t\r')
		if [[ -z "$choice" ]]; then
			echo "Operação cancelada pelo usuário."; exit 0
		fi
		if [[ $choice =~ ^[0-9]+$ ]]; then
			idx=$((choice-1))
			if (( idx < 0 || idx >= ${#boot_ids[@]} )); then
				echo "Número fora do intervalo."; exit 4
			fi
			chosen_id=${boot_ids[$idx]}
		else
			c_raw=$(echo "$choice" | sed -E 's/^Boot//I')
			if [[ $c_raw =~ ^[0-9A-Fa-f]+$ ]]; then
				normc=$(normalize_id "$c_raw")
				for id in "${boot_ids[@]}"; do
					if [[ ${id^^} == *$normc ]]; then
						chosen_id=$id
						break
					fi
				done
			fi
			if [[ -z "$chosen_id" ]]; then
				targ_lc=$(echo "$choice" | tr '[:upper:]' '[:lower:]')
				for id in "${boot_ids[@]}"; do
					lbl=${label_by_id[$id]}
					lbl_lc=$(echo "$lbl" | tr '[:upper:]' '[:lower:]')
					if [[ $lbl_lc == *$targ_lc* ]]; then
						chosen_id=$id
						break
					fi
				done
			fi
			if [[ -z "$chosen_id" ]]; then
				echo "Entrada inválida."; exit 3
			fi
		fi
	else
		echo "Modo não interativo e sem alvo especificado; nada a fazer." >&2
		exit 1
	fi
fi

echo "Escolhido para primeiro: $chosen_id -> ${label_by_id[$chosen_id]}"

if [[ -t 0 ]]; then
	read -rp "Aplicar apenas para o próximo boot (teste) em vez de persistir? [y/N]: " one
	one=$(echo -n "$one" | tr '[:upper:]' '[:lower:]')
	if [[ "$one" == "y" || "$one" == "yes" ]]; then
		short=${chosen_id#BOOT}
		echo "Definindo BootNext=$short (apenas para o próximo boot)..."
		$SUDO efibootmgr -n "$short" >/dev/null 2>&1 || echo "Falha ao definir BootNext" >&2
		echo "Pronto. Reinicie para testar o boot único. Saindo sem alterar BootOrder." 
		exit 0
	fi
fi

IFS=',' read -r -a order_arr <<< "${bootorder^^}"

declare -A desired_set
chosen_lbl_lc=$(echo "${label_by_id[$chosen_id]}" | tr '[:upper:]' '[:lower:]')
for id in "${boot_ids[@]}"; do
	lbl=${label_by_id[$id]}
	lbl_lc=$(echo "$lbl" | tr '[:upper:]' '[:lower:]')
	if [[ $lbl_lc == *$chosen_lbl_lc* ]]; then
		short=${id#BOOT}
		desired_set[$short]=1
	fi
done

front_list=()
rest_list=()
declare -A added
for e in "${order_arr[@]}"; do
	[[ -z "$e" ]] && continue
	e_up=${e^^}
	if [[ $e_up =~ ^BOOT([0-9A-F]{4})$ ]]; then
		idnum=${BASH_REMATCH[1]}
	elif [[ $e_up =~ ^([0-9A-F]{4})$ ]]; then
		idnum=${BASH_REMATCH[1]}
	else

		continue
	fi
	if [[ -n "${added[$idnum]:-}" ]]; then
		continue
	fi
	if [[ -n "${desired_set[$idnum]:-}" ]]; then
		front_list+=("$idnum")
		added[$idnum]=1
	else
		rest_list+=("$idnum")
		added[$idnum]=1
	fi
done


for id in "${boot_ids[@]}"; do
	short=${id#BOOT}
	if [[ -z "${added[$short]:-}" ]]; then
		rest_list+=("$short")
		added[$short]=1
	fi
done

desired_order_parts=()
for id in "${front_list[@]}"; do desired_order_parts+=("$id"); done
for id in "${rest_list[@]}"; do desired_order_parts+=("$id"); done
desired_order=$(IFS=,; echo "${desired_order_parts[*]}")

if [[ "${bootorder^^}" == "$desired_order" ]]; then
	echo "A ordem já está correta (escolhido em primeiro)."
else
	echo "2) Ajustando BootOrder para: $desired_order"
	applied=0
	for attempt in 1 2 3; do
		$SUDO efibootmgr -o "$desired_order" >/dev/null 2>&1 || true
		sleep 1
		current=$($SUDO efibootmgr | awk -F': ' '/BootOrder/ {gsub(/ /, "", $2); print $2}' || echo "")
		if [[ "$current" == "$desired_order" ]]; then
			applied=1
			break
		fi
		echo "  tentativa $attempt falhou, readquirindo..."
	done
	if [[ $applied -eq 1 ]]; then
		echo "  BootOrder aplicado com sucesso."
	else
		echo "  Aviso: não foi possível persistir BootOrder no firmware." >&2
		echo "  BootOrder atual após tentativas: $current" >&2
		echo "  Pode ser necessário ajustar via firmware (UEFI/BIOS) ou remover entradas conflitantes." >&2
	fi
fi


if [[ -t 0 ]]; then
	read -rp "Deseja tentar recriar uma entrada EFI persistente (criar nova + setar ordem)? [y/N]: " persist
	persist=$(echo -n "$persist" | tr '[:upper:]' '[:lower:]')
	if [[ "$persist" == "y" || "$persist" == "yes" ]]; then
		ts=$(date +%Y%m%d%H%M%S)
		backup=/tmp/efibootmgr-backup-$ts.txt
		echo "  Salvando backup: $backup"
		$SUDO efibootmgr -v > "$backup" 2>/dev/null || true

		short=${chosen_id#BOOT}

		entry_line=$($SUDO efibootmgr -v | awk -v id="$chosen_id" '$0 ~ "^"id {found=1} found && NF {print; exit}')
		if [[ -z "$entry_line" ]]; then
			echo "  Não consegui localizar a entrada detalhada no efibootmgr -v." >&2
		else

			if [[ $entry_line =~ HD\(([0-9]+),GPT,([0-9A-Fa-f-]+) ]]; then
				partnum=${BASH_REMATCH[1]}
				partguid=${BASH_REMATCH[2]}
			else
				partnum=""
				partguid=""
			fi


			partdev=""
			if [[ -n "$partguid" ]]; then
				partdev=$(blkid -t PARTUUID="$partguid" -o device 2>/dev/null || true)
			fi
			if [[ -z "$partdev" ]]; then
				echo "  Não foi possível resolver dispositivo da partição (PARTUUID=$partguid). Aborto." >&2
			else
				pkname=$(lsblk -no PKNAME "$partdev" 2>/dev/null || true)
				if [[ -z "$pkname" ]]; then
					echo "  Não foi possível obter o disco pai para $partdev. Aborto." >&2
				else
					disk="/dev/$pkname"

					efi_path=$(echo "$entry_line" | awk '{ if(match($0,/\\EFI[^ ]*\.EFI/)){print substr($0,RSTART,RLENGTH)} }')
					if [[ -z "$efi_path" ]]; then
						echo "  Não encontrei o caminho do loader EFI na linha de entrada. Aborto." >&2
					else
						new_label="${label_by_id[$chosen_id]}-copy-$ts"
						echo "  Criando nova entrada em $disk part $partnum -> $efi_path"
						create_out=$($SUDO efibootmgr -c -d "$disk" -p "$partnum" -l "$efi_path" -L "$new_label" 2>&1 || true)
						echo "  Resultado: "
						echo "$create_out" | sed -n '1,120p'

						newboot=$(echo "$create_out" | awk '/Boot[0-9A-Fa-f]{4}/ {for(i=1;i<=NF;i++) if($i~/^Boot[0-9A-Fa-f]{4}$/){print $i; exit}}')
						if [[ -z "$newboot" ]]; then

							newboot=$($SUDO efibootmgr -v | awk 'BEGIN{ while((getline<"'$backup'")>0){b[$0]=1} } /^Boot[0-9A-Fa-f]{4}/ { if(!($0 in b)){ print $1; exit } }')
						fi
						if [[ -z "$newboot" ]]; then
							echo "  Não consegui detectar nova entrada criada. Abortando limpeza." >&2
						else
							echo "  Nova entrada: $newboot"
							newshort=${newboot#Boot}

							new_desired="$newshort"

							for part in $(echo "$bootorder" | tr -d ' ' | tr ',' ' '); do
								part_up=$(echo "$part" | tr '[:lower:]' '[:upper:]')
								if [[ "$part_up" == "$newshort" ]]; then
									continue
								fi
								new_desired+=","$part_up
							done
							echo "  Aplicando BootOrder: $new_desired"
							$SUDO efibootmgr -o "$new_desired" >/dev/null 2>&1 || true
							echo "  BootOrder definido (verifique com 'sudo efibootmgr -v')."
							read -rp "  Remover entrada antiga $chosen_id ? [y/N]: " rem
							rem=$(echo -n "$rem" | tr '[:upper:]' '[:lower:]')
							if [[ "$rem" == "y" || "$rem" == "yes" ]]; then
								oldshort=${chosen_id#BOOT}
								echo "  Removendo $chosen_id ..."
								$SUDO efibootmgr -b "$oldshort" -B >/dev/null 2>&1 || echo "  Falha ao remover $chosen_id" >&2
							fi
						fi
					fi
				fi
			fi
		fi
	fi
fi

echo "3) Verificando timeout..."
timeout_raw=$($SUDO efibootmgr | awk -F': ' '/Timeout/ {print $2}' || true)
timeout=${timeout_raw%% *}
desired_timeout=10
if [[ -z "$timeout" ]]; then
	echo "Timeout atual não encontrado; definindo para $desired_timeout s"
	$SUDO efibootmgr -t $desired_timeout || true
else
	if [[ $timeout -lt $desired_timeout ]]; then
		echo "Timeout atual: ${timeout}s -> atualizando para ${desired_timeout}s"
		$SUDO efibootmgr -t $desired_timeout || true
	else
		echo "Timeout atual: ${timeout}s (mantendo)"
	fi
fi

echo "4) Regenerando configuração do GRUB (quando aplicável)"
if command -v os-prober >/dev/null 2>&1; then
	echo "  Executando os-prober..."
	$SUDO os-prober >/dev/null 2>&1 || true
fi

if command -v grub2-mkconfig >/dev/null 2>&1; then
	if [[ -d /boot/grub2 ]]; then
		out=/boot/grub2/grub.cfg
	elif [[ -d /boot/efi/EFI/fedora ]]; then
		out=/boot/efi/EFI/fedora/grub.cfg
	else
		out=/boot/grub2/grub.cfg
	fi
	echo "  Executando: grub2-mkconfig -o $out"
	if $SUDO grub2-mkconfig -o "$out" >/dev/null 2>&1; then
		echo "  grub.cfg gerado: $out"
	else
		echo "  Falha ao gerar $out" >&2
	fi
elif command -v grub-mkconfig >/dev/null 2>&1; then
	out=/boot/grub/grub.cfg
	echo "  Executando: grub-mkconfig -o $out"
	if $SUDO grub-mkconfig -o "$out" >/dev/null 2>&1; then
		echo "  grub.cfg gerado: $out"
	else
		echo "  Falha ao gerar $out" >&2
	fi
else
	echo "  Nenhuma ferramenta de geração do GRUB encontrada (grub2-mkconfig/grub-mkconfig). Pulei esta etapa." >&2
fi

echo "5) Estado final do boot (resumo):"

bootcurrent=$($SUDO efibootmgr | awk -F': ' '/BootCurrent/ {print $2}' || echo "")
bootorder_final=$($SUDO efibootmgr | awk -F': ' '/BootOrder/ {gsub(/ /,"",$2); print $2}' || echo "")
timeout_raw=$($SUDO efibootmgr | awk -F': ' '/Timeout/ {print $2}' || echo "")
if [[ -n "$timeout_raw" ]]; then
	timeout_disp=${timeout_raw}
else
	timeout_disp="?"
fi

total_entries=$($SUDO efibootmgr -v | grep -c -E '^Boot[0-9A-Fa-f]{4}')
shown=${#boot_ids[@]}
skipped=$(( total_entries - shown ))

printf "  BootCurrent: %s\n" "${bootcurrent:-?}"
printf "  Timeout: %s\n" "$timeout_disp"
printf "  BootOrder: %s\n" "${bootorder_final:-$bootorder}"
printf "  Entradas exibidas: %d\n" "$shown"
for id in "${boot_ids[@]}"; do
	printf "    %s -> %s\n" "$id" "${label_by_id[$id]}"
done
if (( skipped > 0 )); then
	printf "  Entradas ignoradas: %d (ex.: PXE, dispositivos USB longos, duplicatas)\n" "$skipped"
fi

echo "=== Correção concluída ==="
echo "Reinicie o computador para testar. Se o problema persistir, verifique o Fast Boot do Windows e a ordem de partições na BIOS/UEFI."


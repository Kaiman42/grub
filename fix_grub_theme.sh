#!/bin/bash
set -euo pipefail
TS=$(date +%s)
if [ "$EUID" -ne 0 ]; then
  echo "This script requires root. Re-run with sudo." >&2
  exit 2
fi

cp -a /etc/default/grub /etc/default/grub.bak.${TS}

if grep -q '^GRUB_TERMINAL_OUTPUT=' /etc/default/grub; then
  sed -i 's/^GRUB_TERMINAL_OUTPUT=.*/GRUB_TERMINAL_OUTPUT="gfxterm"/' /etc/default/grub
else
  echo 'GRUB_TERMINAL_OUTPUT="gfxterm"' >> /etc/default/grub
fi

if ! grep -q '^GRUB_GFXMODE=' /etc/default/grub; then
  echo 'GRUB_GFXMODE="auto"' >> /etc/default/grub
fi

if ! grep -q '^GRUB_THEME=' /etc/default/grub; then
  echo "Warning: no GRUB_THEME set in /etc/default/grub" >&2
  echo "You can set e.g. GRUB_THEME=\"/boot/grub/themes/YourTheme/theme.txt\"" >&2
fi

if [ -f /etc/grub.d/06_load_theme ]; then
  cp -a /etc/grub.d/06_load_theme /etc/grub.d/06_load_theme.bak.${TS}
fi
cat > /etc/grub.d/06_load_theme <<'EOF'
#!/bin/sh
set -e
cat << 'LOADTHEME'
### BEGIN /etc/grub.d/06_load_theme ###
# Inject load_theme when a theme is defined
if [ -n "${theme}" ] ; then
  if [ -f "${theme}" ] ; then
    load_theme "${theme}"
  fi
fi
### END /etc/grub.d/06_load_theme ###
LOADTHEME
EOF
chmod 755 /etc/grub.d/06_load_theme

echo "Regenerating /boot/grub2/grub.cfg..."
if grub2-mkconfig -o /boot/grub2/grub.cfg; then
  echo "Regenerated /boot/grub2/grub.cfg successfully."
else
  echo "grub2-mkconfig failed; check output above." >&2
  exit 3
fi
echo "Done. Reboot to verify theme."

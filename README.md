
# GRUB Fix

Uma coleção pequena de scripts para diagnosticar e reparar problemas comuns do GRUB em sistemas Linux.

Principais itens:

- `fix_grub.sh` — recupera e regenera a configuração do GRUB (ex.: executar update-grub, reinstalar entradas quando necessário).
- `fix_grub_theme.sh` — corrige/repõe o tema do GRUB (arquivos de tema, permissões e caminhos esperados pelo bootloader).

## Como usar

1. Abra um terminal na pasta deste repositório.
2. Torne os scripts executáveis (uma vez):

```bash
chmod +x fix_grub.sh fix_grub_theme.sh
```

3. Execute o script apropriado como root (use sudo):

```bash
sudo ./fix_grub.sh
# ou
sudo ./fix_grub_theme.sh
```

Observação: leia o conteúdo dos scripts antes de rodar para entender as ações realizadas. Faça backup de arquivos de configuração importantes (por exemplo, `/etc/default/grub` e `/boot/grub`) quando estiver em dúvida.

## Exemplo rápido

Se o GRUB não mostra entradas ou o tema está quebrado, siga esta ordem:

1. `sudo ./fix_grub.sh` — regenera a configuração e tenta detectar sistemas operacionais.
2. `sudo ./fix_grub_theme.sh` — restaura o tema e ajusta permissões/caminhos.

## Troubleshooting

- Se o sistema não inicializar após alterações, inicialize com outra versão do kernel e recupere arquivos a partir dos backups.
- Verifique logs de instalação do GRUB e mensagens no console para pistas (dmesg, journalctl).

## Contribuição

Pequenas melhorias e correções de bugs são bem-vindas. Abra uma issue ou um pull request com mudanças e uma breve descrição do problema/solução.

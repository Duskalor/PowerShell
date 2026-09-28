# Auditoría del setup — 2026-09-28

Estado del repo y decisiones pendientes, para retomar sin volver a investigar.

> Nota: escrito en español porque son notas de trabajo. El resto del repo está
> en inglés; si se queda como documento permanente, conviene traducirlo.

---

## Lo que ya se hizo

### Pull de 18 commits

`main` pasó de `fae8bf4` a `4aa7641`. El repo dejó de ser un perfil de PowerShell
y se convirtió en un gestor de dotfiles: `manifest.psd1` + `bootstrap.ps1` +
`sync.ps1` + `install.ps1`, con todos los configs bajo `config/` y `home/`.

En ese pull, `claude/statusline-command.sh` se borró y su reemplazo quedó en
`config/claude/statusline-command.sh`.

### Statusline portado a Node — commit `f061933`

Rama `fix/statusline-node-extraction`, −194/+155 sobre dos archivos.

**El problema:** la versión en Python estaba muerta en esta máquina.
`command -v python3` resuelve al *stub* de alias de Microsoft Store en
`WindowsApps`, así que la detección tenía éxito, los diez subprocesos de
extracción imprimían "Python was not found", y el statusline se renderizaba con
el cwd vacío y `ctx --`.

**Lo que se cambió:** Python se usaba en dos sitios, los dos ahora en Node.

| | Antes | Ahora |
|---|---|---|
| Extracción de campos | 10 × `python -c` | 1 × `node -e`, parsea el JSON una vez y emite una línea por campo, leído con `mapfile` |
| Line-wrap adaptativo | `python -c` | `node -e`, mismo algoritmo greedy midiendo ancho visible con los ANSI quitados |

No se tocó el render: markers de git sucio (`✚`/`●`), barras de rate-limit,
orden de segmentos y el fallback de una línea cuando no hay intérprete siguen
igual. De paso desaparece la ruta hardcodeada a `python.exe` que llevaba el
nombre de usuario de otra máquina, así que la tabla de rutas hardcodeadas del
README bajó a una sola entrada.

**Verificado con:** `COLUMNS=200`, `COLUMNS=60`, sin `COLUMNS`, entrada `{}` y
entrada que no es JSON. Salida real:

```
...\CODE\PowerShell |  main ●2 | Opus 5 | ctx 42% | 5h ██░░░░ 30% (3h14m) | 7d █░░░░░ 12% | "test" | $1.230
```

Pendiente: la rama **no está mergeada ni pusheada**.

---

## Hallazgo principal: nada está enlazado en esta máquina

`bootstrap.ps1 -DryRun` reporta **`already ok 0`**. Ni un symlink puesto.
El motivo es la ubicación del clon:

| | Ruta |
|---|---|
| Este clon | `Documents\CODE\PowerShell` |
| Donde PowerShell busca el perfil | `Documents\PowerShell` |

`install.ps1` clona a propósito en `[Environment]::GetFolderPath('MyDocuments')\PowerShell`
para que **la raíz del repo *sea* el directorio del perfil**. Eso es lo que hace
que `Microsoft.PowerShell_profile.ps1` se cargue y que `Modules/Terminal-Icons`
se auto-importe: ninguno de los dos está en el manifest, funcionan por
ubicación.

Como el clon está en otro sitio, en `Documents\PowerShell` hay un stub ajeno de
156 bytes (solo zoxide) con sus propios `Modules/` y `Scripts/`, y el perfil real
del repo — 14,5 KB, con todos los alias y `cmds` — **nunca se carga**.

Esto explica dos síntomas que ya se vieron:

- `git commit` falló con *"Author identity unknown"* aunque `home/.gitconfig`
  declara la identidad: el symlink a `~/.gitconfig` no existía.
- `~/.claude/statusline-command.sh` era una copia suelta y desactualizada, no un
  enlace al repo.

**Regla práctica:** antes de asumir que un config bajo `config/` está activo,
comprobar si su destino es realmente un symlink.

---

## Huecos verificados en el instalador

1. **Claude Code no lo instala nada.** `Anthropic.Claude` en
   `packages/winget-core.json` es la **app de escritorio** — `winget show` lo
   confirma: *"Your AI partner on desktop"*. El CLI vive en
   `~/.local/bin/claude.exe`, instalador nativo, y no está en ninguna lista. En
   una máquina nueva quedaría todo `~/.claude` enlazado (CLAUDE.md, 20+ skills,
   agents, commands, statusline) y sin el CLI que lo lee.
2. **`opencode` y `gga` tampoco.** Sus configs sí se enlazan — `opencode.json`
   es uno de los tres templates renderizados — pero nadie instala los binarios.
   `opencode` llegó por npm; `gga` no está en esta máquina.
3. **Dos filas muertas en el manifest:** `config/opencode/agents` y
   `config/opencode/profiles` no existen. `bootstrap.ps1` las salta limpiamente
   con "not in the repository, nothing to link", así que es solo ruido.
4. **Logins y secretos son manuales, y así debe ser.** `settings.local.json` se
   siembra desde su `.example` para llenarlo a mano; aparte quedan el login de
   `claude`, `gh auth login` y el store de datos de engram. La identidad de git
   sí está cubierta por `home/.gitconfig`.

Lo que **sí** cubre `install.ps1`, para constancia: comprueba winget y el
permiso de symlinks, instala git y PowerShell 7, clona, importa 16 paquetes,
instala IosevkaTerm Nerd Font por usuario (sin elevación), pone engram en
`~/bin` y lo añade al PATH, y llama a `bootstrap.ps1` — 23 symlinks, 3
renderizados, 1 archivo sembrado. Es idempotente y respalda a
`.backup/<timestamp>`.

---

## Decisiones pendientes

### 1. Cómo enlazar esta máquina

- **Mover el clon** a `Documents\PowerShell` (apartando el stub actual) y correr
  `bootstrap.ps1`. Queda igual que una máquina nueva, perfil incluido.
- **Solo `bootstrap.ps1`** desde donde está: enlaza los 23 configs, pero el
  perfil seguirá sin cargarse porque eso depende de la ubicación.

### 2. Mergear y pushear `fix/statusline-node-extraction`

```powershell
git checkout main
git merge --ff-only fix/statusline-node-extraction
```

### 3. Mejoras opcionales al instalador

- Añadir Claude Code, `opencode` y `gga` a `install.ps1`.
- Borrar las dos filas muertas de `manifest.psd1`.
- `config/claude/settings.json:112` todavía contiene una ruta absoluta con el
  nombre de usuario de otra máquina, dentro de la descripción del entorno
  auto-mode. Es texto descriptivo, no una ruta funcional, y el chequeo del
  README (`rg -F "C:\Users" config home`) sí la detecta.

---

## Comandos para retomar

```powershell
.\bootstrap.ps1 -DryRun   # qué se enlazaría, sin escribir nada
.\sync.ps1 -Check         # deriva entre máquina y repo
git log --oneline -5
git status -sb
```

Y para comprobar si un config está realmente enlazado:

```powershell
Get-Item $HOME\.claude\settings.json -Force | Select-Object LinkType, Target
```

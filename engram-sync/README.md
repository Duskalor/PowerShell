# Engram Autosync (Windows)

Mantiene las memorias de Engram sincronizadas automáticamente entre máquinas,
subiendo y bajando cada **30 minutos** contra el repo privado
[`Duskalor/engram-sync`](https://github.com/Duskalor/engram-sync).

## Cómo funciona

```
Windows          GitHub          Mac
 engram DB ──export──→ JSON ──push/pull──→ JSON ──import──→ engram DB
```

**A prueba de conflictos:** la DB local es la fuente de verdad; el JSON se
regenera en cada corrida. Por eso `autosync.ps1` hace `git reset --hard`
antes de re-exportar → un merge conflict de git es imposible.

## Requisitos (una sola vez)

1. **Engram instalado**
   ```powershell
   go install github.com/Gentleman-Programming/engram/cmd/engram@latest
   ```

2. **Repo de sync clonado en `~/.engram`**
   ```powershell
   git clone https://github.com/Duskalor/engram-sync.git "$HOME\.engram"
   ```
   > Si ya tenés una DB local en `~/.engram`, respaldala antes:
   > ```powershell
   > Move-Item "$HOME\.engram\engram.db" "$HOME\engram.db.bak"
   > git clone https://github.com/Duskalor/engram-sync.git "$HOME\.engram"
   > Move-Item "$HOME\engram.db.bak" "$HOME\.engram\engram.db"
   > ```

## Instalar el autosync

```powershell
.\engram-sync\setup.ps1
```

Eso registra la tarea programada `engram-autosync` que corre cada 30 min.

### Verificar
```powershell
Get-ScheduledTask -TaskName engram-autosync    # que exista
Start-ScheduledTask -TaskName engram-autosync  # correrla ya, sin esperar
```

### Desinstalar
```powershell
Unregister-ScheduledTask -TaskName engram-autosync -Confirm:$false
```

## Uso manual (opcional)

Agregá estas funciones a tu `$PROFILE` si querés sincronizar a mano:

```powershell
function engram-push {
    $d = "$HOME\.engram"
    engram export "$d\engram-export.json"
    git -C $d add engram-export.json
    git -C $d commit -m "sync $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
    git -C $d push
}

function engram-pull {
    $d = "$HOME\.engram"
    git -C $d pull
    engram import "$d\engram-export.json"
}
```

## Archivos

| Archivo | Qué hace |
|---------|----------|
| `autosync.ps1` | El script que corre la tarea: pull+import y export+push |
| `setup.ps1` | Registra la tarea programada (idempotente) |

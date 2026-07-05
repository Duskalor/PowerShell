# Paquetes instalados

Guardar la lista de paquetes hace que tu Windows sea **reconstruible de verdad**:
no solo recuperás el perfil de PowerShell, sino TODAS tus apps de una.

## Cómo exportar (correr en Windows)

### Scoop
```powershell
scoop export > packages/scoop.json
```

### Winget
```powershell
winget export -o packages/winget.json
```

Después commiteás los archivos generados:
```powershell
git add packages/
git commit -m "chore: update package lists"
git push
```

## Cómo restaurar en una máquina nueva

### Scoop
```powershell
scoop import packages/scoop.json
```

### Winget
```powershell
winget import -i packages/winget.json
```

> Tip: corré el export cada vez que instales algo importante, así el repo
> refleja siempre el estado real de tu máquina.

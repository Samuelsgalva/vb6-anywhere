#Requires -Version 5.0
<#
    Repara el IDE cuando abre pero se cierra al cargar un proyecto.

    Pasa en PCs que YA tuvieron VB6 (instalado o una copia portable anterior):
    el IDE hereda estado del usuario y una cache de componentes que apunta a
    rutas que ya no existen. En una PC limpia no ocurre.

    Que hace, en este orden, con copia de seguridad de todo:
      1. Exporta y borra HKCU\Software\Microsoft\Visual Basic\6.0
         (posicion de ventanas, cuadro de herramientas, ultimos proyectos:
         el IDE lo reconstruye solo al arrancar).
      2. Borra las entradas de cache de componentes de HKLM cuya .oca ya no
         existe o que apuntan a otra copia portable de VB6.
      3. Vuelve a comprobar que el resto del paquete esta bien.
#>
$ErrorActionPreference = 'Continue'
$Raiz = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$Ide  = Join-Path $Raiz '01_IDE\VB98'
$ts   = Get-Date -Format 'yyyyMMdd-HHmmss'
$temp = $env:TEMP

function E([string]$t, [string]$c = 'Gray') { Write-Host $t -ForegroundColor $c }

E ''
E '  Reparar el IDE de VB6 (se cierra al abrir un proyecto)' Cyan
E ('  Paquete: ' + $Raiz)
E ''

$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) {
    E '  Esto necesita administrador. Ejecuta "6-Reparar IDE.bat" y acepta el UAC.' Yellow
    Read-Host '  Enter para salir'
    exit 1
}

# ---------------------------------------------------------------- 1. HKCU
E '  [1/3] Estado del IDE guardado en tu usuario'
$hkcuReg = Join-Path $temp ("vb6-estado-usuario-$ts.reg")
if (Test-Path 'HKCU:\Software\Microsoft\Visual Basic\6.0') {
    & reg export 'HKCU\Software\Microsoft\Visual Basic\6.0' $hkcuReg /y 2>&1 | Out-Null
    if (Test-Path $hkcuReg) { E ('        copia: ' + $hkcuReg) DarkGray }
    Remove-Item 'HKCU:\Software\Microsoft\Visual Basic\6.0' -Recurse -Force -ErrorAction SilentlyContinue
    if (Test-Path 'HKCU:\Software\Microsoft\Visual Basic\6.0') { E '        AVISO: no se pudo borrar del todo' Yellow }
    else { E '        borrado (el IDE lo recrea al arrancar)' Green }
}
else { E '        no existia: nada que limpiar' DarkGray }

# ---------------------------------------------------------------- 2. cache HKLM
E ''
E '  [2/3] Cache de componentes (entradas que apuntan a rutas muertas)'
$k = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Visual Basic\6.0'
$cacheReg = Join-Path $temp ("vb6-cache-componentes-$ts.reg")
if (Test-Path $k) {
    & reg export 'HKLM\SOFTWARE\WOW6432Node\Microsoft\Visual Basic\6.0' $cacheReg /y 2>&1 | Out-Null
    if (Test-Path $cacheReg) { E ('        copia: ' + $cacheReg) DarkGray }
    $ideNorm = $Ide.TrimEnd('\').ToLower()
    $borradas = 0; $dejadas = 0
    foreach ($s in (Get-ChildItem $k -ErrorAction SilentlyContinue)) {
        $props = (Get-ItemProperty $s.PSPath -ErrorAction SilentlyContinue).PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' }
        $ruta = $null
        foreach ($pr in $props) { if ($pr.Value -is [string] -and $pr.Value -match '(?i)\.oca$') { $ruta = $pr.Value } }
        if (-not $ruta) { continue }
        $dir = (Split-Path $ruta -Parent)
        $esSistema = ($dir -match '(?i)^[a-z]:\\windows(\\system32|\\syswow64)?$')
        $esNuestro = ($dir.TrimEnd('\').ToLower() -eq $ideNorm)
        $existeOca = (Test-Path -LiteralPath $ruta)
        $otraCopia = ($dir -match '(?i)VB6-Portable|VB6-Anywhere|01_IDE\\VB98')
        if ((-not $existeOca) -or ($otraCopia -and -not $esNuestro)) {
            Remove-Item $s.PSPath -Recurse -Force -ErrorAction SilentlyContinue
            $borradas++
        }
        else { $dejadas++ }
    }
    E ('        borradas: {0}   conservadas: {1}' -f $borradas, $dejadas) Green
}
else { E '        la clave no existe: ejecuta antes 1-Instalar.bat' Yellow }

# ---------------------------------------------------------------- 3. verificar
E ''
E '  [3/3] Comprobacion del paquete'
$inst = Join-Path $Raiz 'Instalar.ps1'
if (Test-Path $inst) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $inst -SoloVerificar -NoPause 2>&1 |
        Where-Object { $_ -match 'OK|FALLA|->' } | ForEach-Object { E ('        ' + $_) }
}

E ''
E '  Listo. Abre ahora el IDE con 4-Abrir VB6.bat y prueba el proyecto.' Green
E ''
Read-Host '  Enter para cerrar'

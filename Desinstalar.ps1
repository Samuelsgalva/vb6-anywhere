#Requires -Version 5.0
<#
    Desinstalador del VB6 Anywhere.

    Quita lo que agrego Instalar.ps1:
      - marca de edicion de VB6
      - claves del IDE (VisualStudio 6.0)
      - entradas de cache de componentes
      - registro de los controles ActiveX del paquete
      - acceso directo del escritorio

    NO borra archivos del paquete ni las licencias de HKCR\Licenses
    (son inofensivas y puede que las use otro software).
#>
[CmdletBinding()]
param(
    [switch]$NoPause
)

$ErrorActionPreference = 'Stop'
$Raiz = Split-Path -Parent $PSCommandPath

$identidad = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identidad)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host '  Se necesitan permisos de administrador (UAC)...' -ForegroundColor Yellow
    Start-Process powershell.exe -Verb RunAs -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -File "' + $PSCommandPath + '"')
    return
}

function Escribir($t, $c = 'Gray') { Write-Host $t -ForegroundColor $c }
$base = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft'

Escribir ''
Escribir '  Desinstalando VB6 Anywhere...' Cyan

# 1. Controles
$regsvr = Join-Path $env:WINDIR 'SysWOW64\regsvr32.exe'
$controles = Join-Path $Raiz '02_Componentes\Controles'
if (Test-Path $controles) {
    foreach ($o in (Get-ChildItem $controles -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -match '(?i)^\.ocx$' })) {
        Start-Process -FilePath $regsvr -ArgumentList @('/s', '/u', "`"$($o.FullName)`"") -Wait -WindowStyle Hidden
        Escribir ("    desregistrado: " + $o.Name) DarkGray
    }
}

# 2. Cache de componentes
$rutaCache = "$base\Visual Basic\6.0"
$claves = @(
    '{43093C9E-3720-11D9-A457-00115B44C4A0}#38.4', '{43093C9E-3720-11D9-A457-00115B44C4A0}#38.0',
    '{831FDD16-0C5C-11D2-A9FC-0000F8754DA1}#2.0', '{831FDD16-0C5C-11D2-A9FC-0000F8754DA1}#2.1', '{831FDD16-0C5C-11D2-A9FC-0000F8754DA1}#2.2',
    '{86CF1D34-0C5F-11D2-A9FC-0000F8754DA1}#2.0', '{0BA686C6-F7D3-101A-993E-0000C0EF6F5E}#1.0',
    '{B02F3647-766B-11CE-AF28-C3A2FBE76A13}#2.5', '{FDAC2480-F4ED-4632-AA78-DCA210A74E49}#6.0'
)
foreach ($k in $claves) {
    $ruta = "$rutaCache\$k"
    if (Test-Path $ruta) { Remove-Item $ruta -Recurse -Force -ErrorAction SilentlyContinue }
}
Escribir '    cache de componentes limpiada' DarkGray

# 2b. Runtime VBA compartido que copia Instalar.ps1 a Common Files
$comunes = @()
if ([Environment]::Is64BitOperatingSystem) {
    $comunes += (Join-Path $env:SystemDrive 'Program Files (x86)\Common Files')
}
$comunes += $env:CommonProgramFiles
foreach ($comun in ($comunes | Select-Object -Unique)) {
    $vba = Join-Path $comun 'Microsoft Shared\VBA'
    if (Test-Path $vba) {
        Remove-Item $vba -Recurse -Force -ErrorAction SilentlyContinue
        Escribir ("    runtime VBA retirado de " + $comun) DarkGray
    }
}

# 2c. Registro de MSO97RT en Shared Tools (solo si apunta a la copia del paquete)
$msoKey  = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Shared Tools\mso97rt'
$msoPath = (Get-ItemProperty -Path $msoKey -Name Path -ErrorAction SilentlyContinue).Path
if ($msoPath -and ($msoPath -match 'Common Files')) {
    Remove-Item -Path $msoKey -Recurse -Force -ErrorAction SilentlyContinue
    Escribir '    registro MSO97RT (Shared Tools) retirado' DarkGray
}


# 3. Claves del IDE
foreach ($r in @("$base\VisualStudio\6.0", "$base\Visual Studio\6.0")) {
    if (Test-Path $r) { Remove-Item $r -Recurse -Force -ErrorAction SilentlyContinue }
}
Remove-ItemProperty -Path "$base\IE4\DependentComponents" -Name 'VB98' -ErrorAction SilentlyContinue
Escribir '    claves del IDE eliminadas' DarkGray

# 4. Acceso directo
$lnk = Join-Path ([Environment]::GetFolderPath('Desktop')) 'VB6 (sandbox).lnk'
if (Test-Path $lnk) { Remove-Item $lnk -Force; Escribir '    acceso directo eliminado' DarkGray }

Escribir ''
Escribir '  Listo. El paquete se puede borrar sin dejar rastro (las licencias se dejan).' Green
Escribir ''
if (-not $NoPause) { Read-Host '  Enter para cerrar' }

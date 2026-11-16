#Requires -Version 5.0
<#
    Abre el IDE de VB6 (el instalado si existe; si no, la copia portable).
    Pide UAC porque el IDE escribe en HKLM.
#>
$ErrorActionPreference = 'Stop'
$Raiz = Split-Path -Parent (Split-Path -Parent $PSCommandPath)

function Buscar-Vb6Instalado {
    $candidatos = @()
    $r = Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\6.0' -ErrorAction SilentlyContinue
    if ($r -and $r.InstallDir) { $candidatos += (Join-Path $r.InstallDir 'VB6.EXE') }
    $r2 = Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Visual Basic\6.0' -ErrorAction SilentlyContinue
    if ($r2 -and $r2.Path) { $candidatos += (Join-Path $r2.Path 'VB6.EXE') }
    if (${env:ProgramFiles(x86)}) { $candidatos += (Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\VB98\VB6.EXE') }
    foreach ($c in $candidatos) {
        if ($c -and (Test-Path $c) -and ($c -notmatch [regex]::Escape($Raiz))) { return $c }
    }
    return $null
}

$instalado = Buscar-Vb6Instalado
if ($instalado) {
    $exe = $instalado
    Write-Host ("  VB6 instalado: {0}" -f $exe) -ForegroundColor Green
}
else {
    $exe = Join-Path $Raiz '01_IDE\VB98\VB6.EXE'
    Write-Host ''
    Write-Host '  VB6 no esta instalado en esta PC: se abrira la copia portable.' -ForegroundColor Cyan
}

if (-not (Test-Path $exe)) { Write-Host ("  No existe: " + $exe) -ForegroundColor Red; exit 1 }

# El IDE necesita el runtime VBA en Common Files (lo copia 1-Instalar.bat).
# Sin el, VB6 abre y se cierra con "Error inesperado".
$vbaOk = $false
foreach ($comun in @((Join-Path $env:SystemDrive 'Program Files (x86)\Common Files'), $env:CommonProgramFiles)) {
    if ($comun -and (Test-Path (Join-Path $comun 'Microsoft Shared\VBA\VBA6\3082\VBE6INTL.DLL'))) { $vbaOk = $true; break }
}
if (-not $vbaOk) {
    Write-Host ''
    Write-Host '  Falta el runtime VBA compartido (Common Files\Microsoft Shared\VBA).' -ForegroundColor Yellow
    Write-Host '  El IDE se cerraria con "Error inesperado". Ejecuta antes:' -ForegroundColor Yellow
    Write-Host ('    ' + (Join-Path $Raiz '1-Instalar.bat')) -ForegroundColor Yellow
    Write-Host ''
    Read-Host '  Enter para cerrar'
    exit 1
}

# UAC: el IDE escribe en HKLM (cache de componentes, marca de edicion).
$p = Start-Process -FilePath $exe -WorkingDirectory (Split-Path $exe -Parent) -Verb RunAs -PassThru -ErrorAction SilentlyContinue
if (-not $p) { exit 1 }

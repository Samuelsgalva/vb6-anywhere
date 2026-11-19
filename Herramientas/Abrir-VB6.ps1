#Requires -Version 5.0
param(
    [string]$Proyecto
)
<#
    Abre el IDE de VB6 (el instalado si existe; si no, la copia portable).

    Pide UAC siempre: el IDE escribe en HKLM (cache de componentes, licencias) y
    sin privilegios aparece "Error al intentar tener acceso al registro del
    sistema" la primera vez que un proyecto usa un control que aun no esta
    cacheado.

    -Proyecto <ruta.vbp>  abre ese proyecto. Es lo que usa la asociacion de
    archivos .vbp, asi que el doble clic se comporta igual que 4-Abrir VB6.bat.
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
        if (-not $c -or -not (Test-Path $c)) { continue }
        # Ni la copia de este paquete ni la de OTRO paquete portable cuentan como
        # "instalado": las dos viven en <raiz>\01_IDE\VB98 y tienen su propio registro.
        if ($c -match '\\01_IDE\\VB98\\') { continue }
        return $c
    }
    return $null
}

# Proyecto a abrir (si viene de la asociacion de archivos)
$rutaProyecto = $null
$carpetaTrabajo = $null
if ($Proyecto) {
    if (Test-Path -LiteralPath $Proyecto) {
        $rutaProyecto = (Get-Item -LiteralPath $Proyecto).FullName
        $carpetaTrabajo = Split-Path $rutaProyecto -Parent
    }
    else {
        # Sin ventana (asociacion): no hay a quien avisar, se sale en silencio
        exit 1
    }
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
    if ($rutaProyecto) {
        # Lanzado desde el doble clic: sin consola no se puede preguntar nada
        exit 1
    }
    Write-Host ''
    Write-Host '  Falta el runtime VBA compartido (Common Files\Microsoft Shared\VBA).' -ForegroundColor Yellow
    Write-Host '  El IDE se cerraria con "Error inesperado". Ejecuta antes:' -ForegroundColor Yellow
    Write-Host ('    ' + (Join-Path $Raiz '1-Instalar.bat')) -ForegroundColor Yellow
    Write-Host ''
    Read-Host '  Enter para cerrar'
    exit 1
}

# UAC siempre: es lo que evita el "Error al intentar tener acceso al registro".
if ($rutaProyecto) {
    $p = Start-Process -FilePath $exe -ArgumentList ('"' + $rutaProyecto + '"') -WorkingDirectory $carpetaTrabajo -Verb RunAs -PassThru -ErrorAction SilentlyContinue
}
else {
    $p = Start-Process -FilePath $exe -WorkingDirectory (Split-Path $exe -Parent) -Verb RunAs -PassThru -ErrorAction SilentlyContinue
}
# Si se cancela el UAC, Start-Process no devuelve proceso: se sale sin ruido.
if (-not $p) { exit 1 }

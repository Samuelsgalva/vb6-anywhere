#Requires -Version 5.0
<#
    Compila un proyecto VB6 (.vbp) con el sandbox portable.

    - Trabaja sobre una COPIA del proyecto, nunca sobre el original.
    - Ajusta Path32 a una carpeta local (los .vbp suelen apuntar a un share).
    - Deja el .exe en la carpeta que indiques.

    Uso:
        powershell -ExecutionPolicy Bypass -File Compilar.ps1 -Vbp "C:\MisProyectos\App\App.vbp"
        powershell -ExecutionPolicy Bypass -File Compilar.ps1 -Vbp "..." -Salida "C:\Salida"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Vbp,
    [string]$Salida,
    [int]$TimeoutSegundos = 300,
    [switch]$Elevado
)

$ErrorActionPreference = 'Stop'
$Raiz = Split-Path -Parent (Split-Path -Parent $PSCommandPath)

# Version portable: compila SIEMPRE con la copia del paquete. Si se usara un
# VB6 "instalado" que aparezca en el registro, compilaria con otra carpeta.
$Ide = Join-Path $Raiz '01_IDE\VB98'
$Vb6 = Join-Path $Ide 'VB6.EXE'
Write-Host ("  IDE: {0}" -f $Ide) -ForegroundColor DarkGray

# Autoelevacion (VB6 escribe en HKLM al compilar)
$identidad = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identidad)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $arg = '-NoProfile -ExecutionPolicy Bypass -File "' + $PSCommandPath + '" -Vbp "' + $Vbp + '" -Elevado'
    if ($Salida) { $arg += ' -Salida "' + $Salida + '"' }
    Write-Host '  Pidiendo permisos (UAC)...' -ForegroundColor Yellow
    Start-Process powershell.exe -Verb RunAs -ArgumentList $arg
    return
}

if (-not (Test-Path $Vbp))     { throw "No existe el proyecto: $Vbp" }
if (-not (Test-Path $Vb6))     { throw "No existe el IDE: $Vb6" }

$proyecto = Get-Item $Vbp
$nombre   = [System.IO.Path]::GetFileNameWithoutExtension($proyecto.Name)
$carpeta  = $proyecto.Directory.FullName
if (-not $Salida) { $Salida = Join-Path $carpeta 'Salida' }
if (-not (Test-Path $Salida)) { New-Item -ItemType Directory -Path $Salida -Force | Out-Null }
$Salida = (Resolve-Path $Salida).Path

$build = Join-Path $env:TEMP ('vb6build_' + $nombre)
if (Test-Path $build) { Remove-Item $build -Recurse -Force }
New-Item -ItemType Directory -Path $build -Force | Out-Null
robocopy $carpeta $build /E /XF *.exe *.EXE *.log *.LOG *.vbw *.VBW /NFL /NDL /NJH /NJS /NP | Out-Null

$vbpBuild = Join-Path $build $proyecto.Name
if (-not (Test-Path $vbpBuild)) { throw "No se copio el .vbp a $build" }

$enc = [System.Text.Encoding]::GetEncoding(1252)
$texto = [System.IO.File]::ReadAllText($vbpBuild, $enc)
if ($texto -match 'Path32=') {
    $texto = [regex]::Replace($texto, 'Path32="[^"]*"', ('Path32="' + $build + '"'))
}
else {
    $texto = [regex]::Replace($texto, '(?m)^(ExeName32=.*)$', ('$1' + "`r`n" + 'Path32="' + $build + '"'))
}
[System.IO.File]::WriteAllText($vbpBuild, $texto, $enc)

$log = Join-Path $build ('compile_' + $nombre + '.log')
Write-Host ''
Write-Host ("  Compilando {0} ..." -f $nombre) -ForegroundColor Cyan
$proc = Start-Process -FilePath $Vb6 -ArgumentList @('/make', "`"$vbpBuild`"", '/out', "`"$log`"") -WorkingDirectory $build -PassThru -WindowStyle Hidden
if (-not $proc.WaitForExit($TimeoutSegundos * 1000)) {
    try { $proc.Kill() } catch { }
    throw "VB6 no termino en $TimeoutSegundos segundos (posible dialogo)."
}

$textoLog = ''
if (Test-Path $log) { $textoLog = [System.IO.File]::ReadAllText($log, $enc) }
Write-Host $textoLog.Trim()

$exe = Get-ChildItem $build -Filter '*.exe' -File -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $exe) {
    Write-Host ''
    Write-Host '  FALLO: no se genero el EXE.' -ForegroundColor Red
    exit 2
}

$destino = Join-Path $Salida $exe.Name
Copy-Item $exe.FullName $destino -Force
Write-Host ''
Write-Host ("  OK: {0} ({1:N0} bytes)" -f $destino, (Get-Item $destino).Length) -ForegroundColor Green
exit 0

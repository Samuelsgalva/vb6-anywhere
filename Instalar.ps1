#Requires -Version 5.0
<#
    Instalador del VB6 Anywhere.

    - Se autoeleva (UAC) si no se ejecuta como administrador.
    - No copia nada al sistema: registra los componentes desde esta carpeta
      y escribe las claves de registro necesarias apuntando a rutas relativas
      a la ubicacion del paquete (se puede mover de D:\ a C:\ sin reinstalar
      solo hay que volver a ejecutar Instalar.ps1).
    - No contiene ni necesita los proyectos.

    Uso:  Click derecho -> Ejecutar con PowerShell   (o)
          powershell -NoProfile -ExecutionPolicy Bypass -File Instalar.ps1
#>
[CmdletBinding()]
param(
    [switch]$SinAccesos,
    [switch]$SoloVerificar,
    [switch]$NoPause
)

$ErrorActionPreference = 'Stop'

$Raiz     = Split-Path -Parent $PSCommandPath
$IdePortable = Join-Path $Raiz '01_IDE\VB98'
$Controles= Join-Path $Raiz '02_Componentes\Controles'
$Licencias= Join-Path $Raiz '02_Componentes\Licencias'
$Herram   = Join-Path $Raiz 'Herramientas'


# Version portable: SIEMPRE usa su propia copia del IDE. Si se usara un VB6
# "instalado" que aparezca en el registro, el paquete acabaria configurando otra
# carpeta (o la de otra persona) en vez de la suya.
$Ide     = $IdePortable
$ModoIde = 'portable'
$Vb6 = Join-Path $Ide 'VB6.EXE'
$InstaladorVb6 = Join-Path $Raiz '03_Instaladores\VB6'

function Escribir($texto, $color = 'Gray') { Write-Host $texto -ForegroundColor $color }

# ---------------------------------------------------------------------------
#  0. Autoelevacion
# ---------------------------------------------------------------------------
$identidad = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identidad)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) -and -not $SoloVerificar) {
    Escribir ''
    Escribir '  Se necesitan permisos de administrador. Se abrira el aviso de UAC...' Yellow
    $arg = '-NoProfile -ExecutionPolicy Bypass -File "' + $PSCommandPath + '"'
    if ($SinAccesos) { $arg += ' -SinAccesos' }
    if ($SoloVerificar) { $arg += ' -SoloVerificar' }
    Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $arg
    return
}

Escribir ''
Escribir '==========================================================' Cyan
Escribir '  VB6 Anywhere - instalacion' Cyan
Escribir '==========================================================' Cyan
Escribir ("  Carpeta: {0}" -f $Raiz) DarkGray
if ($ModoIde -eq 'portable') {
    Escribir ("  IDE: {0}   (copia portable)" -f $Ide) Yellow
}
Escribir ''

# ---------------------------------------------------------------------------
#  1. Comprobaciones basicas
# ---------------------------------------------------------------------------
$faltantes = @()
if (-not (Test-Path $Vb6))       { $faltantes += $Vb6 }
if (-not (Test-Path $Controles)) { $faltantes += $Controles }
if ($faltantes.Count -gt 0) {
    Escribir '  ERROR: falta contenido del paquete:' Red
    $faltantes | ForEach-Object { Escribir ("     " + $_) Red }
    Read-Host '  Enter para salir'
    exit 1
}
Escribir ("  IDE: {0}" -f (Get-Item $Vb6).VersionInfo.FileVersion) DarkGray

if ($ModoIde -eq 'portable') {
    Escribir ''
    Escribir '  VB6 no esta instalado en esta PC: se usara la copia portable.' Cyan
    Escribir '  El IDE arranca igual: aqui se copia el runtime VBA que necesita.' Cyan
}

if ($SoloVerificar) { Escribir '  (SoloVerificar: no se escribe nada)' Yellow }

# ---------------------------------------------------------------------------
#  1b. Runtime VBA compartido  (imprescindible para que el IDE arranque)
# ---------------------------------------------------------------------------
# El IDE de VB6 usa el motor VBA como editor de codigo. Si no encuentra
# VBE6INTL.DLL / MSO97RT.DLL en su ubicacion estandar, abre la ventana de
# bienvenida y se cierra con "Error inesperado. Se cerrara el programa".
Escribir ''
Escribir '  [1/6] Runtime VBA compartido' Cyan
$vbaOrigen = Join-Path $Raiz '02_Componentes\VBA'
if ([Environment]::Is64BitOperatingSystem) {
    $comunes = @( (Join-Path $env:SystemDrive 'Program Files (x86)\Common Files') )
}
else {
    $comunes = @()
}
$comunes += $env:CommonProgramFiles
$copiadosVba = 0
$omitidosVba = 0
if (-not $SoloVerificar -and (Test-Path $vbaOrigen)) {
    $archivosVba = Get-ChildItem $vbaOrigen -Recurse -File
    foreach ($comun in ($comunes | Select-Object -Unique)) {
        if (-not (Test-Path $comun)) { continue }
        $vbaDestino = Join-Path $comun 'Microsoft Shared\VBA'
        foreach ($f in $archivosVba) {
            $rel = $f.FullName.Substring($vbaOrigen.Length).TrimStart('\')
            $dst = Join-Path $vbaDestino $rel
            $dir = Split-Path $dst
            if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
            # Si ya esta igual, no se toca: evita el error 1224 cuando el IDE
            # tiene la DLL mapeada (fichero en uso).
            if (Test-Path $dst) {
                $yaIgual = $false
                try {
                    $yaIgual = ((Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash -eq
                                (Get-FileHash -LiteralPath $dst -Algorithm SHA256).Hash)
                } catch { $yaIgual = $false }
                if ($yaIgual) { $omitidosVba++; continue }
            }
            try {
                Copy-Item -LiteralPath $f.FullName -Destination $dst -Force -ErrorAction Stop
                $copiadosVba++
            }
            catch {
                $omitidosVba++
            }
        }
    }
}
if ($SoloVerificar) { Escribir '        (no se copia en modo verificar)' Yellow }
elseif ($copiadosVba -gt 0) { Escribir ("        OK ({0} copiados, {1} ya estaban o en uso)" -f $copiadosVba, $omitidosVba) Green }
elseif ($omitidosVba -gt 0) { Escribir ("        OK (ya presentes: {0} archivos)" -f $omitidosVba) Green }
else { Escribir '        AVISO: falta la carpeta 02_Componentes\VBA en el paquete' Yellow }

# El IDE no solo necesita el fichero: lo localiza por esta clave. En una PC
# limpia no existe, y entonces el IDE abre el splash y se cierra en silencio
# con "Error inesperado". Comprobado en una VM virgen: con la clave arranca,
# sin la clave no.
$sharedDir = Join-Path (Join-Path $env:SystemDrive 'Program Files (x86)\Common Files') 'Microsoft Shared'
if (-not (Test-Path -LiteralPath $sharedDir)) { $sharedDir = Join-Path $env:CommonProgramFiles 'Microsoft Shared' }
$stKey  = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Shared Tools'
$msoDll = Join-Path $sharedDir 'VBA\MSO97RT.DLL'
$msoReg = (Get-ItemProperty -Path (Join-Path $stKey 'mso97rt') -Name Path -ErrorAction SilentlyContinue).Path
$msoOk  = [bool]($msoReg -and (Test-Path -LiteralPath $msoReg))
if (-not $SoloVerificar) {
    if ($msoOk) {
        Escribir '        MSO97RT ya registrado en esta PC: se respeta' DarkGray
    }
    elseif (Test-Path -LiteralPath $msoDll) {
        # (todavia no existe la funcion Set-Valor: se escribe directo)
        if (-not (Test-Path $stKey)) { New-Item -Path $stKey -Force | Out-Null }
        New-ItemProperty -Path $stKey -Name 'SharedFilesDir' -Value $sharedDir -PropertyType String -Force | Out-Null
        $msoKey = Join-Path $stKey 'mso97rt'
        if (-not (Test-Path $msoKey)) { New-Item -Path $msoKey -Force | Out-Null }
        New-ItemProperty -Path $msoKey -Name 'Path' -Value $msoDll -PropertyType String -Force | Out-Null
        $msoReg = $msoDll
        $msoOk  = $true
        Escribir '        MSO97RT registrado (Shared Tools)' Green
    }
    else {
        Escribir '        AVISO: no se encontro MSO97RT.DLL que registrar' Yellow
    }
}

# ---------------------------------------------------------------------------
#  2. Claves de registro
# ---------------------------------------------------------------------------
function Set-Clave([string]$ruta) {
    if (-not (Test-Path $ruta)) { New-Item -Path $ruta -Force | Out-Null }
}

function Set-Valor([string]$ruta, [string]$nombre, [string]$valor) {
    Set-Clave $ruta
    if ($nombre -eq '') { Set-Item -Path $ruta -Value $valor -Force }
    else { New-ItemProperty -Path $ruta -Name $nombre -Value $valor -PropertyType String -Force | Out-Null }
}

$base = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft'

Escribir ''
Escribir '  [2/6] Marca de edicion de VB6' Cyan
# Sin esta marca el IDE se cree "Working Model Edition" y no compila.
if (-not $SoloVerificar) {
    Set-Valor "$base\IE4\DependentComponents" 'VB98' 'Microsoft Visual Basic 6.0 Enterprise Edition'
}
Escribir '        OK' Green

Escribir '  [3/6] Registro del IDE' Cyan
if (-not $SoloVerificar) {
    # Registro completo de una instalacion real de VS6/VB6, con las rutas
    # reescritas a la ubicacion actual del paquete. Sin esto el IDE abre y se
    # cierra con "Error inesperado": no basta con Path/Path32.
    $regVm = Join-Path $Licencias 'vb6_registro.reg'
    if (Test-Path $regVm) {
        $txt = [System.IO.File]::ReadAllText($regVm, [System.Text.Encoding]::Unicode)
        $ideEsc = $Ide.Replace('\', '\\')
        $comEsc = (Join-Path $Raiz '01_IDE\Common').Replace('\', '\\')
        $vsEsc = (Join-Path $Raiz '01_IDE').Replace('\', '\\')
        # El .reg trae __PKG__ como marcador de la carpeta del paquete, para que
        # funcione sin importar donde se descomprima.
        $txt = $txt.Replace('__PKG__\\VB98', $ideEsc)
        $txt = $txt.Replace('__PKG__\\Common', $comEsc)
        $txt = $txt.Replace('__PKG__', $vsEsc)
        $tmpReg = Join-Path $env:TEMP 'vb6_registro_portable.reg'
        [System.IO.File]::WriteAllText($tmpReg, $txt, (New-Object System.Text.UnicodeEncoding($false, $true)))
        $reg32 = Join-Path $env:WINDIR 'SysWOW64\reg.exe'
        $ErrorActionPreference = 'Continue'
        if (Test-Path $reg32) { & $reg32 import $tmpReg /reg:32 2>&1 | Out-Null }
        else { & reg.exe import $tmpReg 2>&1 | Out-Null }
        $ErrorActionPreference = 'Stop'
        Remove-Item $tmpReg -Force -ErrorAction SilentlyContinue
    }
    else {
        Escribir '        AVISO: falta vb6_registro.reg (el IDE no arrancara)' Yellow
    }

        # Asociacion de .vbp: sin esto, el doble clic en un proyecto abre el VB6 que este
    # asociado en el sistema, que puede ser OTRA copia con otro registro, y da errores.
    # Abierto desde el IDE no pasa, porque usa el suyo.
    $clases = 'HKLM:\SOFTWARE\Classes\WOW6432Node'
    $progId = 'VisualBasic.Project'
    foreach ($sub in @('', 'shell', 'shell\open', 'shell\open\command')) {
        $k = if ($sub) { Join-Path $clases ($progId + '\' + $sub) } else { Join-Path $clases $progId }
        if (-not (Test-Path $k)) { New-Item -Path $k -Force -ErrorAction SilentlyContinue | Out-Null }
    }
    Set-ItemProperty -Path (Join-Path $clases $progId) -Name '(default)' -Value 'Microsoft Visual Basic 6.0 Project' -ErrorAction SilentlyContinue
    Set-ItemProperty -Path (Join-Path $clases ($progId + '\shell\open\command')) -Name '(default)' -Value ('"' + $Vb6 + '" "%1"') -ErrorAction SilentlyContinue
    if (-not (Test-Path (Join-Path $clases '.vbp'))) { New-Item -Path (Join-Path $clases '.vbp') -Force -ErrorAction SilentlyContinue | Out-Null }
    Set-ItemProperty -Path (Join-Path $clases '.vbp') -Name '(default)' -Value $progId -ErrorAction SilentlyContinue
    Escribir '        asociacion .vbp -> este IDE' DarkGray

Set-Valor "$base\VisualStudio\6.0" 'InstallDir' $Ide
    # Path/Path32 son los que usa VB6 para localizar sus propios archivos al
    # arrancar. Si apuntan a otra carpeta el IDE muere con "Unexpected error".
    Set-Valor "$base\Visual Basic\6.0" 'Path'   $Ide
    Set-Valor "$base\Visual Basic\6.0" 'Path32' $Ide

    # Add-ins del VS6 que no funcionan sin el resto del producto instalado
    # (VCM pide repositorio, ResEdit/DataView piden componentes extra).
    $addins = 'HKCU:\Software\Microsoft\Visual Basic\6.0\AddIns'
    if (Test-Path $addins) {
        foreach ($n in 'VcmMgr.Connect', 'ResEdit6.Connect', 'PDAddIn.AddIn',
                        'TempMgr.AddInDesigner1', 'APIDeclarationLoader.AddInDesigner') {
            $k = Join-Path $addins $n
            if (Test-Path $k) {
                New-ItemProperty -Path $k -Name 'LoadBehavior' -Value 0 -PropertyType DWord -Force | Out-Null
            }
        }
    }
}
Escribir '        OK' Green

Escribir '  [4/6] Cache de componentes (.oca)' Cyan
# VB6 resuelve las versiones de los controles por esta cache. Si falta, intenta
# instanciar el control y algunos (Spread 2.5) piden licencia de diseno.
$mapa = @(
    @{ Key = '{831FDD16-0C5C-11D2-A9FC-0000F8754DA1}#2.0';  Oca = '02_Componentes\Controles\MSCOMCTL.oca' },
    @{ Key = '{831FDD16-0C5C-11D2-A9FC-0000F8754DA1}#2.1';  Oca = '02_Componentes\Controles\MSCOMCTL.oca' },
    @{ Key = '{831FDD16-0C5C-11D2-A9FC-0000F8754DA1}#2.2';  Oca = '02_Componentes\Controles\MSCOMCTL.oca' },
    @{ Key = '{86CF1D34-0C5F-11D2-A9FC-0000F8754DA1}#2.0';  Oca = '02_Componentes\Controles\MSCOMCT2.oca' },
    @{ Key = '{0BA686C6-F7D3-101A-993E-0000C0EF6F5E}#1.0';  Oca = '02_Componentes\Controles\THREED32.oca' }
)
$faltanPaquete = @()
if (-not $SoloVerificar) {
    $rutaCache = "$base\Visual Basic\6.0"
    foreach ($m in $mapa) {
        $archivo = Join-Path $Raiz $m.Oca
        if (Test-Path $archivo) {
            Set-Valor "$rutaCache\$($m.Key)" '' $archivo
        }
        else {
            $faltanPaquete += $m.Oca
        }
    }
}
if ($faltanPaquete.Count -gt 0) {
    Escribir ("        AVISO: faltan en el paquete -> " + (($faltanPaquete | Sort-Object -Unique) -join ', ')) Yellow
}
else {
    Escribir '        OK' Green
}

# DAO 3.51: el proyecto estandar de VB6 trae una referencia a DAO. dao350.dll no
# se auto-registra (no exporta DllRegisterServer), asi que hay que registrar su
# type library (version 4.0) desde un proceso de 32 bits, que es el que lee VB6.
Escribir '  [5/6] DAO 3.51 (referencia del proyecto estandar)' Cyan
$daoDll = Join-Path $Ide 'DAO350.DLL'
$daoKey = 'HKLM:\SOFTWARE\Classes\TypeLib\{00025E01-0000-0000-C000-000000000046}\4.0\0\win32'
$daoRuta = (Get-ItemProperty $daoKey -ErrorAction SilentlyContinue).'(default)'
$daoOk = [bool]($daoRuta -and (Test-Path -LiteralPath $daoRuta))
if (-not $SoloVerificar) {
    if ($daoOk) {
        Escribir '        DAO 3.51 ya registrada en esta PC: se respeta' DarkGray
    }
    elseif (Test-Path $daoDll) {
        $ps32 = Join-Path $env:WINDIR 'SysWOW64\WindowsPowerShell\v1.0\powershell.exe'
        $regTl = Join-Path $Herram 'Registrar-Typelib.ps1'
        if (Test-Path $ps32) {
            & $ps32 -NoProfile -ExecutionPolicy Bypass -File $regTl -Ruta $daoDll 2>&1 | Out-Null
        }
        else {
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $regTl -Ruta $daoDll 2>&1 | Out-Null
        }
        $daoRuta = (Get-ItemProperty $daoKey -ErrorAction SilentlyContinue).'(default)'
        $daoOk = [bool]($daoRuta -and (Test-Path -LiteralPath $daoRuta))
    }
}
if ($daoOk) { Escribir '        OK' Green }
else { Escribir '        AVISO: DAO 3.51 sin registrar (el IDE pedira DAO350.DLL)' Yellow }

Escribir '  [6/6] Licencias de diseno' Cyan
$regLic = Join-Path $Licencias 'vb6_controles.reg'
if ((Test-Path $regLic) -and -not $SoloVerificar) {
    $reg32 = Join-Path $env:WINDIR 'SysWOW64\reg.exe'
    $ErrorActionPreference = 'Continue'
    if (Test-Path $reg32) {
        & $reg32 import $regLic /reg:32 2>&1 | Out-Null
    } else {
        & reg.exe import $regLic 2>&1 | Out-Null
    }
    $ErrorActionPreference = 'Stop'
}
$nLic = (Get-ChildItem 'HKLM:\SOFTWARE\Classes\Licenses' -ErrorAction SilentlyContinue | Measure-Object).Count
Escribir ("        OK ({0} claves registradas)" -f $nLic) Green


# ---------------------------------------------------------------------------
#  3. Registro de componentes
# ---------------------------------------------------------------------------
Escribir ''
Escribir '  Registrando controles ActiveX...' Cyan
$regsvr = Join-Path $env:WINDIR 'SysWOW64\regsvr32.exe'
if (-not (Test-Path $regsvr)) { $regsvr = 'regsvr32.exe' }
$ocx = Get-ChildItem $Controles -File -ErrorAction SilentlyContinue |
       Where-Object { $_.Extension -match '(?i)^\.ocx$' -or $_.Name -match '(?i)^(MSRDO20|MSSTDFMT|MSBIND)\.DLL$' }
$okC = 0; $malC = 0
foreach ($o in $ocx) {
    if ($SoloVerificar) { $okC++; continue }
    $p = Start-Process -FilePath $regsvr -ArgumentList @('/s', "`"$($o.FullName)`"") -Wait -PassThru -WindowStyle Hidden
    if ($p.ExitCode -eq 0) { $okC++ } else { $malC++ ; Escribir ("        FALLO: " + $o.Name) Yellow }
}
if ($SoloVerificar) { Escribir ("        {0} controles en el paquete (no se registran en modo verificar)" -f $okC) Green } else { Escribir ("        {0} registrados, {1} con error" -f $okC, $malC) Green }

# ---------------------------------------------------------------------------
#  4. Accesos directos
# ---------------------------------------------------------------------------
if (-not $SinAccesos -and -not $SoloVerificar) {
    Escribir ''
    Escribir '  Creando accesos directos...' Cyan

    # Crea un .lnk. El flag de "ejecutar como administrador" se pone tocando el
    # byte 0x15 de la cabecera: WScript.Shell no lo expone y hay que hacerlo asi.
    function Nuevo-Acceso {
        param([string]$Ruta, [string]$Destino, [string]$Argumentos, [string]$Carpeta, [string]$Icono, [string]$Descripcion, [switch]$ComoAdmin)
        $sh = New-Object -ComObject WScript.Shell
        $lnk = $sh.CreateShortcut($Ruta)
        $lnk.TargetPath = $Destino
        if ($Argumentos) { $lnk.Arguments = $Argumentos }
        if ($Carpeta)    { $lnk.WorkingDirectory = $Carpeta }
        if ($Icono)      { $lnk.IconLocation = $Icono }
        if ($Descripcion){ $lnk.Description = $Descripcion }
        $lnk.Save()
        if ($ComoAdmin) {
            $b = [System.IO.File]::ReadAllBytes($Ruta)
            $b[0x15] = $b[0x15] -bor 0x20
            [System.IO.File]::WriteAllBytes($Ruta, $b)
        }
    }

    $escritorio = [Environment]::GetFolderPath('Desktop')
    # Nombres anteriores: se retiran para no dejar varios iconos en el escritorio
    foreach ($viejo in 'VB6 (sandbox).lnk', 'Visual Basic 6.lnk') {
        $rutaVieja = Join-Path $escritorio $viejo
        if (Test-Path $rutaVieja) { Remove-Item $rutaVieja -Force -ErrorAction SilentlyContinue }
    }
    Nuevo-Acceso -Ruta (Join-Path $escritorio 'Visual Basic 6.0 Portable.lnk') -Destino $Vb6 -Carpeta $Ide `
                 -Icono "$Vb6,0" -Descripcion 'Visual Basic 6.0 Portable - IDE (VB6 Anywhere)' -ComoAdmin
    Escribir '        Escritorio: Visual Basic 6.0 Portable' DarkGray

    # El menu Inicio es lo unico que indexa la busqueda de Windows: un acceso en el
    # escritorio NO aparece al escribir "vb6" en el buscador. Con esto si.
    $programas = [Environment]::GetFolderPath('Programs')
    $grupo = Join-Path $programas 'VB6 Anywhere'
    New-Item -ItemType Directory -Force -Path $grupo | Out-Null
    Nuevo-Acceso -Ruta (Join-Path $grupo 'Visual Basic 6.0 Portable.lnk') -Destino $Vb6 -Carpeta $Ide `
                 -Icono "$Vb6,0" -Descripcion 'Microsoft Visual Basic 6.0 Portable - IDE (VB6 Anywhere)' -ComoAdmin
    # Alias corto: Windows busca por el nombre visible, y "Visual Basic 6.0 Portable"
    # no responde a "vb6". Con este acceso, si.
    $aliasViejo = Join-Path $grupo 'VB6 (Visual Basic 6).lnk'
    if (Test-Path $aliasViejo) { Remove-Item $aliasViejo -Force -ErrorAction SilentlyContinue }
    Nuevo-Acceso -Ruta (Join-Path $grupo 'VB6.lnk') -Destino $Vb6 -Carpeta $Ide `
                 -Icono "$Vb6,0" -Descripcion 'VB6 - Visual Basic 6.0 Portable' -ComoAdmin
    Nuevo-Acceso -Ruta (Join-Path $grupo 'VB6 Anywhere (carpeta).lnk') -Destino (Join-Path $env:WINDIR 'explorer.exe') `
                 -Argumentos ('"' + $Raiz + '"') -Icono (Join-Path $env:WINDIR 'explorer.exe,0') `
                 -Descripcion 'Carpeta del paquete VB6 Anywhere'
    Nuevo-Acceso -Ruta (Join-Path $grupo 'Desinstalar VB6 Anywhere.lnk') -Destino (Join-Path $Raiz '9-Desinstalar.bat') `
                 -Carpeta $Raiz -Descripcion 'Quita el registro, los controles y el runtime VBA'

    # Restos de intentos anteriores: un acceso "Microsoft Visual Basic 6.0" en el menu
    # Inicio apunta a una copia portable vieja y GANA como mejor coincidencia en la
    # busqueda de Windows (el nombre del .lnk manda sobre el nuestro). Se retira solo
    # si su destino NO es una instalacion real de VB6.
    foreach ($baseInicio in @((Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs'), [Environment]::GetFolderPath('Programs'))) {
        if (-not $baseInicio -or -not (Test-Path $baseInicio)) { continue }
        foreach ($viejo in (Get-ChildItem $baseInicio -Recurse -Filter 'Microsoft Visual Basic 6.0*.lnk' -File -ErrorAction SilentlyContinue)) {
            $destinoViejo = $null
            try { $destinoViejo = (New-Object -ComObject WScript.Shell).CreateShortcut($viejo.FullName).TargetPath } catch { }
            if ($destinoViejo -and ($destinoViejo -notlike '*\Microsoft Visual Studio\VB98\*')) {
                Remove-Item $viejo.FullName -Force -ErrorAction SilentlyContinue
                if (-not (Test-Path $viejo.FullName)) {
                    Escribir '        retirado acceso antiguo: Microsoft Visual Basic 6.0' DarkGray
                    $carpetaVieja = Split-Path $viejo.FullName -Parent
                    if ((Get-ChildItem $carpetaVieja -Force -ErrorAction SilentlyContinue | Measure-Object).Count -eq 0) {
                        Remove-Item $carpetaVieja -Recurse -Force -ErrorAction SilentlyContinue
                    }
                }
            }
        }
    }
    Escribir '        Menu Inicio: VB6 (Visual Basic 6), carpeta y desinstalar' DarkGray
}

# ---------------------------------------------------------------------------
#  5. Verificacion
# ---------------------------------------------------------------------------
Escribir ''
Escribir '  Verificacion:' Cyan
$ruta384 = (Get-ItemProperty "$base\Visual Basic\6.0\{43093C9E-3720-11D9-A457-00115B44C4A0}#38.4" -ErrorAction SilentlyContinue).'(default)'
$rutaPath = (Get-ItemProperty "$base\Visual Basic\6.0" -Name Path -ErrorAction SilentlyContinue).Path
$checks = @(
    @{ n = 'IDE VB6.EXE';           ok = (Test-Path $Vb6);                          d = $Vb6 },
    @{ n = 'Path del IDE';          ok = ($rutaPath -eq $Ide);                      d = ("-> " + $rutaPath) },
    @{ n = 'Marca de edicion';      ok = ((Get-ItemProperty "$base\IE4\DependentComponents" -Name VB98 -ErrorAction SilentlyContinue) -ne $null); d = '' },
    @{ n = 'MSCOMCTL registrado';   ok = (Test-Path 'HKLM:\SOFTWARE\Classes\WOW6432Node\TypeLib\{831FDD16-0C5C-11D2-A9FC-0000F8754DA1}'); d = '' }
)
# El IDE necesita el runtime VBA en Common Files (si falta: "Error inesperado")
$vbaOk = $false
$vbaRuta = ''
foreach ($comun in $comunes) {
    $cand = Join-Path (Join-Path $comun 'Microsoft Shared\VBA') 'VBA6\3082\VBE6INTL.DLL'
    if (Test-Path $cand) { $vbaOk = $true; $vbaRuta = $cand; break }
}
$checks += @{ n = 'Runtime VBA (IDE)'; ok = $vbaOk; d = $(if ($vbaOk) { '-> ' + $vbaRuta } else { 'sin VBE6INTL.DLL en Common Files' }) }
$checks += @{ n = 'Registro VS6/VB6';  ok = ((Test-Path (Join-Path "$base\Visual Basic\6.0" 'External Tools')) -and (Test-Path (Join-Path "$base\VisualStudio\6.0" 'Setup'))); d = '' }
$checks += @{ n = 'DAO 3.51 (IDE)';    ok = $daoOk;  d = ("-> " + $(if ($daoRuta) { $daoRuta } else { 'sin registrar' })) }
$checks += @{ n = 'MSO97RT registrado'; ok = $msoOk; d = ("-> " + $(if ($msoReg) { $msoReg } else { 'sin registrar' })) }

$todoOk = $true
foreach ($c in $checks) {
    $marca = if ($c.ok) { 'OK   ' } else { 'FALLA'; $todoOk = $false }
    $color = if ($c.ok) { 'Green' } else { 'Red' }
    Escribir ("     {0}  {1}  {2}" -f $marca, $c.n, $c.d) $color
}

Escribir ''
if ($todoOk) {
    Escribir '  Listo: IDE y compilacion funcionando desde el paquete portable.' Green
    Escribir '  Abre el IDE con 4-Abrir VB6.bat o con el acceso del escritorio (UAC).' Green
    Escribir '  Para generar el EXE sin abrir el IDE: 3-Compilar.bat' Green
} else {
    Escribir '  Hay comprobaciones que fallan. Revisa los mensajes de arriba.' Yellow
}
Escribir ''
if (-not $NoPause) { Read-Host '  Enter para cerrar' }

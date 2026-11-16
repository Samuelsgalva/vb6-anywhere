#Requires -Version 5.0
<#
    Diagnostico de solo lectura para VB6 Anywhere.

    Recoge todo lo necesario para entender por que el IDE no arranca en una PC:
    idioma de Windows, runtime VBA compartido (y en que idiomas), registro,
    versiones/hashes de los binarios, DAO, y otras instalaciones de VB6/VBA.

    NO escribe en el registro, NO copia ni borra nada del sistema.
    Genera  diagnostico.txt  junto a la carpeta del paquete.
#>
$ErrorActionPreference = 'Continue'

$Raiz = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$Ide  = Join-Path $Raiz '01_IDE\VB98'
$Vba  = Join-Path $Raiz '02_Componentes\VBA'
$salida = Join-Path $Raiz 'diagnostico.txt'

$o = New-Object System.Collections.Generic.List[string]
function W([string]$t = '') { $o.Add($t) }
function Titulo([string]$t) { W ''; W ('=' * 72); W ('  ' + $t); W ('=' * 72) }
function Dato([string]$k, $v) { W ('  {0,-34} {1}' -f $k, $v) }

Titulo 'VB6 ANYWHERE - DIAGNOSTICO'
Dato 'Fecha'            (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Dato 'Equipo'           $env:COMPUTERNAME
Dato 'Usuario'          "$env:USERDOMAIN\$env:USERNAME"
Dato 'Carpeta del paquete' $Raiz
Dato 'Elevado'          ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# ---------------------------------------------------------------------------
Titulo '1. SISTEMA'
Titulo '1.1 Windows'
try {
    $os = Get-CimInstance Win32_OperatingSystem
    Dato 'Caption'        $os.Caption
    Dato 'Version / Build' ("{0} / {1}" -f $os.Version, $os.BuildNumber)
    Dato 'Arquitectura'   $os.OSArchitecture
} catch { Dato 'ERROR' $_.Exception.Message }
Dato 'Es 64-bit'       ([Environment]::Is64BitOperatingSystem)

Titulo '1.2 Idioma'
try { Dato 'InstalledUICulture' ([Globalization.CultureInfo]::InstalledUICulture.Name + ' (LCID ' + [Globalization.CultureInfo]::InstalledUICulture.LCID + ')') } catch {}
try { Dato 'CurrentUICulture'   ([Globalization.CultureInfo]::CurrentUICulture.Name + ' (LCID ' + [Globalization.CultureInfo]::CurrentUICulture.LCID + ')') } catch {}
try { $sl = Get-WinSystemLocale; Dato 'Locale del sistema' ($sl.Name + '  ' + $sl.DisplayName) } catch {}
try { $ov = Get-WinUILanguageOverride; Dato 'UI language override' $(if ($ov) { $ov.Name } else { '(ninguno)' }) } catch {}
try { Get-WinUserLanguageList | ForEach-Object { Dato 'Idioma de usuario' (($_.LanguageTag -join ',') + '  ' + (($_.Autonym -join ','))) } } catch {}
Dato 'env LANG'        $(if ($env:LANG) { $env:LANG } else { '(vacio)' })

Titulo '1.3 Rutas clave'
Dato 'ProgramFiles'          $env:ProgramFiles
Dato 'ProgramFiles(x86)'     ${env:ProgramFiles(x86)}
Dato 'CommonProgramFiles'    $env:CommonProgramFiles
Dato 'CommonProgramFiles(x86)' ${env:CommonProgramFiles(x86)}
Dato 'TEMP'                  $env:TEMP

# ---------------------------------------------------------------------------
Titulo '2. EL PAQUETE'
Titulo '2.1 Binarios del IDE'
foreach ($f in 'VB6.EXE', 'VB6IDE.DLL', 'VBA6.DLL', 'DAO350.DLL', 'VB6.OLB', 'VB6EXT.OLB') {
    $p = Join-Path $Ide $f
    if (Test-Path -LiteralPath $p) {
        $i = Get-Item -LiteralPath $p
        $h = try { (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.Substring(0, 16) } catch { '?' }
        Dato $f ("{0:N0} bytes  ver={1}  sha={2}" -f $i.Length, $i.VersionInfo.FileVersion, $h)
    }
    else { Dato $f 'NO EXISTE' }
}

Titulo '2.2 Runtime VBA del paquete (02_Componentes\VBA)'
if (Test-Path $Vba) {
    Get-ChildItem $Vba -Recurse -File | ForEach-Object { Dato $_.FullName.Substring($Vba.Length + 1) ("{0:N0} bytes" -f $_.Length) }
}
else { Dato 'carpeta' 'NO EXISTE' }

Titulo '2.3 Controles incluidos'
$ctrl = Join-Path $Raiz '02_Componentes\Controles'
if (Test-Path $ctrl) { Get-ChildItem $ctrl -File | ForEach-Object { Dato $_.Name ("{0:N0} bytes" -f $_.Length) } }
else { Dato 'carpeta' 'NO EXISTE' }

# ---------------------------------------------------------------------------
Titulo '3. RUNTIME VBA COMPARTIDO (la causa habitual)'
$rutasVba = @(
    (Join-Path ${env:ProgramFiles(x86)} 'Common Files\Microsoft Shared\VBA'),
    (Join-Path $env:ProgramFiles          'Common Files\Microsoft Shared\VBA')
) | Where-Object { $_ }

foreach ($p in $rutasVba) {
    Titulo ("3.x " + $p)
    if (-not (Test-Path $p)) { Dato 'estado' 'NO EXISTE  <-- el IDE se cerrara solo si falta'; continue }
    Dato 'estado' 'existe'
    Get-ChildItem $p -Recurse -File | ForEach-Object {
        Dato ($_.FullName.Substring($p.Length + 1)) ("{0:N0} bytes  ver={1}" -f $_.Length, $_.VersionInfo.FileVersion)
    }
    $vba6 = Join-Path $p 'VBA6'
    if (Test-Path $vba6) {
        $idiomas = Get-ChildItem $vba6 -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
        Dato 'Carpetas de idioma bajo VBA6' $(if ($idiomas) { $idiomas -join ', ' } else { 'NINGUNA' })
        $conIntl = 0
        foreach ($lc in $idiomas) {
            $v = Join-Path (Join-Path $vba6 $lc) 'VBE6INTL.DLL'
            $hay = Test-Path $v
            if ($hay) { $conIntl++ }
            Dato ("  VBE6INTL en " + $lc) $(if ($hay) { 'SI' } else { 'NO' })
        }
        # La carpeta NO la elige el idioma de Windows: la elige el idioma del IDE.
        # Este paquete lleva el IDE en espanol, asi que usa 3082 aunque el Windows
        # sea es-MX, ingles, etc. Solo importa que exista ALGUNA con VBE6INTL.
        if ($conIntl -eq 0) { Dato 'AVISO' 'ninguna carpeta tiene VBE6INTL.DLL  <-- el IDE se cerrara solo' }
    }
    else { Dato 'VBA6' 'NO EXISTE  <-- el IDE se cerrara solo' }
}

# ---------------------------------------------------------------------------
Titulo '4. REGISTRO (vista de 32 bits)'
function RegVal([string]$ruta, [string]$nombre) {
    try {
        $v = (Get-ItemProperty -Path $ruta -Name $nombre -ErrorAction Stop).$nombre
        Dato $nombre $v
    } catch { Dato $nombre '(no existe)' }
}
$base = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft'
RegVal "$base\Visual Basic\6.0" 'Path'
RegVal "$base\Visual Basic\6.0" 'Path32'
RegVal "$base\VisualStudio\6.0" 'InstallDir'
RegVal "$base\VisualStudio\6.0\Setup\Microsoft Visual Basic" 'ProductDir'
RegVal "$base\IE4\DependentComponents" 'VB98'
RegVal 'HKLM:\SOFTWARE\Classes\TypeLib\{00025E01-0000-0000-C000-000000000046}\4.0\0\win32' '(default)'
RegVal 'HKLM:\SOFTWARE\Classes\TypeLib\{00025E01-0000-0000-C000-000000000046}\5.0\0\win32' '(default)'
try {
    $n = (Get-ChildItem "$base\Visual Basic\6.0" -ErrorAction SilentlyContinue | Measure-Object).Count
    Dato 'Subclaves bajo Visual Basic\6.0' $n
} catch { Dato 'Subclaves bajo Visual Basic\6.0' '?' }
try {
    $lic = (Get-ChildItem 'HKLM:\SOFTWARE\Classes\Licenses' -ErrorAction SilentlyContinue | Measure-Object).Count
    Dato 'Claves en HKCR\Licenses' $lic
} catch {}
foreach ($g in '{831FDD16-0C5C-11D2-A9FC-0000F8754DA1}', '{00025E01-0000-0000-C000-000000000046}') {
    Dato ("TypeLib " + $g) $(if (Test-Path "HKLM:\SOFTWARE\Classes\TypeLib\$g") { 'registrada' } else { 'NO registrada' })
}

# ---------------------------------------------------------------------------
Titulo '5. OTRAS INSTALACIONES DE VB6 / VBA EN LA MAQUINA'
foreach ($p in (Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\VB98\VB6.EXE'),
               (Join-Path $env:ProgramFiles 'Microsoft Visual Studio\VB98\VB6.EXE')) {
    Dato $p $(if (Test-Path -LiteralPath $p) { 'EXISTE -> usa: ' + (Get-Item -LiteralPath $p).VersionInfo.FileVersion } else { 'no' })
}
foreach ($p in (Join-Path $env:WINDIR 'SysWOW64\msvbvm60.dll'), (Join-Path $env:WINDIR 'System32\msvbvm60.dll')) {
    Dato $p $(if (Test-Path -LiteralPath $p) { 'EXISTE -> ' + (Get-Item -LiteralPath $p).VersionInfo.FileVersion } else { 'no' })
}
foreach ($k in 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\VBA', 'HKCU:\Software\Microsoft\VBA') {
    Dato $k $(if (Test-Path $k) { 'existe: ' + ((Get-ChildItem $k -ErrorAction SilentlyContinue | Select-Object -ExpandProperty PSChildName) -join ', ') } else { 'no' })
}
try {
    $office = Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Office' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty PSChildName
    Dato 'Versiones de Office en HKLM' $(if ($office) { $office -join ', ' } else { 'ninguna' })
} catch {}

# ---------------------------------------------------------------------------
Titulo '6. PROCESOS VB6 EN EJECUCION (modulos cargados)'
$vbs = Get-Process VB6 -ErrorAction SilentlyContinue
if (-not $vbs) { Dato 'VB6.EXE' 'no hay ninguno en ejecucion' }
foreach ($p in $vbs) {
    Dato 'PID' ($p.Id.ToString() + '  ' + $p.MainWindowTitle)
    try {
        $p.Modules | Where-Object { $_.FileName -match '(?i)vba|mso|mrt|dao|vbe6|vb6' } |
            ForEach-Object { Dato '  modulo' $_.FileName }
    } catch { Dato '  modulos' '(no accesible: el proceso es de otra elevacion)' }
}

# ---------------------------------------------------------------------------
Titulo '6b. SHARED TOOLS (donde el IDE localiza MSO97RT)'
$st = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Shared Tools'
if (Test-Path $st) {
    Dato 'SharedFilesDir' ((Get-ItemProperty $st -ErrorAction SilentlyContinue).SharedFilesDir)
    $mso = (Get-ItemProperty (Join-Path $st 'mso97rt') -Name Path -ErrorAction SilentlyContinue).Path
    if ($mso) {
        Dato 'mso97rt\Path' $mso
        Dato '  el fichero existe' (Test-Path -LiteralPath $mso)
    } else {
        Dato 'mso97rt\Path' 'NO EXISTE  <-- el IDE se cerrara solo'
    }
} else {
    Dato 'Shared Tools' 'NO EXISTE  <-- el IDE se cerrara solo'
}

Titulo '7. NOTAS'
W '  - Si el IDE se cierra solo tras el splash, el primer sospechoso es el runtime'
W '    VBA compartido de la seccion 3: debe existir y contener VBE6INTL.DLL.'
W '  - La carpeta de idioma (3082) la elige el idioma del PROPIO IDE, no el de'
W '    Windows: este paquete trae el IDE en espanol, asi que 3082 es lo esperado'
W '    aunque el Windows sea es-MX, ingles, etc.'
W '  - Los tres binarios deben ser 6.00.9782 (ver seccion 2.1).'
W '  - 2-Verificar.bat muestra 7 comprobaciones OK/FALLA con las rutas en uso.'

$texto = $o -join "`r`n"
[System.IO.File]::WriteAllText($salida, $texto, (New-Object System.Text.UTF8Encoding($true)))
Write-Host ''
Write-Host '  ============================================================' -ForegroundColor Cyan
Write-Host '   Diagnostico generado (solo lectura, no cambio nada)' -ForegroundColor Cyan
Write-Host '  ============================================================' -ForegroundColor Cyan
Write-Host ('   Archivo: ' + $salida) -ForegroundColor Green
Write-Host ''
Write-Host '   Envialo tal cual para analizarlo.' -ForegroundColor Gray
Write-Host ''

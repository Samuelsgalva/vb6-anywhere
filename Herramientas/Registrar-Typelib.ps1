#Requires -Version 5.0
<#
    Registra una type library (y sus interfaces/clases) a partir de un DLL o TLB.

    Por que existe este script: dao350.dll NO exporta DllRegisterServer, asi que
    regsvr32 no sirve. La via correcta es LoadTypeLibEx con REGKIND_REGISTER.

    OJO con la vista del registro: LoadTypeLibEx escribe en la vista del proceso
    que lo llama. VB6 es de 32 bits, asi que esto hay que ejecutarlo con el
    PowerShell de SysWOW64:

        %WINDIR%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe -File Registrar-Typelib.ps1 -Ruta <dll>

    Codigos de salida: 0 = registrada, distinto de 0 = HRESULT del error.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Ruta
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $Ruta)) {
    Write-Error ("No existe: " + $Ruta)
    exit 2
}

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class TypeLibReg {
    // REGKIND_NONE = 0 (solo cargar), REGKIND_REGISTER = 1 (cargar y registrar)
    [DllImport("oleaut32.dll", CharSet = CharSet.Unicode)]
    public static extern int LoadTypeLibEx(string szFile, int regKind, out IntPtr pptlib);
}
'@

$ptr = [IntPtr]::Zero
$hr  = [TypeLibReg]::LoadTypeLibEx($Ruta, 1, [ref]$ptr)
if ($ptr -ne [IntPtr]::Zero) { [void][System.Runtime.InteropServices.Marshal]::Release($ptr) }

if ($hr -eq 0) {
    Write-Host ("  typelib registrada: " + $Ruta) -ForegroundColor Green
}
else {
    Write-Host ("  no se pudo registrar (HRESULT 0x{0:X8}): {1}" -f $hr, $Ruta) -ForegroundColor Yellow
}
exit $hr

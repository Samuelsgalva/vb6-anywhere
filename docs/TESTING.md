# Testing

Everything below was actually executed, not inferred. Dates are 2026-11-16 (local time, UTC-5).

The point of this file is that you can judge the package on evidence: which machine, what was
installed before, what was run, and what came out.

## Test machines

| # | Machine | State before | Notes |
|---|---|---|---|
| **A** | Windows 11 Enterprise Evaluation, build 26300, x64, Spanish | **virgin**. Nothing VB6-related had ever been installed | VMware Workstation 17.5, 4 GB RAM, 4 vCPU, 40 GB disk, no TPM, no Secure Boot |
| **B** | Windows 10 22H2 Pro, x64, Spanish | **virgin** | Same hypervisor and sizing, consumer ISO |
| **C** | Windows 11 Pro, build 26200, x64 | **had VB6 installed before** (real installation + an older portable copy) | The "upgrade" case, and the one that surfaces inherited-state problems |

Machines A and B were built by hand for this: fresh unattended install, then **only** the package
and a few sample projects were copied in. Nothing else was pre-installed, and the installer was
never run by the person who prepared the VM.

## Results

### Installation and verification

| ID | Test | Machine | Result |
|---|---|---|---|
| T1 | `1-Instalar.bat` on a clean machine | A | **8/8 checks OK** — IDE, Path, edition mark, MSCOMCTL, VBA runtime, VS6/VB6 registry, DAO 3.51, MSO97RT |
| T2 | `1-Instalar.bat` on a clean machine | B | **8/8 checks OK** |
| T3 | `2-Verificar.bat` right after installing | A, B | Idempotent: reports the same result without changing anything |
| T4 | `9-Desinstalar.bat` then `1-Instalar.bat` again | A | Clean round trip, 8/8 again |

### IDE

| ID | Test | Machine | Result |
|---|---|---|---|
| T5 | Open the IDE, "New Project" dialog | A | Opens; `wndclass_desked_gsk` window and IDEOwner present |
| T6 | Open the IDE | B | Opens |
| T7 | Load a real project and stay in design mode | A, B, C | `Prueba - Microsoft Visual Basic [diseño]` |
| T8 | Load a project while running **elevated** (`4-Abrir VB6.bat` path) | C | Opens and stays open |
| T9 | Load a project **non-elevated** | C | Opens and stays open |

### Compiler

| ID | Test | Machine | Result |
|---|---|---|---|
| T10 | `VB6.EXE /make` on a minimal project | A | `Prueba.exe`, **16,384 bytes**, exit 0, "La generación de 'Prueba.exe' ha tenido éxito" |
| T11 | Same, at the final path the user will use | A | exit 0, 16,384 bytes |
| T12 | Compile a **real legacy project** (Cronograma) | A | `Cronograma.exe`, **483,328 bytes**, exit 0 |
| T13 | Compile the other three legacy projects | A | Open in the IDE and build |

T12/T13 were run with the company's own third-party controls installed **for the test only**, in a
folder outside the package. Those controls are not, and will not be, part of this repository.

## Root causes that were proven, not guessed

### The IDE opened and closed instantly: `MSO97RT` was not registered

Machine A, first attempt: the IDE showed its splash and quit with *"Unexpected error"*, exit code 0,
no exception, no dump. ProcMon on the guest showed every file it needed being found, so it was not a
missing DLL.

The difference against a working machine turned out to be one registry key: VB6 does not just *load*
`MSO97RT.DLL`, it **locates** it through

```
HKLM\SOFTWARE\WOW6432Node\Microsoft\Shared Tools\mso97rt\Path
```

A real VB6 installation writes that key. This package copied the DLL but did not create the key, so
on any machine that never had VB6 the IDE died. Proven with an A/B test on machine A:

| Key present | Result |
|---|---|
| Written by the installer | **IDE opens**, project loads |
| Deleted by hand | **IDE closes** with "Unexpected error" |
| Written again | IDE opens again |

`1-Instalar.bat` now writes it (respecting an existing registration) and `2-Verificar.bat` reports
it as `MSO97RT registrado`.

### The IDE asked for `DAO350.DLL`

The default VB6 project references DAO. `dao350.dll` does **not** export `DllRegisterServer`, so
`regsvr32` is not enough: its type library (version 4.0) has to be registered with
`LoadTypeLibEx(..., REGKIND_REGISTER)` **from a 32-bit process**. `Herramientas\Registrar-Typelib.ps1`
does exactly that, and the installer ships `DAO350.DLL` inside `01_IDE\VB98`.

### "The IDE closes when I load a project" on a machine that already had VB6

Only reproduces on machine C. Two explanations were measured and **rejected**:

| Hypothesis | Experiment | Result |
|---|---|---|
| Component cache pointing at dead folders | Counted the 76 cache entries, before and after | Unchanged: 9 dead paths and 9 pointing at an older portable tree remained |
| Missing `.oca` files next to the OCX | Deleted `MSADODC.oca`, `MSDATGRD.oca`, `TABCTL32.oca`, then loaded a project that uses them | IDE stayed open 12 s; the `.oca` files were not even regenerated |

What did change the behaviour was loading the projects successfully once, which rebuilds the
**per-user IDE state** (`HKCU\Software\Microsoft\Visual Basic\6.0`). That is why it works after
someone has opened a project on the machine, and why it never happens on a clean install.

`6-Reparar IDE.bat` makes that repair deliberate and reversible: it backs up both registry keys to
`%TEMP%` before clearing them, then re-runs the verification.

## Not tested

Say it plainly, so nobody assumes otherwise:

- **Windows 8.1 / 7**: not tested. The package is built for Windows 10/11 x64.
- **32-bit Windows**: not tested. The IDE is 32-bit, but the registry layout this package writes is
  the 64-bit one (`WOW6432Node`).
- **Windows on ARM**: not tested.
- **Hyper-V / VirtualBox**: the VMs were VMware Workstation. Nothing in the package is
  hypervisor-specific, but it was not measured elsewhere.

## How to reproduce the important ones

```bat
:: 1. clean machine, nothing VB6-related installed
1-Instalar.bat            -> must end 8/8 OK
2-Verificar.bat           -> must report the same

:: 2. the IDE really works
4-Abrir VB6.bat           -> New Project -> EXE estándar -> F5 runs

:: 3. the compiler works without the IDE
3-Compilar.bat C:\ruta\Prueba.vbp C:\salida
echo %ERRORLEVEL%         -> 0, and C:\salida\Prueba.exe exists

:: 4. the MSO97RT proof (the interesting one)
2-Verificar.bat           -> note "MSO97RT registrado"
reg delete "HKLM\SOFTWARE\WOW6432Node\Microsoft\Shared Tools\mso97rt" /f
4-Abrir VB6.bat           -> the IDE now shows the splash and exits
1-Instalar.bat            -> 8/8 again, the IDE opens again
```

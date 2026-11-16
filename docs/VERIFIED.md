# Verified behaviour

This page records **what has actually been tested**, so you know what to trust and what to
re-check on your machine.

## Test matrix

| # | Test | How | Result |
|---|---|---|---|
| 1 | Installer runs end to end | `1-Instalar.bat` elevated | ✅ exit 0, **7/7 checks OK** |
| 2 | Registry points at the package itself | read `Path` / `Path32` / `ProductDir` after install | ✅ `...\01_IDE\VB98` |
| 3 | **IDE starts** | launch `VB6.EXE` with a `.vbp` | ✅ designer window: `Prueba - Microsoft Visual Basic [diseño]` |
| 4 | **Project loads** | same as #3 | ✅ forms/menus/properties/toolbox created, no dialogs |
| 5 | **Compile without the IDE** | `VB6.EXE /make proyecto.vbp /out build.log` | ✅ `Prueba.exe`, 16 384 bytes, exit 0 |
| 6 | Runs **without** Administrator (after install) | `/make` from a normal shell | ✅ exit 0 |
| 7 | No third-party artefacts shipped | grep for known control names / `license.dat` | ✅ none |
| 8 | Registry has no foreign absolute paths | scan the generated `.reg` | ✅ 0 |
| 9 | **Works on a virgin Windows 11 VM** | clean install on an untouched VM, no VB6 ever present | ✅ IDE opens + compiles |

### Environments

| OS | Architecture | Status |
|---|---|---|
| Windows 11 (build 26200 / 25H2) | x64 | **verified** — all tests above |
| Windows 11 Enterprise Evaluation (build 26300) | x64 | **verified on a virgin VM** (VMware Workstation, 4 GB, no TPM, fresh install) — installer 8/8, IDE opens, `/make` produces the EXE |
| Windows 10 22H2 (Pro, ISO de consumo) | x64 | **verified on a clean VM** (VMware, fresh install, only the package + sample projects copied) - installer, IDE and compile |
| Windows 10 | x64 | reported working; same mechanism, not part of the automated run |
| Windows 11 24H2 | x64 | historically the build where a *manually assembled* VB6 folder fails; this package was developed against it and the failure was diagnosed on it |
| 32-bit Windows | x86 | not tested — the package targets x64 (all the registry work uses the 32-bit view, which exists on both) |

### Inherited results

The predecessor of this package (same mechanism, plus company-specific controls) was additionally
verified for:

- compiling a real 200 kLOC-style project — `299 008` bytes, byte-identical to the build produced
  on the reference VM;
- relocating the folder and re-running the installer, after which the IDE and compiler still worked.

Relocation for this repository uses the identical `__PKG__` mechanism, so re-testing it is one
command: move the folder, run `1-Instalar.bat`, run `2-Verificar.bat`.

## Not covered

- **F5 debugging against a live database** — depends on your project's connection strings.
- **The Package and Deployment Wizard** (`VB98\Wizards\PDWizard`) — untested; it expects an installer
  layout that does not exist on a modern machine.
- **ADO / Jet / DAO data access** — the libraries are provided by Windows, not by this package.
  Very old providers (`dao350.dll`, `msjet35.dll`) are not shipped by Microsoft anymore.
- **Third-party controls** — by design. Out of scope.

## Reproduce the checks yourself

```powershell
# 1. what is installed and where it points
.\2-Verificar.bat

# 2. the IDE
.\4-Abrir VB6.bat          # then File > Open Project

# 3. compilation, head-less
.\3-Compilar.bat           # drag & drop a .vbp on it, or:
.\Herramientas\Compilar.ps1 -Vbp "C:\path\MyProject.vbp" -Salida "C:\path\out"
```

A minimal project you can use as a smoke test needs only two files — a `.vbp` and a form. Note that
**VB6 requires CRLF line endings** in both; a form written with LF endings fails with
*"Errores de carga ... Form1.frm"*. The easiest safe fixture is the form template that ships with the
package: `01_IDE\VB98\Template\Projects\Form1.frm`.

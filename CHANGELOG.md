# Changelog

All notable changes to this package. Dates are local (America/Guayaquil).

## Changed - double-clicking a `.vbp` now opens the IDE elevated

Opening a project from Explorer went straight to `vb6.exe`, so the IDE ran without privileges and could
not write its **component cache** in `HKLM`. The first time a project pulled in a control that was not
cached yet, VB6 showed *"Error al intentar tener acceso al registro del sistema"* - harmless, but it
looked like a broken install and came back on every new machine.

The association now points at the same launcher as `4-Abrir VB6.bat`:

```
powershell.exe -WindowStyle Hidden -File "<package>\Herramientas\Abrir-VB6.ps1" -Proyecto "%1"
```

`Abrir-VB6.ps1` gained a `-Proyecto` parameter, opens the project in its own folder and exits silently
when the UAC prompt is cancelled (no console flashing, no hanging `Read-Host`).

## Added - mouse wheel scrolling in the IDE

VB6 does not handle `WM_MOUSEWHEEL` in its code panes, so scrolling meant dragging the scrollbar.
The package now ships and registers Microsoft's **`VB6IDEMouseWheelAddin.dll`**
(`01_IDE\Addins\`), which fixes it from inside the IDE - no background helper, no hooks.

`1-Instalar.bat` runs `regsvr32` on it and writes the add-in entry with `LoadBehavior = 1`, so it is
loaded on every IDE start; `9-Desinstalar.bat` unregisters it and removes the entry. The verification
grew to **9 checks** with `Rueda del raton (add-in)`.

Fixed on a real machine where the add-in was registered and still did nothing: the add-in entry already
existed from an older installation with **`LoadBehavior = 0`** (disabled), and the installer only
looked for the ProgID under `HKLM\SOFTWARE\Classes\WOW6432Node` while this DLL registers it in the
**native** `Classes` view. The installer now writes `LoadBehavior = 3` (loaded + load on startup) and
looks in both views.

## Added - `COMCTL32.OCX` (Common Controls 5.0)

A project that references `COMCTL32.OCX` failed on a clean machine: it is **not** `MSCOMCTL.OCX`.
`MSCOMCTL` is Common Controls **6.0**; `COMCTL32` is the **5.0** file VB6 also shipped for older
projects, and it was never in the package. It is now bundled and registered like the rest.

It also turned out to be a **version** problem: the file exists in builds that register typelib **1.3**
(6.00.8022, the media) and **1.5** (6.00.9839, later service packs), and VB6 matches the version
written in the `.vbp`. A project stamped `#1.5#` refuses to load with only 1.3 present, and reports it
as a missing file in the project folder. **Both builds are now bundled and registered**
(`COMCTL32.OCX` + `COMCTL32_v15.OCX`).

The base-controls check was extended to cover all three type libraries, so this class of problem shows
up as a failed check instead of a broken project: `Controles base (6.0 y 5.0)`.

## Fixed - double-clicking a `.vbp` opened a different copy of the IDE

`HKCR\VisualBasic.Project\shell\open\command` still pointed at a previous portable tree, so opening
a project from Explorer launched that copy - with another registry state and another component cache -
while the IDE opened from the shortcut used the installed one. Hence "from the `.vbp` it errors, from
the IDE it works". `1-Instalar.bat` now writes the association to its own `VB6.EXE`, and
`9-Desinstalar.bat` removes it only if it points into its own folder.

## 1.0.1

- **Shortcuts are called `Visual Basic 6.0 Portable`** (desktop and Start menu), which is the name
  people search for, plus a `VB6` alias in the Start menu so `vb6` still finds it.
- **The IDE is now searchable from the Windows search box.** Windows indexes the Start menu and not
  the desktop, so `1-Instalar.bat` creates a Start menu group (`VB6 Anywhere`) with the IDE, the
  package folder and the uninstaller.
- **Fixed:** the uninstaller deleted `VB6 (sandbox).lnk`, a name the installer had stopped using, so
  the desktop shortcut survived an uninstall.
- README (both languages), `docs/SCRIPTS.md` and this file document the shortcuts.
- **`1-Instalar.bat` retira el acceso `Microsoft Visual Basic 6.0`** que dejaron pruebas
  anteriores si apunta a una copia portable y no a una instalacion real de VB6. Ese acceso ganaba
  como *mejor coincidencia* en la busqueda de Windows, porque el nombre del `.lnk` manda sobre el
  nuestro, y por eso al buscar `visual basic` aparecia sin la palabra *Portable*.

Everything from 1.0.0 is included: `MSO97RT` registration (the silent-exit fix), DAO 3.51, the 19
Microsoft controls, `6-Reparar IDE.bat` and `docs/TESTING.md`.

## Changed - the shortcut is called `Visual Basic 6.0 Portable`

The desktop and Start menu entries are now `Visual Basic 6.0 Portable` instead of `Visual Basic 6`,
which is the name people search for. Because Windows matches the visible name, an entry called only
"Visual Basic 6.0 Portable" would not answer to `vb6`, so the Start menu group also carries a `VB6`
alias pointing at the same executable. Both open the IDE with the administrator flag.

`1-Instalar.bat` removes the previous names (`Visual Basic 6.lnk` and, in the enterprise package,
`VB6 (sandbox).lnk`) so an upgrade does not leave duplicate icons.

## Added - the IDE is searchable from the Windows search box

`1-Instalar.bat` now creates a **Start menu group** (`VB6 Anywhere`) with three entries: the IDE, the
package folder and the uninstaller. Windows search indexes the Start menu and **not** the desktop, so
until now typing `vb6` found nothing. The group is created per user, needs no elevation, and
`9-Desinstalar.bat` removes it.

Fixed while doing it: the uninstaller was deleting `VB6 (sandbox).lnk`, a name the installer stopped
using, so the desktop shortcut survived an uninstall.

## Docs - wording: it is VB6 that is not installed

The tagline said "no installation", which contradicted a script called `1-Instalar.bat`. What is not
installed is **VB6**: the package only registers the runtime, the registry keys and the controls, and
both READMEs now say so and explain the script name.

## Docs - bilingual README, TESTING and LICENSE

- **`README.md` is now Spanish** (the default view) and **`README.en.md` keeps the English one**,
  with a switcher at the top of both.
- New **`docs/TESTING.md`**: every test actually executed, with the machine it ran on, the state it was
  in beforehand, the experiment and the result - including the two hypotheses that were measured and
  rejected (component-cache paths and missing `.oca` files).
- New **`LICENSE`** (MIT) covering the scripts, tooling and docs. It explicitly does **not** cover the
  Microsoft binaries the repository repackages; that stays in `NOTICE.md`.
- `LEEME.txt` was removed: a Spanish README replaces it and cannot drift out of sync.
- `NOTICE.md` updated: the ActiveX control list is no longer "three", and the DAO 3.51 and
  `Shared Tools\mso97rt` steps are documented.

## Added - `6-Reparar IDE.bat`

A machine that already had VB6 can make the IDE close about two seconds after loading a project. The
cause is inherited state, not the package: the per-user settings under `HKCU\...\Visual Basic\6.0`
and a component cache whose entries point at folders that no longer exist (or at an older portable
tree). The new repair script backs up both registry keys to `%TEMP%`, clears them, and re-runs the
verification. Two other hypotheses were measured and discarded first: missing `.oca` files next to the
OCX (deleting them changes nothing) and a bad `Shared Tools` registration (that is the different
"IDE never opens" case).

## [1.0.0] — 2026-11-14

First public release.

### Added

- **Portable VB6 IDE** (6.00.9782 / SP6) that starts without installing Visual Basic 6 and without a
  virtual machine: form designer, toolbox, project explorer, object browser and debugger.
- **Head-less compiler** (`Herramientas/Compilar.ps1`, `3-Compilar.bat`) that copies the project to a
  temp folder, injects `Path32`, runs `VB6.EXE /make` and reports the resulting EXE.
- **Installer** (`1-Instalar.bat`) that copies the shared VBA runtime, imports a relocatable registry
  snapshot, writes the edition mark and `.oca` caches, imports design-time licences for the bundled
  controls, registers them and verifies everything (7 checks).
- **Verifier** (`2-Verificar.bat`) that changes nothing and reports OK/FAIL with the paths in use.
- **Uninstaller** (`9-Desinstalar.bat`) that reverses all of it, and removes the shared VBA runtime
  only when it is byte-identical to what was installed.
- `__PKG__` placeholder in the registry snapshot: every path is resolved at install time, so the
  package works from any folder.
- Bundled controls: `MSCOMCTL.OCX`, `MSCOMCT2.OCX`, `THREED32.OCX`.
- Documentation: [README](README.md), [architecture](docs/ARCHITECTURE.md),
  [how it was made](docs/HOW-IT-WAS-MADE.md), [scripts](docs/SCRIPTS.md),
  [troubleshooting](docs/TROUBLESHOOTING.md), [FAQ](docs/FAQ.md), [verified](docs/VERIFIED.md).

### Fixed while packaging

- **The IDE exited silently right after the splash screen.** Root cause: the shared VBA runtime was
  missing from `%CommonProgramFiles%\Microsoft Shared\VBA`. Diagnosed with a process dump, a Process
  Monitor trace and decompilation — documented in [docs/HOW-IT-WAS-MADE.md](docs/HOW-IT-WAS-MADE.md).
- **The IDE closed silently on a clean machine even with every file present.** VB6 does not just load
  `MSO97RT.DLL`, it *locates* it through `HKLM\SOFTWARE\WOW6432Node\Microsoft\Shared Tools\mso97rt\Path`.
  A real VB6 installation writes that key; this package did not, so on any machine that never had VB6
  the IDE showed its splash and quit with *"Unexpected error"*. The installer now registers it
  (respecting an existing registration) and `2-Verificar.bat` reports it as `MSO97RT registrado`.
  Found and proven with an A/B test on a virgin Windows 11 VM: with the key the IDE opens, without it
  it does not.
- **The IDE stopped on a clean machine asking for DAO350.DLL.** The default VB6 project references
  DAO 3.51 (type-library version 4.0) and the IDE loads it while starting. The package now ships
  `DAO350.DLL` next to `VB6.EXE` and registers it when the machine has no working DAO of its own,
  using `LoadTypeLibEx` from a 32-bit process (the DLL has no `DllRegisterServer`, and that is the
  registry view VB6 reads).
- Mixed service-pack binaries (`VB6.EXE` from one build, `VB6IDE.DLL` from another) — normalised to a
  single SP6 set.
- Installer aborted when the IDE held the VBA DLLs mapped (`ERROR_USER_MAPPED_FILE`). It now compares
  hashes, skips identical files and never fails on a locked one.
- The portable package used to adopt any VB6 found in the registry, configuring *that* folder instead
  of its own. It now always uses its own copy.

### Not included (by design)

Third-party controls and their licences, `license.dat` files, sample projects, databases, company
configuration and the VB6 installation media. See [NOTICE.md](NOTICE.md).

### Design notes

- **The package is intentionally complete.** `01_IDE\Common` ships the full Visual Studio 6 shared
  tree (including `MSDev98` and `Tools`, ~60 MB that a bare compile does not need) because the goal
  is *plug and play*: double-click a `.bat` and it works, with no missing-component hunting and with
  parity against a real VB6 installation. Slim variants belong in forks.
- **Two ways to build, one compiler.** The IDE is the tool for developing and debugging (F5,
  breakpoints, watch, *File ▸ Make Project.exe*). `3-Compilar.bat` is the headless path for CI
  pipelines, AI agents or a quick rebuild — deterministic exit codes, no GUI.
- Third-party licence dialogs after the fix: see
  [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md). No third-party licence file is shipped.

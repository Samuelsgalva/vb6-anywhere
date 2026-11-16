# FAQ

### Is this legal?

VB6 is a discontinued Microsoft product (support ended 2008). This repository only *repackages*
files from an existing installation so they run portably. It grants no licence: **you must own a
valid VB6 licence**. It ships no third-party controls, no third-party licence keys and no company
data. Details in [`../NOTICE.md`](../NOTICE.md).

### Why not just install VB6 the normal way?

Because the original installer is a 1998 application: `acmboot.exe` is a **16-bit** bootstrapper and
modern 64-bit Windows refuses to run it. With several workarounds (`acmsetup.exe` instead, patched
media) an install is possible, but it then lives in `Program Files`, depends on a machine-wide state
and cannot be moved. This package sidesteps the installer completely.

### Does it need internet access?

No. Everything is local.

### Why does it need Administrator rights?

VB6 writes to `HKLM` when it starts (window state, type-library cache bookkeeping) and when it
compiles. The install step writes the registry keys and registers the controls. Your own account
with a UAC confirmation is enough; the built-in `Administrator` account is not required.

### Can I have two copies of this package at once?

Not meaningfully. Both would write the **same** registry keys, so the last one installed wins and
the other would start using the wrong folders. Pick one location.

### Can I move the folder? Can I run it from a USB stick?

Yes — but the registry stores absolute paths. After moving (or if the drive letter changes), run
`1-Instalar.bat` again from the new location. Copying to another *machine* requires running
`1-Instalar.bat` there.

### Does it work on 32-bit Windows?

It was built and tested on 64-bit Windows 10/11. On a 32-bit OS the registry layout is different
(no `WOW6432Node`) and the `Common Files` handling changes; the scripts assume the 64-bit layout.

### Can I use my own third-party controls?

Yes. Install your licensed copy normally (they register themselves), then run `1-Instalar.bat`
again so the VB6 registry is coherent. Some very old controls do not use the registry for
design-time licensing but a file such as `C:\Windows\license.dat`; that file is yours to provide
and is deliberately not distributed here.

### Which VB6 version is inside?

`6.00.9782` — that is Visual Basic 6.0 with **Service Pack 6**, plus the SP6 cumulative update. All
three core binaries (`VB6.EXE`, `VB6IDE.DLL`, `VBA6.DLL`) come from the same build on purpose;
mixing builds makes the IDE exit silently.

### Can I debug, run and build from the IDE?

Yes — all of it. This is the real IDE, not a wrapper: breakpoints (F9), run (F5), step into / step
over, Immediate window, Watch, Call Stack, and *File ▸ Make Project.exe* for the final EXE.
Debugging **against your database** works as long as your project's connection strings resolve on
this machine — that is your project's business, not the package's.

### Why is the package ~126 MB? Can I trim it?

It is deliberately complete. `01_IDE\Common` is the full Visual Studio 6 shared tree (`IDE98`,
`MSDev98`, `Tools`, `Graphics`) as it existed on the reference machine. Trimming ~60 MB out of it is
possible, but it turns a *plug and play* package into a "which DLL was in the folder I deleted?"
exercise — and the wizards and component tools do reach into that tree. The whole point here is
double-click-and-go. See
[Why keep the whole VS6 tree?](../README.md#why-keep-the-whole-vs6-tree).

If you need a slim deployment, fork it and test the exact features you use; do not do it in place.

### Why are there Visual C++ 6 files in a VB6 package?

Because they live in the same shared tree (`Common\MSDev98`). They cost ~26 MB and guarantee that
nothing the IDE expects to find under `Common` is missing.

### Can I use it in CI, or from an AI agent?

That is exactly what the headless build is for:

```powershell
Herramientas\Compilar.ps1 -Vbp "C:\path\MyProject.vbp" -Salida "C:\path\out"
# exit 0 -> C:\path\out\MyProject.exe
# exit 2 -> compilation failed; the failing build.log lines are printed
```

No GUI, no window focus, deterministic exit codes — safe to automate from a pipeline or an agent,
and the project is copied to `%TEMP%` so your source tree is never modified. Install once (elevated)
on the machine or runner first.

Caveat: VB6 itself is a GUI application, its registry state is machine-wide, and Microsoft does not
support it. Treat any pipeline built on it as fragile.

### Why are the scripts' messages in Spanish?

They were written by Spanish-speaking developers for their own team. The documentation is in
English so the package can be understood (and fixed) by anyone. Messages are short and mostly
identifiers (`OK`, `FALLA`, `AVISO`); translating them is a welcome pull request.

### Windows Defender / SmartScreen complains

Expected: the binaries are unsigned 1998-era executables. Both are also a classic false-positive
target of heuristic scanners. If your policy blocks them, add an exclusion for the package folder.
Never disable your antivirus to make this work.

### Does it work on Windows 11 24H2 / 25H2?

Yes — verified on Windows 11 build 26200. That build is precisely where a *hand-assembled* VB6
folder is known to fail, which is what motivated this work: see
[`HOW-IT-WAS-MADE.md`](HOW-IT-WAS-MADE.md).

### Where does the IDE keep its own settings?

`HKCU\Software\Microsoft\Visual Basic\6.0` — window layout, toolbox tabs, recent projects. Delete
that key to reset the IDE to defaults; the package does not need it.

### I found a bug / something does not work on my machine

Open an issue with the output of `2-Verificar.bat` and your Windows build. See
[`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) for what to collect.

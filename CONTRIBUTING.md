# Contributing

This repository exists to keep legacy VB6 code maintainable on modern Windows. Small, verifiable
changes are welcome — especially around *other* Windows builds.

## Ground rules

- **Do not add third-party controls, licence keys, `license.dat` files, projects or customer data.**
  See [NOTICE.md](NOTICE.md). Pull requests containing them will be rejected.
- **Do not "modernise" the VB6 files.** They are shipped byte-for-byte as they came out of a
  working installation; changing them breaks the build-consistency requirement.
- Keep the comments in the scripts as they are (Spanish). Documentation is in English.
- Preserve **CRLF** in `.bat`, `.ps1`, `.frm`, `.vbp`, `.bas`, `.cls`. The
  [`.gitattributes`](.gitattributes) enforces this; do not remove it.
- **Do not trim the package "to save space".** `01_IDE\Common` is kept complete on purpose: this
  package is meant to be *plug and play*, and deleting folders like `MSDev98` or `Tools` trades
  ~60 MB for exactly the class of "silently missing component" bug this project exists to eliminate.
  See [Why keep the whole VS6 tree?](README.md#why-keep-the-whole-vs6-tree). Slim variants are fine
  as a fork, never as a change here.

## Before opening a pull request

Run the two checks below and paste the result in the PR description.

```powershell
# 1. syntax of every script
Get-ChildItem -Recurse -Include *.ps1 |
  ForEach-Object {
    $e = $null; $t = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$t, [ref]$e)
    "{0,-20} {1}" -f $_.Name, ($(if ($e.Count) { "FAIL: " + $e[0].Message } else { "OK" }))
  }

# 2. the package still installs and verifies
.\1-Instalar.bat          # once, elevated
.\2-Verificar.bat         # expect 7/7 OK
```

If you touched the compiler wrapper, also compile something:

```powershell
.\Herramientas\Compilar.ps1 -Vbp "C:\path\Any.vbp" -Salida "C:\path\out"
```

## Reporting a problem

Include:

1. `diagnostico.txt` from `5-Diagnostico.bat` (read-only; system, language, VBA runtime, registry).
2. `2-Verificar.bat` output (it names the failing check and the path it used).
2. Windows edition, version and build (`winver`).
3. The exact message, and whether it appears *before* or *after* the splash screen.
4. If the IDE exits silently: `01_IDE\VB98\VB6.EXE` / `VB6IDE.DLL` file versions.

Use the issue template if it is available.

## What would help most

| Area | Why it matters |
|---|---|
| Testing on **Windows 10** and **Windows 11 23H2/24H2** | the matrix in [docs/VERIFIED.md](docs/VERIFIED.md) has gaps |
| Testing on a **32-bit** Windows VM | the scripts assume the 64-bit registry layout |
| Translating the script messages to English | keeps the package usable outside Spanish-speaking teams |
| Verifying the **Package and Deployment Wizard** | untested, probably broken on modern Windows |
| Testing the headless build in a **real CI runner** | confirms the exit-code contract for pipelines and agents |

# Legal notice

## What this repository is

A **repackaging** of files from an existing installation of Microsoft Visual Basic 6.0
(version 6.00.9782, Service Pack 6) so that the IDE and the compiler can run from a folder on
64-bit Windows 10/11, without an installation and without a virtual machine.

## Rights

- **Visual Basic 6.0 is the property of Microsoft Corporation** and is discontinued — support
  ended on 8 April 2008.
- This repository **grants no license** for VB6. To use it you must already hold a **valid Visual
  Basic 6.0 license**. If you do not, do not use it.
- The files are provided for the sole purpose of preserving and maintaining legacy software that
  is already licensed to you. If you are a rights holder and want content removed, open an issue
  and it will be taken down.

## What is NOT included

- **No third-party controls** (FarPoint Spread, Crystal Reports, vendor-specific ActiveX
  components) and **no third-party license keys** or `license.dat` files.
- **No project files, databases, connection strings, credentials or configuration** belonging to
  any company.
- **No VB6 installation media.**
- The `HKCR\Licenses` entries that get imported belong to the **controls Microsoft ships with
  VB6** (`MSCOMCTL`, `MSCOMCT2`, `THREED32`, `MSADODC`, `MSDATGRD`, `TABCTL32`, `COMDLG32`,
  `MSMASK32`, `MSFLXGRD`, `MSHFLXGD`, `MSCHRT20`, `MSCOMM32`, `MSINET`, `MSWINSCK`, `MCI32`,
  `RICHTX32`, `MSRDO20`, `MSSTDFMT`, `MSBIND`). They are the same entries any VB6 Professional
  installation writes for its own bundled controls.

## What it does to the machine

The installer writes registry keys under
`HKLM\SOFTWARE\WOW6432Node\Microsoft\Visual Basic\6.0` and `...\VisualStudio\6.0`, registers three
ActiveX controls, copies the shared VBA runtime into `%CommonProgramFiles%\Microsoft Shared\VBA`,
registers the DAO 3.51 type library (`DAO350.DLL` ships in `01_IDE\VB98`), writes
`Shared Tools\mso97rt` (where the IDE *locates* `MSO97RT.DLL`) and creates a desktop shortcut.
`9-Desinstalar.bat` reverses all of it, including the desktop
shortcut and the VBA runtime directory it created (it does not touch a pre-existing one).

## Trademarks

Microsoft, Visual Basic, Visual Studio and Windows are trademarks of Microsoft Corporation.
This project is **not affiliated with, sponsored or endorsed by** Microsoft.

---

## Español

Este repositorio es un **reempaquetado** de archivos de una instalación existente de Microsoft
Visual Basic 6.0 para que el IDE y el compilador se ejecuten desde una carpeta en Windows 10/11 de
64 bits, sin instalación y sin máquina virtual.

- **VB6 es propiedad de Microsoft** y está descatalogado (fin de soporte: 8 de abril de 2008).
  Este repositorio **no concede ninguna licencia**: para usarlo necesitas disponer de una licencia
  válida de Visual Basic 6.0.
- **No se incluye**: controles de terceros (FarPoint Spread, Crystal Reports, controles locales),
  ni sus claves de licencia, ni ficheros `license.dat`; tampoco proyectos, bases de datos,
  credenciales ni configuración de ninguna empresa; ni el instalador de VB6.
- Las claves `HKCR\Licenses` importadas corresponden a los **controles que Microsoft incluye con
  VB6** (`MSCOMCTL`, `MSCOMCT2`, `THREED32`, `MSADODC`, `MSDATGRD`, `TABCTL32`, `COMDLG32`,
  `MSMASK32`, `MSFLXGRD`, `MSHFLXGD`, `MSCHRT20`, `MSCOMM32`, `MSINET`, `MSWINSCK`, `MCI32`,
  `RICHTX32`, `MSRDO20`, `MSSTDFMT`, `MSBIND`), las mismas que escribe cualquier instalación de
  VB6 Professional. Se añaden las de `DAO 3.51` y `Shared Tools\mso97rt`, igual que hace el
  instalador original de VB6.
- Si eres titular de derechos y quieres que se retire algún contenido, abre un *issue* y se elimina.

No está afiliado ni respaldado por Microsoft.

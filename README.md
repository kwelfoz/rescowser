# RESCOWSER

**A lightweight-minded portable browser package for Windows 10 and Windows 11.**

Rescowser packages the official Mozilla Firefox ESR builds with a USB-local profile, a small set of conservative preferences, and a custom start page. It is an independent packaging/launcher project — not a new browser engine, a Firefox fork, or a Mozilla product.

> **Status: 0.1 preview.** The source and packaging workflow are ready for testing. A successful GitHub Actions build and real Windows launch tests are required before calling any ZIP a working release.

## Goals

- Windows 10 and Windows 11.
- Both x86 and x64 builds in one package; launcher selects the native OS architecture.
- Browser application files, profile, and downloads stay together in the Rescowser folder.
- No Firefox installation on the target PC: the build process extracts the official Mozilla MSI payload.
- Modern HTTPS support through a current Firefox ESR engine.
- Conservative footprint settings without disabling browser security protections.

## Browser base

The initial build pins **Firefox ESR 153.7.0** and uses the **Portuguese (Portugal)** locale by default. The build workflow allows the version and locale to be changed. Always use a current Mozilla security release before distributing the package.

Mozilla's release notes list ESR 153.7.0 as released on 10 November 2026. Mozilla's download page provides Windows 64-bit and 32-bit MSI packages. See:

- [Firefox ESR 153.7.0 release notes](https://www.firefox.com/en-US/firefox/153.7.0/releasenotes/)
- [Mozilla: Deploy Firefox with MSI installers](https://support.mozilla.org/en-US/kb/deploy-firefox-msi-installers)

## Build on Windows 10/11

Requirements:

- Windows 10 or Windows 11.
- Windows PowerShell 5.1 or PowerShell 7.
- Internet access to Mozilla's official release server.

From the repository root, run:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\Scripts\Build-Rescowser.ps1
```

To specify a release and locale:

```powershell
.\Scripts\Build-Rescowser.ps1 -FirefoxVersion '153.7.0esr' -Locale 'pt-PT'
```

The script downloads the official x86 and x64 Mozilla MSI packages, verifies their Authenticode signatures and signer, and uses Mozilla's documented `EXTRACT_DIR` option to extract the browser files without installing Firefox on the build machine. It then creates `dist\Rescowser-Portable.zip`.

The same build can be run from **GitHub → Actions → Build Rescowser portable package → Run workflow**. The generated ZIP is uploaded as a workflow artifact.

## Use from a USB drive

1. Download `Rescowser-Portable.zip` from a successful workflow run.
2. Extract it to a folder on the USB drive.
3. Keep the folder structure intact.
4. Run `Rescowser.cmd`.
5. The launcher selects x64 on 64-bit Windows and x86 on 32-bit Windows.

The Firefox profile is created in `Data\Profiles` and downloads go to `Data\Downloads`. The launcher updates the download path at startup so it follows the USB drive letter.

**Portability note:** the profile and downloads are kept on the USB drive, but Windows, Firefox, crash reporting, DNS, networking, and the operating system may still create temporary data outside that folder. Do not save customer passwords or sensitive customer data in a shared technician profile. Use a dedicated profile for each client or clear it after use.

## Footprint and safety

- Disk cache is capped at 64 MiB.
- Session history is limited to 10 entries.
- Sponsored New Tab content and selected optional integrations are disabled.
- No sandbox, site isolation, certificate validation, HTTPS protections, or security updates are disabled.
- Memory use depends on the hardware, websites, extensions, and number of tabs. Rescowser does not promise a fixed RAM footprint.
- USB 2.0 flash storage can make startup and profile access slower than an internal SSD.

## Current limitations

- Version 0.1 uses the standard Firefox interface plus a Rescowser start page; a fully custom browser chrome is not part of this first preview.
- Some websites may behave differently from Chromium-based browsers, and no browser can guarantee compatibility with every website.
- The x86 package is intended for 32-bit Windows 10. The x64 package is selected on 64-bit Windows.
- Updates are not yet automatic. Rebuild the package with a current supported Firefox ESR release before regular use.

## Licensing and trademarks

The Rescowser launcher, scripts, and configuration are licensed under MIT. Firefox binaries are Mozilla software and remain subject to Mozilla's licensing and trademark terms. Rescowser is independent and is not affiliated with or endorsed by Mozilla. See [NOTICE.md](NOTICE.md).

# Secure UTM Sandbox on macOS

This guide turns UTM into a practical containment workflow for unsafe browsing,
unknown downloads, suspicious documents, and client apps you do not trust enough
to install on the main Mac.

## Recommended default

Use **one encrypted external SSD** as the unsafe-work container. Put all UTM VM
bundles, raw downloads, quarantined files, logs, and sanitized outputs on that
SSD. Do **not** let unsafe sites or raw files touch the Mac's normal Downloads,
Desktop, Documents, iCloud Drive, or Time Machine-backed storage.

```text
Main Mac
  ├─ normal work only; no unsafe browsing or raw hostile files
  ├─ Time Machine backs up normal data only
  └─ external encrypted volume: /Volumes/UnsafeLab
       ├─ VMs/
       │   ├─ Dirty-Linux-Browser.utm
       │   ├─ Windows-App-Test.utm
       │   └─ macOS-App-Test.utm, only if genuinely needed
       ├─ Raw-Quarantine/
       ├─ Sanitized-Outbox/
       ├─ Client-App-Tests/
       └─ Logs/
```

The key rule is simple: **raw unsafe content lives only in the VM or encrypted
external quarantine; the main Mac only sees sanitized outputs.**

## Security model: green / amber / red

### Green: main Mac

The host stays boring and clean.

- Keep macOS and apps updated.
- Keep FileVault enabled.
- Keep the macOS firewall enabled unless you have a specific reason not to.
- Avoid unsafe browsing on the host.
- Do not install unknown desktop clients on the host just because a site asks.
- Consider Apple Lockdown Mode only for high-risk targeted-attack threat models;
  it can break or slow normal browsing and messaging features.

### Amber: encrypted external storage

Use a dedicated external SSD, not the Time Machine disk. Format it manually in
Disk Utility:

1. Open **Disk Utility**.
2. Choose **View -> Show All Devices**.
3. Select the external physical drive.
4. Click **Erase**.
5. Name it `UnsafeLab`.
6. Scheme: **GUID Partition Map**.
7. Format: **APFS (Encrypted)**.
8. Use a long unique passphrase.
9. If your threat model includes host credential-stealing malware, do not store
   the volume password in Keychain; unlock it manually before unsafe work.

After the volume is mounted, prepare folders and host exclusions with the helper
script:

```bash
# After chezmoi apply renders scripts into ~/scripts:
~/scripts/setup-utm-sandbox-macos.sh --install --volume /Volumes/UnsafeLab

# From the chezmoi source checkout before apply, use bash explicitly:
bash ~/.local/share/chezmoi/scripts/executable_setup-utm-sandbox-macos.sh --install --volume /Volumes/UnsafeLab
```

The helper is intentionally non-destructive: it will not format, partition, or
erase disks. It verifies the mounted volume, creates the `UnsafeLab` folder tree,
sets owner-only `700` permissions on those lab folders, adds a Time Machine
exclusion, disables Spotlight indexing where macOS permits, places a
`.metadata_never_index` marker, and writes a local checklist plus a session-log
template under `Logs/`.

Manual verification commands:

```bash
tmutil isexcluded /Volumes/UnsafeLab
mdutil -s /Volumes/UnsafeLab
ls -la /Volumes/UnsafeLab
```

Also verify in System Settings:

- **General -> Time Machine -> Options** excludes `/Volumes/UnsafeLab`.
- **Spotlight -> Search Privacy** excludes `/Volumes/UnsafeLab` or at least
  `/Volumes/UnsafeLab/Raw-Quarantine`.

### Red: disposable unsafe VM

The dirty VM has internet access but no deliberate bridges to personal data.
Default stance:

- No host home-folder share.
- No Mac Desktop, Documents, normal Downloads, Library, iCloud Drive, or Time
  Machine volume shared into the guest.
- Clipboard sharing off.
- Shared directories off by default.
- Drag-and-drop not used as a transfer path.
- USB auto-connect off or prompt-only; do not forward personal USB devices.
- No iCloud, browser sync, password-manager sync, personal accounts, or normal
  SSH/Git credentials inside the dirty VM.

For high-risk files, add a second **no-internet transfer/sanitization VM**. The
dirty VM writes to an intermediate disk; the transfer VM sanitizes and is the
only VM allowed to access `Sanitized-Outbox`.

## Install UTM

Recommended default: install UTM from the **Mac App Store** if you value automatic
updates. The free Homebrew cask/GitHub build is useful when you want a fully CLI
install path.

Simple helper usage:

```bash
# Recommended: open/install the App Store build and prepare the mounted volume.
~/scripts/setup-utm-sandbox-macos.sh --install --volume /Volumes/UnsafeLab

# CLI/free fallback: install the Homebrew cask instead.
~/scripts/setup-utm-sandbox-macos.sh --install --install-method brew --volume /Volumes/UnsafeLab

# Later audit without changing anything.
~/scripts/setup-utm-sandbox-macos.sh --verify --volume /Volumes/UnsafeLab
```

If `mas` is installed and you are signed into the App Store, the helper attempts
`mas install 1538878817`. Otherwise it opens the UTM App Store deep link and can
fall back to the UTM web listing so you can install it manually.

## VM choice

| Use case | Best VM | Notes |
| --- | --- | --- |
| Unsafe browsing, unknown PDFs, random downloads | **Linux VM** | Best default: fast, easy to reset, little reason to sign into real accounts, good scanning and PDF tooling. |
| Required Windows desktop client | **Windows VM** | Use only for that client. Do not make it your general unsafe browser unless the site requires Windows. |
| Required Mac desktop client | **macOS VM on Apple Silicon** | Use only when the app truly requires macOS and works in a VM. Avoid installing unknown Mac apps on the host. |
| Very high-risk malware detonation | **Separate sacrificial hardware** | A VM reduces risk but is not a perfect containment boundary. |

On Apple Silicon, prefer ARM64 Linux and Windows ARM64. On Intel Macs, prefer
x86_64 Linux or x86_64 Windows. Matching the host architecture avoids slow
cross-architecture emulation.

## Dirty Linux VM settings

Create the dirty VM with UTM and store the `.utm` bundle under:

```text
/Volumes/UnsafeLab/VMs/
```

Keep a clean template VM with OS updates and tools installed, then duplicate that
template for risky work. Prefer Disposable Mode for browsing sessions; otherwise
revert to a clean snapshot or delete the throwaway duplicate when finished.

Recommended starting point:

- **Architecture:** same as the Mac, ARM64 on Apple Silicon or x86_64 on Intel.
- **Backend:** QEMU when you want UTM **Disposable Mode** / **Run without saving
  changes**.
- **CPU/RAM:** 2-4 CPU cores and 4-8 GB RAM for Linux.
- **Disk:** 40-80 GB minimum, stored on `/Volumes/UnsafeLab/VMs/`.
- **Network:** Shared Network with **Isolate Guest from Host** enabled, or
  **Emulated VLAN**. Use **Host Only** for offline document processing.
- **Avoid:** Bridged networking unless a required client must appear on the
  physical LAN.
- **Port forwarding:** none.
- **Guest services:** do not expose services to the LAN.
- **Sharing:** clipboard off, shared directory off by default, drag-and-drop not
  a security boundary, USB auto-connect off/prompt-only.

When you need a shared folder, share only:

```text
/Volumes/UnsafeLab/Sanitized-Outbox
```

Never share:

```text
normal Downloads
Desktop
Documents
Library
iCloud Drive
Time Machine disks
SSH keys or password-manager vaults
```

If the VM may display malicious or sensitive content, disable automatic VM
screenshots in UTM preferences and keep drive-image locking enabled.

## Windows VM settings

For Windows 11 test VMs:

- Enable UEFI.
- Enable TPM 2.0.
- Enable Secure Boot / preload secure boot keys.
- Keep Microsoft Defender active.
- Use 4+ cores and 8+ GB RAM if the host has enough memory.
- Do not sign into a real Microsoft account unless absolutely required.
- Do not sync OneDrive.
- Do not share Mac folders.
- Scan suspicious files with **Microsoft Defender -> Scan with Microsoft
  Defender** inside the VM.

Treat the Windows VM as a client-test appliance, not a trusted desktop.

## macOS VM settings

Use a macOS VM only on Apple Silicon and only when a required app truly needs
macOS. In the guest:

- Do not sign into iCloud.
- Do not enable iCloud Drive.
- Do not use the real password manager.
- Deny Full Disk Access, Accessibility, Input Monitoring, Screen Recording,
  Contacts, and similar privacy permissions unless the app cannot function
  without them.

If a Mac client requires kernel/system extensions, device drivers, MDM
enrollment, unusual entitlements, or hardware access that does not work in a VM,
the safer answer is a separate sacrificial Mac, not the main Mac.

## Browser profile inside the VM

Use a dedicated browser inside the VM. Incognito/private mode is not a safety
boundary.

### Firefox

- Create a profile named `Unsafe`.
- Do not sign into Firefox Sync.
- Do not save passwords.
- Do not install normal personal extensions.
- Set Enhanced Tracking Protection to **Strict**.
- Keep dangerous/deceptive content, dangerous download, and unwanted/uncommon
  software warnings enabled.
- Set downloads to **Always ask where to save files**.
- Save raw downloads inside the VM, for example `~/Downloads/raw`.
- Deny or prompt for camera, microphone, location, notifications, autoplay, and
  VR/XR.

### Chrome / Chromium

- Use a dedicated profile.
- Do not sign into Google Sync.
- Do not save passwords.
- Consider Enhanced Safe Browsing only if you accept the extra telemetry tradeoff.
- Run Safety Check regularly.
- Enable **Ask where to save each file before downloading**.
- Deny notifications, location, camera, microphone, USB, WebHID, and WebSerial
  unless the test requires them.
- Treat dangerous-download warnings as meaningful.

## File workflow

### Normal PDF/document workflow

Inside the dirty Linux VM:

```bash
mkdir -p ~/Downloads/raw ~/work/pages
cd ~/Downloads/raw
# Download with the VM browser, not the host browser.
sha256sum *
```

For each risky session, keep notes on the encrypted volume under `Logs/` or in
the VM until sanitized. Record the source URL, retrieval time, file names,
SHA-256 hashes, scanner results, and sanitizer used. Do not paste secrets or
client-confidential content into ordinary host notes.

Install scanning and PDF tools in the VM. The repo includes a Linux guest helper
for a clean Debian/Ubuntu VM template:

Copy `~/scripts/utm-sandbox-linux-guest-setup.sh` into the clean VM template
before unsafe browsing, or fetch the tracked script from the public repo inside
the VM and review it first. Then run:

```bash
# In the Linux VM template, not on the Mac host:
bash utm-sandbox-linux-guest-setup.sh --inside-unsafe-vm
```

If you prefer to run the commands manually:

```bash
sudo apt update
sudo apt install clamav clamav-freshclam poppler-utils img2pdf ocrmypdf imagemagick qpdf p7zip-full unzip file libimage-exiftool-perl
sudo freshclam
clamscan -r --infected ~/Downloads/raw
```

The guest helper requires the explicit `--inside-unsafe-vm` acknowledgement,
refuses macOS, creates `~/Downloads/raw`, `~/work/sanitized`, and `~/work/logs`,
installs the package set above with `apt-get`, and writes small local VM helpers
for PDF flattening and image metadata stripping. It does not configure UTM host
sharing, clipboard, networking, USB, or any Mac host setting.

Do not open raw PDFs on the host in Preview, Quick Look, Acrobat, or a browser
tab. View raw PDFs only inside the VM. If you install Acrobat Reader inside a VM,
disable Acrobat JavaScript in preferences.

Flatten a suspicious PDF you need to keep:

```bash
mkdir -p ~/work/pages
pdftoppm -r 200 -png ~/Downloads/raw/suspect.pdf ~/work/pages/page
img2pdf $(ls -v ~/work/pages/page-*.png) -o ~/work/suspect-sanitized.pdf
ocrmypdf --force-ocr ~/work/suspect-sanitized.pdf ~/work/suspect-sanitized-ocr.pdf
```

Rasterizing and rebuilding removes active PDF features such as JavaScript, forms,
embedded files, and links. It does not prove the document is truthful, and OCR or
PDF tooling is not itself a malware-protection boundary.

Dangerzone is a GUI alternative for PDFs, Office documents, and images. Prefer
running Dangerzone inside the VM or in a dedicated sanitization VM, and remember
that residual exploit risk remains.

### VirusTotal rule

- For non-confidential files, check a hash before uploading the file.
- For confidential, client, legal, medical, personal, proprietary, or identity
  documents, **do not upload the file to public VirusTotal**.
- Use local scanning, private scanning, or the client's internal process for
  sensitive files.

### Office documents

For `.doc`, `.docx`, `.xls`, `.xlsx`, `.ppt`, and `.pptx`:

1. Open only inside the VM.
2. Do not enable macros.
3. Convert to PDF inside the VM.
4. Flatten the PDF using the rasterize-and-rebuild workflow.
5. Transfer only the sanitized PDF, not the original Office document.

### Images

Re-encode and strip metadata inside the VM:

```bash
magick input.jpg -strip safe.png
```

Image rewriting is risk reduction, not proof of safety.

### Archives

For `.zip`, `.7z`, `.rar`, `.tar`, and similar archives:

1. Extract only inside the VM.
2. Scan extracted contents.
3. Do not execute anything.
4. Prefer transferring sanitized PDFs/images/text outputs instead of archives.

## Transfer patterns

### Practical pattern

1. Dirty VM has internet.
2. Host shared folders stay off during browsing.
3. Record hashes and source URL in the encrypted `Logs/` session note if doing so
   is appropriate for the matter.
4. After sanitization, temporarily share only
   `/Volumes/UnsafeLab/Sanitized-Outbox` if needed.
5. Copy only sanitized files there.
6. Shut down the VM.
7. On the Mac, inspect only the sanitized file.
8. Copy it into normal Documents only after deciding it is worth keeping.

### Higher-assurance pattern

1. Dirty VM has internet and no host shared folder.
2. Dirty VM writes output to a small intermediate virtual disk image.
3. Shut down dirty VM.
4. Attach that disk image to a no-internet transfer/sanitization VM.
5. Sanitize documents in the transfer VM.
6. Transfer only sanitized outputs from the transfer VM to `Sanitized-Outbox`.

The second pattern prevents a compromised browsing VM from directly writing into
a host-visible folder.

The repo includes a host helper to create the blank intermediate image on the
encrypted external SSD without formatting, mounting, or attaching it on the Mac:

```bash
~/scripts/utm-sandbox-transfer-disk.sh --volume /Volumes/UnsafeLab --size 2g
```

The helper writes a new sparse `.raw` image under
`/Volumes/UnsafeLab/Client-App-Tests/Transfer-Disks/` and refuses to overwrite
existing files. Attach the image to the dirty VM while powered off, format it
inside the guest only after confirming the device name, copy candidate files to
it, shut down, then attach it to the no-internet transfer VM. Do **not** mount
that raw disk image on the Mac host and do **not** use it as a shared folder.

## Sites that require desktop clients

### Windows client required

1. Duplicate a clean Windows template VM.
2. Name it after the site/client.
3. Disable shared clipboard and shared folders.
4. Use Shared Network with host isolation, not Bridged.
5. Install the client.
6. Use a throwaway account where possible.
7. Test only what is required.
8. Export only screenshots, logs, or sanitized outputs.
9. Delete or revert the VM afterward.

### macOS client required

Use a macOS VM if the app works there. If it cannot run in a VM and asks for
kernel/system extensions, MDM enrollment, hardware drivers, or broad privacy
permissions, prefer separate sacrificial hardware.

### Last-resort host installation

Only for a client you must use and cannot run in a VM:

1. Confirm it is from the expected vendor.
2. Let Gatekeeper and notarization work normally; do not casually bypass them.
3. Use a separate standard macOS user account.
4. Disconnect personal external drives.
5. Do not grant Full Disk Access, Accessibility, Input Monitoring, or Screen
   Recording unless absolutely required.
6. Remove the app afterward.
7. Treat this as a meaningful risk, not equivalent to VM isolation.

## Verification and review checklist

Run the setup verification helper:

```bash
~/scripts/setup-utm-sandbox-macos.sh --verify --volume /Volumes/UnsafeLab
```

Run the read-only UTM bundle audit after creating or moving VMs into
`/Volumes/UnsafeLab/VMs/`:

```bash
~/scripts/utm-sandbox-audit.sh --volume /Volumes/UnsafeLab
# Optional CI-style check for a lab you expect to be clean:
~/scripts/utm-sandbox-audit.sh --fail-on-warning --volume /Volumes/UnsafeLab
```

The audit checks the expected lab folders and owner-only `700` permissions, then
parses each `.utm/config.plist` with Python `plistlib` and reports best-effort
warnings for bridged networking, clipboard sharing, shared-folder bridges, host
personal folder paths, USB forwarding, and port forwarding. It is read-only and
intentionally does not modify UTM bundles. Treat a clean audit as a prompt for
manual review, not as proof of containment; UTM GUI settings remain the source of
truth.

Host review:

- `/Volumes/UnsafeLab` is mounted only when needed.
- Disk Utility shows APFS Encrypted and GUID Partition Map.
- Time Machine excludes `/Volumes/UnsafeLab`.
- Spotlight indexing is disabled or Search Privacy excludes the volume.
- UTM VM bundles live under `/Volumes/UnsafeLab/VMs/`.
- Raw files are not in normal host folders.

UTM review for each dirty VM:

- Same architecture as host where possible.
- QEMU backend if using Disposable Mode / Run without saving changes.
- Shared Network + Isolate Guest from Host, Emulated VLAN, or Host Only.
- No Bridged networking unless explicitly required for a client test.
- No port forwarding.
- Clipboard sharing off.
- Shared directory off, or limited to `Sanitized-Outbox` only for sanitized
  transfers.
- USB auto-connect off/prompt-only.
- No iCloud, password-manager sync, browser sync, or personal credentials.

## Residual risks

This setup reduces risk; it does not make unsafe content safe.

Remaining risks include:

- VM escape through the browser, guest OS, QEMU, Apple virtualization components,
  or device-forwarding bugs.
- Shared-folder risk: any shared folder is a bridge the guest can write to.
- Clipboard leakage of passwords, tokens, URLs, or copied sensitive text.
- Network pivoting from Bridged networking or a guest with LAN access.
- USB risk from forwarded devices.
- Scanner misses; antivirus and multi-scanner results are not proof of safety.
- VirusTotal leakage when public uploads disclose files to third parties.
- PDF visual deception; flattening removes active content but cannot tell you
  whether the document itself is fraudulent.
- VM-aware malware that behaves benignly in virtual machines.
- Host compromise; a malicious host can observe or tamper with VMs and external
  drives.
- Backups/local snapshots if unsafe files accidentally land in backed-up internal
  folders before being moved.

## Daily checklist

1. Unlock and mount `/Volumes/UnsafeLab`.
2. Confirm UTM VM bundles are under `/Volumes/UnsafeLab/VMs/`.
3. Confirm Time Machine and Spotlight exclusions.
4. Start the dirty Linux VM in Disposable Mode / Run without saving changes when
   possible.
5. Re-check isolation: clipboard off, shared folders off or `Sanitized-Outbox`
   only, USB prompt-only, no Bridged networking unless required.
6. Use the hardened VM browser profile: no sync, no saved passwords, strict
   protections, dangerous-download warnings on, ask where to save.
7. Download raw files only inside the VM.
8. Hash and scan files inside the VM.
9. Sanitize documents inside the VM or in a no-internet sanitization VM.
10. Transfer only sanitized output.
11. Shut down the disposable VM so changes are lost, or delete/revert the test VM.
12. Eject `/Volumes/UnsafeLab` when finished.

## References

Primary vendor docs to re-check when UTM or macOS changes:

- UTM installation, QEMU settings, Disposable Mode, networking, sharing, and macOS
  preferences: <https://docs.getutm.app/>
- UTM for Mac: <https://mac.getutm.app/>
- Apple Disk Utility encrypted storage, FileVault, Lockdown Mode, Time Machine
  exclusions, Spotlight privacy, and macOS malware protections: Apple Support.
- Mozilla Firefox Enhanced Tracking Protection and dangerous download warnings:
  Mozilla Support.
- Google Chrome Safe Browsing and download warnings: Google Help.
- ClamAV `clamscan`, Microsoft Defender file scanning, OCRmyPDF PDF security
  notes, Dangerzone, OWASP file-upload guidance, and VirusTotal privacy notes for
  file-submission tradeoffs.

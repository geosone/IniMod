# Traceable portable builds

Active build: `.github/workflows/packages.yml` on the maintained master branch.
The workflow compiles from the checked-out commit, never republishes the old
manually built downloads and does not rely on the retired upstream binary site.

| Target | Build | Runtime tests | Distribution |
| --- | --- | --- | --- |
| Linux i386 | Debian 11 / distro FPC | same archive on Debian 11/12/13 and Ubuntu 24.04/26.04 | tar.gz |
| Linux amd64 | Debian 11 / distro FPC | same archive on Debian 11/12/13 and Ubuntu 24.04/26.04 | tar.gz |
| Linux arm64 | Debian 11 / distro FPC under QEMU | same archive on Debian 11/12/13 and Ubuntu 24.04/26.04 | tar.gz |
| Linux armhf | Debian 11 / distro FPC under QEMU | same archive on Debian 11/12/13 and Ubuntu 24.04/26.04 | tar.gz |
| Windows x86 | Lazarus 4.4 / FPC 3.2.2 | real CLI and spaced executable path | ZIP |
| Windows x64 | Lazarus 4.4 / FPC 3.2.2 | real CLI and spaced executable path | ZIP |

Each download contains exactly two files: inimod (or inimod.exe) and README.txt.
The executable has no architecture suffix and needs no installation or global
PATH change. Notices are combined in the README. Architecture appears only in
the download name. Build artifacts and checksums are separate from that payload.

The JPLib snapshot commit and local Windows parser fix are recorded in
third_party/JPLib/SNAPSHOT.txt. Tests cover real read/write behavior, UTF-8,
comment preservation, key renaming/removal and section deletion. Windows tests
also use a path containing spaces, reproducing an actual installed-path failure.

The earlier MSI/DEB experiments remain in legacy/ as historical source only.
They are not active jobs or supported distribution formats. The temporary
inimod-source/binaries/repos jobs on debdev were disabled after that requirement
changed. Tauthon, cryptlib and DOSEMU2 Debian packaging remain independent.

Traceability is not yet a claim of bit-for-bit reproducibility: distribution
package updates and compiler/container inputs must also be pinned and compared
before making that claim. Published downloads should identify the exact workflow
run and source commit, with corresponding source and SHA256SUMS alongside them.

The i386 executable is tested on an amd64 kernel with the distribution-provided
32-bit libc compatibility runtime. This does not claim a full i386 Ubuntu
installation image or i386 support in the Mystic installer.

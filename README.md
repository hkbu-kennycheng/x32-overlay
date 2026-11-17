# gentoo-x32-overlay

A consolidated Gentoo Linux overlay (EAPI 8) that extends the main Gentoo
repository with custom ebuilds, an overlay profile, and patches for **X32 ABI**
support. X32 is an ABI (ILP32 on x86-64) that allows programs to run with
32-bit pointers while taking advantage of 64-bit CPU features.

This repository merges the former three-repository layout
(`x32-overlay`, `etc-portage-x32`, `gentoo-x32-docker`) into a single
repository (Option A consolidation). The `etc-portage-x32` content
(package.mask, package.use, patches) lives under `profiles/x32/` with full
commit history preserved via `git subtree`.

## Layout

```
dev-lang/rust-bin/          Rust binary ebuilds with abi_x86_x32 USE flag
dev-python/cryptography/    cryptography wheel builds for the x32 target
dev-util/maturin/           maturin ebuild with x32 support
gnome-base/librsvg/         librsvg with x32 cross-compilation
media-libs/svt-av1/         SVT-AV1 with x32 fixes
eclass/x32-rust.eclass      x32 Rust helpers (env export, ring vendor patches)
profiles/x32/               x32 profile: package.mask, package.use, patches, profile.bashrc
.devcontainer/              Dev container (stage4:x32-systemd) with the overlay mounted
```

## Usage

Add the overlay to a Gentoo x32 system (or container):

```bash
mkdir -p /etc/portage/repos.conf
cat > /etc/portage/repos.conf/x32-overlay.conf <<EOF
[x32-overlay]
location = /var/db/repos/x32-overlay
EOF
```

Wire up the profile configuration:

```bash
ln -sfn /var/db/repos/x32-overlay/profiles/x32/patches /etc/portage/patches
mkdir -p /etc/portage/package.mask /etc/portage/package.use
ln -sfn /var/db/repos/x32-overlay/profiles/x32/package.mask /etc/portage/package.mask/x32-overlay
ln -sfn /var/db/repos/x32-overlay/profiles/x32/package.use /etc/portage/package.use/x32-overlay
```

`profiles/x32/profile.bashrc` is applied automatically to every emerge when the
repository is synced by a Portage version supporting `profile-bashrcs`
(>= 3.0.50). It also creates the `/etc/portage/patches` symlink on the fly when
missing.

## Development

See `CLAUDE.md` for the development workflow, x32 ebuild patterns, and
container-based testing instructions. A devcontainer is provided in
`.devcontainer/` (`compose.yaml` + `Containerfile.dev`) based on
`docker.io/kennycheng/gentoo-stage4:x32-systemd`.

## Verified builds (2026-11-16, `x32-dev-verify` container on stage4:x32-systemd)

`emerge -pv` resolved `dev-lang/rust-bin dev-util/maturin dev-python/cryptography
gnome-base/librsvg media-libs/svt-av1 app-misc/jq` without conflicts. All built
binaries are genuine x32 ELF (`ELF 32-bit LSB ..., x86-64 ...,
interpreter /libx32/ld-linux-x32.so.2`):

| Package | Result |
|---|---|
| `app-misc/jq-1.8.2` | `x32.patch` auto-applied via `/etc/portage/patches` symlink (eapply_user) |
| `dev-util/maturin-1.14.1` | `x32-rust.eclass` patched vendored `ring-0.17.14` (intel.rs, mont.rs, cfg gates, `.cargo-checksum.json`, `Cargo.lock`); `maturin 1.14.1` runs |
| `dev-python/cryptography-49.0.0` | `maturin pep517 build-wheel --out "${T}/wheels-${EPYTHON}"`; wheels install for all impls; `import cryptography` + RSA keygen OK |
| `dev-lang/rust-bin-1.96.1` | multilib install fix: both x86_64 ABIs' std land under `/opt/rust-bin-1.96.1/lib/rustlib`; `rustc --target x86_64-unknown-linux-gnux32` emits x32 ELF |

Notes:

- On an x32-native host, the `ABI_X86="x32 64"` multilib merge of `rust-bin`
  has no standalone std tarball for the non-native x86_64 ABI; the ebuild
  skips it with an `ewarn` (the native pass installs the full toolchain).
- The cryptography wheel dir is per-impl (`${T}/wheels-${EPYTHON}`) because
  abi3 wheels from earlier impls in a shared dir would collide on install.
- `profiles/x32/package.mask/maturin` masks upstream `dev-util/maturin-1.15.0`
  (no x32 ring patches) so dependency chains resolve to the patched overlay
  version.

## Phase 2 verification (2026-11-17, `x32-dev-verify` container on stage4:x32-systemd)

### Development container

`.devcontainer/Containerfile.dev` + `compose.yaml` (in both `gentoo-x32-overlay`
and `gentoo-x32-docker`) provide:

- Base `docker.io/kennycheng/gentoo-stage4:x32-systemd`
- Persistent named volumes: `distfiles`, `binpkgs`, `ccache`, `gentoo`
- Ephemeral build dirs: `tmpfs` on `/var/tmp/portage` (16 GB)
- Overlay registered via `/etc/portage/repos.conf/x32-overlay.conf`
- Profile wiring: `/etc/portage/patches`, `package.mask`, `package.use` symlinks
- Developer tooling: `app-portage/gentoolkit`, `dev-util/pkgdev`,
  `dev-util/pkgcheck` (with `dev-libs/tree-sitter-bash[python]` USE)

### Patch pipeline (all mechanisms verified)

- **`eapply_user`** (canonical): with `/etc/portage/patches` symlinked to the
  overlay patch tree, `ebuild ... unpack prepare` applies `x32.patch` exactly
  once (verified on `app-misc/jq-1.8.2`).
- **`profile.bashrc` `pre_src_prepare`** (fallback): with the symlink absent,
  the ebuild's default `eapply_user` sees nothing; the hook applies the patch
  manually, guarded by a per-`${PF}` marker file in `${T}` so the nested
  `src_prepare` chain cannot double-apply it (verified on jq).
- **Version-agnostic symlinks**: `dev-lang/ruby -> ruby-3.4.12` delivers the
  coroutine fix to both `ruby-3.3.13` and `ruby-4.0.9`; verified by
  `ebuild ... unpack prepare` applying the patch into `configure.ac`.
- **OpenMP**: `llvm-runtimes/openmp -> openmp-23.1.5` carries the x32 runtime
  patch (ILP32 support in `kmp_platform.h`, `-mx32` in
  `LibompHandleFlags.cmake`, `x86_64_x32` arch in `runtime/CMakeLists.txt`).
  Verified: `ebuild openmp-23.1.5.ebuild unpack prepare` applies it cleanly.
- **`X32_GIT_PATCH=1`** creates a baseline commit (`x32 baseline <PF>`) in a
  transient git repo inside `${S}` for `git diff`-based patch development
  (verified on jq).

### Overlay profile selectability

- `profiles/profiles.desc` (`amd64 x32 stable`) + `profiles/x32/parent`
  (`gentoo:default/linux/amd64/23.0/x32/systemd`) make `x32-overlay:x32`
  selectable via `eselect profile list` (verified in container).
- `profiles/x32/make.defaults` sets `ABI_X86="x32 64"` so packages with
  `REQUIRED_USE="abi_x86_x32? ( abi_x86_64 )"` are installable by default on
  the overlay profile.

### pkgcheck QA

`pkgcheck scan` on the overlay (with `repos.conf/gentoo.conf` present) reports
only upstream-inherited findings (sparc NonsolvableDepsInStable, PotentialStable
keywording) and tree-skew artifacts (svt-av1 `pgo`/`tools` USE flags missing
from the container's older `use.local.desc`). Fixed on the overlay side:
eclass doc tags, maturin restructured to `distutils-r1`, whitespace,
`multiprocessing` inherits, `metadata.xml` remote-ids, cryptography variable
order, `package.mask` atom syntax.

### Additional verified builds

| Package | Result |
|---|---|
| `media-libs/svt-av1-4.1.0` | builds for x32 (`COMPILE_C_ONLY=ON`); `/usr/libx32/libSvtAv1Enc.so.4.1.0` is x32 ELF |
| `gnome-base/librsvg-2.58.5-r1` | `x32-rust` eclass adopted; `/usr/libx32/librsvg-2.so.2.50.0` + `/usr/bin/rsvg-convert` are x32 ELF (`interpreter /libx32/ld-linux-x32.so.2`) |

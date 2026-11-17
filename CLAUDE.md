# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a consolidated Gentoo Linux overlay (`x32-overlay`) providing custom ebuilds, an overlay profile, and user patches for X32 ABI support. X32 is an ABI (ILP32 on x86-64) that runs programs in a 32-bit environment while utilizing 64-bit CPU features.

This repository merges the former `x32-overlay` and `etc-portage-x32` repositories: the `/etc/portage` configuration (package.mask, package.use, patches) now lives in `profiles/x32/` and is wired into a target system via symlinks (see `profiles/x32/profile.bashrc` and `.devcontainer/`).

## Structure

```
dev-lang/rust-bin/          # Rust compiler binary ebuilds with abi_x86_x32 USE flag
dev-python/cryptography/    # Python cryptography with Rust extensions, x32-targeted builds
gnome-base/librsvg/         # SVG rendering library with Rust components, x32 cross-compile
dev-util/maturin/           # Maturin ebuilds with x32 ABI support
media-libs/svt-av1/         # AV1 encoder with x32 fixes
eclass/x32-rust.eclass      # x32 Rust cross-compile helpers (env export + ring vendor patching)
metadata/layout.conf        # Overlay config (thin-manifests, masters = gentoo, profile-bashrcs)
profiles/                   # Overlay metadata (repo_name, eapi)
profiles/x32/               # x32 profile: eapi, package.mask/, package.use/, patches/, profile.bashrc
.devcontainer/              # Dev container (Containerfile.dev + compose.yaml) for testing
```

## Overlay Configuration

- EAPI 8 with thin-manifests enabled
- Inherits from main Gentoo repository (`masters = gentoo`)
- `profile-formats = portage-2 profile-bashrcs` — `profiles/x32/profile.bashrc` hooks `pre_src_prepare`/`post_src_prepare` into every merge
- Manifests do not require signing for local development

## Overlay Profile (`profiles/x32/`)

- `package.mask/` — masks: `>x11-themes/adwaita-icon-theme-3.32.0`, `<dev-lang/ruby-3.3.0`
- `package.use/` — keyword-specific USE flags (cairo/libglvnd `X`, freetype `harfbuzz`, libaom SIMD off)
- `patches/` — x32 user patches in `eapply_user` layout: `patches/<category>/<pkg-version>/x32.patch`. Version-agnostic symlinks (e.g. `app-misc/jq` -> `jq-1.8.2`) keep minor `::gentoo` bumps working. Current patch set (2026-11):

  | Patch dir | Fix |
  |---|---|
  | `app-misc/jq-1.8.2` | `_FILE_OFFSET_BITS`/`_TIME_BITS` 64 on ILP32 (guarded by `!__ILP32__`) |
  | `dev-lang/ruby-3.3.13`, `ruby-3.4.12` | force `ucontext` coroutine backend on x32 (ebuild forces `amd64`) |
  | `dev-build/b2-5.6.1` | add `libx32` to gcc lib path, `-mx32` for 32-bit ELF x86 |
  | `dev-util/android-tools-35.0.2` (fipsmodule), `-36.0.1` (crypto/rand) | x32 `getrandom` syscall number (`0x40000000 + 318`) |
  | `gui-libs/gtk-4.18.6`, `gtk-4.20.4`, `gtk-4.22.5` | disable roaring `x64` SIMD path on `__ILP32__` |
  | `llvm-runtimes/openmp-23.1.5` | x32 (ILP32) runtime support; full port of the former 22.1.8 patch |
  | `net-libs/webkit-gtk-2.54.2` | drop `WTF_CPU_X86_64`, mark `WTF_CPU_UNKNOWN` on `ELF X32` |
  | `dev-debug/gdb-17.2` | skip `si_addr_bnd` fields on x32 (`!__ILP32__`) |

  `dev-libs/boost` needs no patch: upstream ≥1.80 ships `X86_64/SYSV/X32` context aliases in `libs/context/build/Jamfile.v2`.
- `profile.bashrc`:
  - `pre_src_prepare` applies `${CATEGORY}/${P}` and `${CATEGORY}/${PN}`
    patches directly when `/etc/portage/patches` does not resolve to the
    overlay patch tree (eapply_user covers that case). Idempotent: a
    per-`${PF}` marker in `${T}` guards against the double invocation caused
    by nested `src_prepare` chains, and `realpath` dedup handles
    `${PN}`-symlink-to-`${P}` collisions.
  - `post_src_prepare` initializes a transient git repo in `${S}` when
    `X32_GIT_PATCH=1` for rapid patch creation (`git diff` against pristine
    sources).
- `profiles.desc` + `x32/parent`: makes the profile selectable via
  `eselect profile` (`x32-overlay:x32`, inherits
  `gentoo:default/linux/amd64/23.0/x32/systemd`).
- `make.defaults`: `ABI_X86="x32 64"` (x32-native hosts still need 64-bit
  enabled for packages with `REQUIRED_USE="abi_x86_x32? ( abi_x86_64 )"`).
- Symlinked `/etc/portage/patches` cannot be created from `src_prepare`
  (runs unprivileged under `FEATURES=userpriv`); it must be set up at
  container/system provisioning time (see `.devcontainer/Containerfile.dev`).

On target systems, wire up the profile via:

```
/etc/portage/repos.conf/x32-overlay.conf   location = /var/db/repos/x32-overlay
/etc/portage/patches                        -> /var/db/repos/x32-overlay/profiles/x32/patches
/etc/portage/package.mask/x32-overlay       -> /var/db/repos/x32-overlay/profiles/x32/package.mask
/etc/portage/package.use/x32-overlay        -> /var/db/repos/x32-overlay/profiles/x32/package.use
```

## Development Workflow

Test changes in the x32 container (see `.devcontainer/` for the reproducible setup):

```bash
# Run the active container
podman run -it --rm --name x32-test \
  -v $(pwd):/var/db/repos/x32-overlay:Z \
  docker.io/kennycheng/gentoo-stage4:x32-systemd bash

# Sync portage
podman exec x32-test bash -c 'emerge-webrsync'

# add local overlay configuration
podman exec x32-test bash -c 'mkdir -p /etc/portage/repos.conf'
podman exec x32-test bash -c 'echo "[x32-overlay]" > /etc/portage/repos.conf/x32-overlay.conf'
podman exec x32-test bash -c 'echo "location = /var/db/repos/x32-overlay" >> /etc/portage/repos.conf/x32-overlay.conf'

# wire up profile config (patches/masks/USE)
podman exec x32-test bash -c 'ln -sfn /var/db/repos/x32-overlay/profiles/x32/patches /etc/portage/patches'
podman exec x32-test bash -c 'mkdir -p /etc/portage/package.mask /etc/portage/package.use'
podman exec x32-test bash -c 'ln -sfn /var/db/repos/x32-overlay/profiles/x32/package.mask /etc/portage/package.mask/x32-overlay'
podman exec x32-test bash -c 'ln -sfn /var/db/repos/x32-overlay/profiles/x32/package.use /etc/portage/package.use/x32-overlay'

# Generate ebuild Manifest
podman exec x32-test bash -c 'cd /var/db/repos/x32-overlay/dev-util/maturin && ebuild maturin-1.14.1.ebuild digest'

# Test the ebuild by emerging the package
podman exec x32-test bash -c 'emerge --oneshot maturin'

# emerge gentoolkit to get `equery` for file listing
podman exec x32-test bash -c 'emerge gentoolkit'

# verify package file with `file`
podman exec x32-test bash -c 'equery files maturin | grep -v ".pyc" | xargs file | grep -E "x86-64|x32|gnux32"'
maturin --version
```

## X32-Specific Patterns

When adding or modifying ebuilds for x32 support, follow these patterns:

**Use flags:**
- Add `abi_x86_x32` to IUSE for packages that benefit from x32 ABI
- Add `REQUIRED_USE="abi_x86_x32? ( abi_x86_64 )"` where x32 is an alternate ABI for amd64

**Rust packages:**
- Inherit the `x32-rust` eclass: `x32_rust_is_x32` detects x32 builds;
  `x32_rust_export_env` exports `CARGO_BUILD_TARGET=x86_64-unknown-linux-gnux32`,
  `RUST_TARGET`, `PKG_CONFIG_SYSROOT_DIR=/`, `cross_compiling=yes`, and
  `PYO3_CROSS_LIB_DIR=/usr/lib/${EPYTHON}`; `x32_rust_patch_ring_vendor`
  patches vendored `ring-*` crates for ILP32 and fixes
  `.cargo-checksum.json` / `Cargo.lock` (no-op when no ring crate is vendored)
- Check `${ABI} == "x32"` (via `x32_rust_is_x32`) to apply x32-specific settings
- Use `DISTUTILS_ARGS=( --target "${X32_RUST_TARGET}" )` for maturin builds;
  pass `--out "${T}/wheels-${EPYTHON}"` to `maturin pep517 build-wheel` and
  install `"${T}"/wheels-"${EPYTHON}"/*.whl` (per-impl dir: abi3 wheels from
  earlier impls collide in a shared dir; do not parse stdout)

**Multilib packages:**
- Use `multilib-minimal` or `multilib-is-native-abi` patterns
- Set `cross_compiling=yes` when building for x32 ABI to ensure configure scripts use the right Rust target

**Patches:**
- Place in `files/` subdirectory within the package category
- Reference via `PATCHES=( "${FILESDIR}"/<patch-name>.patch )`
- Cross-package x32 fixes go in `profiles/x32/patches/` (auto-applied via profile.bashrc / /etc/portage/patches symlink)

## Key x32 Patterns (from former etc-portage-x32)

**Ruby coroutine selection** (configure.ac):
- Gentoo ebuild forces `--with-coroutine=amd64` on x32 CHOSTs
- amd64 coroutine assembly uses 8-byte `movq` on stack pointers but x32 ILP32 has 4-byte pointers → corrupted saved context
- Fix: Override to ucontext backend after the ebuild's forced option. Use `AC_CHECK_FUNCS([getcontext swapcontext makecontext])` to set `coroutine_type=ucontext` when `ac_cv_sizeof_voidp=4`

**LLVM OpenMP** (kmp.h, etc.):
- Add `KMP_ARCH_X86_X32` to existing `KMP_ARCH_X86_64` conditionals
- May need `ld-linux-x32.so.2` in expected library deps

**Rust ring crate** (ILP32 pointer width):
- `src/cpu/intel.rs`: pointer-size assertion must be 4 on x32
- `src/arithmetic/limbs/x86_64/mont.rs`: `8 * Limb::BITS == 512` fails (32-bit limbs on x32)
- All `cfg(target_arch = "x86_64")` gates need `target_pointer_width = "64"` added
- Handled automatically by `x32_rust_patch_ring_vendor` in `eclass/x32-rust.eclass`

**General**:
- x32 has `__ILP32__` defined; pointers are 32-bit, but the x86-64 ISA (8-byte stack slots, 64-bit GPRs)
- `SIZEOF_VOIDP=4` distinguishes x32 from x86_64 (`SIZEOF_VOIDP=8`)

## Verification (2026-11-17)

All of the following were verified end-to-end in the `x32-dev-verify` container
(`docker.io/kennycheng/gentoo-stage4:x32-systemd`):

- **Dev container**: named volumes (`distfiles`, `binpkgs`, `ccache`, `gentoo`),
  `tmpfs /var/tmp/portage:16G`, repos.conf + patches/masks/USE wiring,
  `gentoolkit`/`pkgdev`/`pkgcheck` installed.
- **Patch pipeline**: `eapply_user` (with `/etc/portage/patches` symlinked) and
  the `profile.bashrc` fallback (symlink absent) each apply `x32.patch` exactly
  once; verified on `jq-1.8.2`, `ruby-3.3.13` / `ruby-4.0.9` (via the
  version-agnostic `dev-lang/ruby` symlink), `b2-5.6.1`, `gtk-4.18.6-r1` /
  `gtk-4.22.5-r1`, `android-tools-35.0.2` / `-36.0.1`, `gdb-17.2-r1`,
  `webkit-gtk-2.54.2` and `openmp-23.1.5`.
- **Patch-set refresh (2026-11)**: obsolete per-version dirs (`ruby-3.3.11`,
  `boost-1.80.0-r1`, `boost-build`, `openmp-15.0.7-r2` through `openmp-22.1.8`,
  plus the `b2`/`boost-build`/`sys-devel/gdb` pseudo-dirs) were replaced with
  patches regenerated against current `::gentoo` versions; `dev-libs/boost`
  no longer needs a patch (1.80+ ships upstream x32 context aliases), and
  `boosting b2` patches apply to both `b2-5.4.2-r1` (stable) and `b2-5.6.1`.
  Full builds succeeding with the patched sources: `jq-1.8.2`, `b2-5.4.2-r1`,
  `b2-5.6.1`, `gtk-4.18.6-r1`, `gtk-4.22.5-r1`, `android-tools-36.0.1`,
  `gdb-17.2-r1` and `openmp-23.1.5` (runtime-tested with a `-fopenmp`
  reduction program; `openmp-23.1.5` needed a `kmp_invoke_microtask.cpp`
  guard so the x32 asm path is not double-defined).
- **X32_GIT_PATCH=1**: baseline commit created in `${S}` (verified on jq).
- **Profile selectability**: `eselect profile list` shows `x32-overlay:x32`
  (stable, inherits the Gentoo x32 systemd profile).
- **pkgcheck**: clean for overlay-owned issues (remaining findings are
  upstream-inherited sparc depset resolution and keyword potentials).
- **Builds**: `librsvg-2.58.5-r1` (x32-rust eclass adopted) and
  `svt-av1-4.1.0` produce x32 ELF (`ELF 32-bit LSB ..., x86-64`,
  `interpreter /libx32/ld-linux-x32.so.2`).

## Ruby-Specific Validation

After ruby rebuild, verify the coroutine backend:

```bash
# Check config.h for backend
grep COROUTINE_H /usr/include/ruby-3.*/x86_64-linux-x32/ruby/config.h

# Quick fiber test (heavy yield)
RUBYOPT="" ruby33 -e 'f = Fiber.new { |x| (1..10000).each { |i| Fiber.yield i*x }; :done }; puts (1..10000).map { |i| f.resume(i) }.size; puts f.resume(1)'
```

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a Gentoo Linux portage overlay (`x32-overlay`) that provides custom ebuilds and patches for X32 ABI support. X32 is an ABI that runs programs in a 32-bit environment while utilizing 64-bit CPU features.

## Structure

- `dev-lang/rust-bin/` - Rust compiler binary ebuilds with `abi_x86_x32` use flag support
- `dev-python/cryptography/` - Python cryptography library with Rust extensions, x32-targeted builds
- `gnome-base/librsvg/` - SVG rendering library with Rust components, x32 cross-compilation support
- `dev-util/maturin/` - Maturation tool ebuilds with x32 ABI support
- `metadata/layout.conf` - Overlay configuration (thin-manifests, masters = gentoo)
- `profiles/` - Overlay metadata (repo_name, eapi)

## Overlay Configuration

- EAPI 8 with thin-manifests enabled
- Inherits from main Gentoo repository (`masters = gentoo`)
- Manifests do not require signing for local development

## Development Workflow

Test changes in the x32 container:

```bash
# Run the active container
podman run -it --rm --name x32-test \
  -v $(pwd):/var/db/repos/x32-overlay:Z \
  kennycheng/gentoo-stage3:x32-systemd bash

# Sync portage
podman exec x32-test bash -c 'emerge-webrsync'

# add local overlay configuration
podman exec x32-test bash -c 'mkdir -p /etc/portage/repos.conf'
podman exec x32-test bash -c 'echo "[x32-overlay]" > /etc/portage/repos.conf/x32-overlay.conf'
podman exec x32-test bash -c 'echo "location = /var/db/repos/x32-overlay" >> /etc/portage/repos.conf/x32-overlay.conf'

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
- Inherit `cargo` and `rust-toolchain` eclasses
- Check `${ABI} == "x32"` to apply x32-specific settings
- Set `CARGO_BUILD_TARGET=x86_64-unknown-linux-gnux32`
- Use `DISTUTILS_ARGS=( --target x86_64-unknown-linux-gnux32 )` for maturin builds
- For cryptography: set `export PKG_CONFIG_SYSROOT_DIR=/` and `PYO3_CROSS_LIB_DIR`

**Multilib packages:**
- Use `multilib-minimal` or `multilib-is-native-abi` patterns
- Set `cross_compiling=yes` when building for x32 ABI to ensure configure scripts use the right Rust target

**Patches:**
- Place in `files/` subdirectory within the package category
- Reference via `PATCHES=( "${FILESDIR}"/<patch-name>.patch )`
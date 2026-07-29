# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{12..15} python3_{14..15}t )
RUST_MIN_VER=1.89.0
RUST_MULTILIB=1

inherit cargo rust-toolchain flag-o-matic shell-completion toolchain-funcs

DESCRIPTION="Build and publish crates with pyo3, rust-cpython and cffi bindings"
HOMEPAGE="https://www.maturin.rs/"
SRC_URI="
	https://github.com/PyO3/maturin/archive/refs/tags/v${PV}.tar.gz
		-> ${P}.gh.tar.gz
	https://distfiles.gentoo.org/pub/dev/ionen@gentoo.org/${P}-vendor.tar.xz
"
# ^ tarball also includes test-crates' Cargo.lock(s) crates for tests

LICENSE="|| ( Apache-2.0 MIT ) doc? ( Apache-2.0 OFL-1.1 )"
LICENSE+="
	0BSD Apache-2.0 Apache-2.0-with-LLVM-exceptions BSD
	CDLA-Permissive-2.0 ISC MIT MIT-0 MPL-2.0 openssl Unicode-3.0 ZLIB
	BZIP2
" # crates
SLOT="0"
KEYWORDS="amd64 arm arm64 ~loong ~mips ppc ppc64 ~riscv ~s390 ~sparc x86"
IUSE="abi_x86_x32 abi_x86_64 doc +ssl test"
REQUIRED_USE="abi_x86_x32? ( abi_x86_64 )"
RESTRICT="!test? ( test )"

RDEPEND="
	app-arch/xz-utils
	app-arch/zstd:=
	ssl? ( dev-libs/openssl:= )
"
DEPEND="${RDEPEND}"
BDEPEND="
	virtual/pkgconfig
	doc? ( >=app-text/mdbook-0.5 )
	test? (
		dev-python/boltons
		dev-python/cffi
		dev-python/virtualenv
		dev-vcs/git
		elibc_musl? ( dev-util/patchelf )
	)
"

QA_FLAGS_IGNORED="usr/bin/${PN}"

pkg_setup() {
	rust_pkg_setup

	if use test; then
		# used to prevent use of network during tests, and silence pip
		# if it finds unrelated issues with system packages (bug #913613)
		cat > "${T}"/pip.conf <<-EOF || die
			[global]
			quiet = 2

			[install]
			no-index = yes
			no-dependencies = yes
		EOF

		# uv does not work easily w/ network-sandbox, force virtualenv
		sed -i 's/"uv"/"uv-not-found"/' tests/common/mod.rs || die

		# needed by several sdist:: tests
		git init -q || die
		git config --global user.email "larry@gentoo.org" || die
		git config --global user.name "Larry the Cow" || die
		git add . || die
		git commit -qm init || die

	fi
}

src_prepare() {
	default

	# Apply x32 patches to ring vendor crate when building for x32 ABI
	# or when abi_x86_x32 use flag is enabled
	if use abi_x86_x32 || [[ ${ABI} == x32 ]]; then
		einfo "Applying ring x32 compatibility patches..."

		# Fix ring's pointer size assertions in cpu/intel.rs
		# https://github.com/briansmith/ring/issues/398
		python3 -c "
intel_rs = '${S}/vendor/ring-0.17.14/src/cpu/intel.rs'
with open(intel_rs) as f:
    content = f.read()
old = '#[cfg(target_arch = \"x86_64\")]\n    const _ASSUMED_POINTER_SIZE: usize = 8;'
new = ('#[cfg(all(target_arch = \"x86_64\", target_pointer_width = \"64\"))]\n'
       '    const _ASSUMED_POINTER_SIZE: usize = 8;\n'
       '    #[cfg(all(target_arch = \"x86_64\", target_pointer_width = \"32\"))]\n'
       '    const _ASSUMED_POINTER_SIZE: usize = 4;')
content = content.replace(old, new)
with open(intel_rs, 'w') as f:
    f.write(content)
" || die

		# Fix Limb::BITS assertion in x86_64 mont.rs for x32 ABI compatibility
		# On x32, Limb::BITS is 32 (pointer-sized), so 8 * 32 = 256, not 512.
		local mont_rs="${S}/vendor/ring-0.17.14/src/arithmetic/limbs/x86_64/mont.rs"
		python3 -c "
mont_rs = '${S}/vendor/ring-0.17.14/src/arithmetic/limbs/x86_64/mont.rs'
with open(mont_rs) as f:
    content = f.read()
content = content.replace(
    'const _512_IS_LIMB_BITS_TIMES_8: () = assert!(8 * Limb::BITS == 512);',
    '// x32-compatible: Limb::BITS is 32 on x32, 64 on x86_64.\n'
    'const _512_IS_LIMB_BITS_TIMES_8: () = ();'
)
with open(mont_rs, 'w') as f:
    f.write(content)
" || die

		# Patch all ring source files to use the generic fallback for x32 ABI.
		# The x86_64 SIMD backend requires 64-bit limbs, which x32 doesn't have.
		# We change all 'target_arch = \"x86_64\"' to
		# 'all(target_arch = \"x86_64\", target_pointer_width = \"64\")' so the
		# x86_64 backend is only selected on true 64-bit pointer targets.
		python3 <<PYEOF || die
import os
base = '${S}/vendor/ring-0.17.14'
old = 'target_arch = "x86_64"'
new = 'all(target_arch = "x86_64", target_pointer_width = "64")'
for root, dirs, files in os.walk(base):
    for fn in files:
        if not fn.endswith('.rs'):
            continue
        fpath = os.path.join(root, fn)
        with open(fpath) as f:
            content = f.read()
        if old in content:
            content = content.replace(old, new)
            with open(fpath, 'w') as f:
                f.write(content)
PYEOF

		# Update cargo checksum for ring to match patched files
		# This updates both .cargo-checksum.json and Cargo.lock
		local ring_checksum
		ring_checksum=$(python3 <<PYEOF || die
import hashlib, json, os
base = '${S}/vendor/ring-0.17.14'
files = {}
all_content = b''
for root, dirs, filenames in os.walk(base):
    for fn in filenames:
        if fn in ('.cargo-checksum.json', '.cargo_vcs_info.json'):
            continue
        fpath = os.path.join(root, fn)
        relpath = os.path.relpath(fpath, base)
        with open(fpath, 'rb') as f:
            content = f.read()
        files[relpath] = hashlib.sha256(content).hexdigest()
        all_content += content
package_checksum = hashlib.sha256(all_content).hexdigest()

# Update .cargo-checksum.json with new file checksums and package checksum
checksum_path = os.path.join(base, '.cargo-checksum.json')
with open(checksum_path) as f:
    checksum_data = json.load(f)
checksum_data['files'] = files
checksum_data['package'] = package_checksum
with open(checksum_path, 'w') as f:
    json.dump(checksum_data, f, separators=(',', ':'))

print(package_checksum)
PYEOF
)
		# Update Cargo.lock ring entry checksum
		sed -i "/^name = \"ring\"$/,/^checksum = / s/^checksum = .*/checksum = \"${ring_checksum}\"/" "${S}/Cargo.lock" || die
	fi

	# Remove setuptools_rust and rust_extensions metadata for pure Cargo build
	sed -i -e '/setuptools_rust/d' -e '/rust_extensions/d' setup.py || die
}

src_configure() {
	export OPENSSL_NO_VENDOR=1
	export ZSTD_SYS_USE_PKG_CONFIG=1

	# https://github.com/rust-lang/stacker/issues/79
	use s390 && ! is-flagq '-march=*' &&
		append-cflags $(test-flags-CC -march=z10)
}

src_compile() {
	# Set CARGO_BUILD_TARGET for x32 cross-compilation
	# The ring crate has pointer width issues on x32 (x86_64 arch but 32-bit pointers)
	# Patches are applied in src_prepare
	if use abi_x86_x32 || [[ ${ABI} == x32 ]]; then
		export CARGO_BUILD_TARGET=x86_64-unknown-linux-gnux32
		export cross_compiling=yes
		ewarn "Building for x32 ABI target: x86_64-unknown-linux-gnux32"
	fi

	cargo_src_compile

	# Build documentation only for AMD64 (native), skip for x32 cross-compile
	if use abi_x86_x32 && [[ ${ABI} == x32 ]]; then
		ewarn "Documentation build skipped for x32 cross-compiled target"
	else
		use !doc || mdbook build -d "${T}"/html guide || die
	fi

	# Generate shell completions only for native ABI (not cross-compiled x32)
	if use abi_x86_x32 && [[ ${ABI} == x32 ]]; then
		ewarn "Shell completions skipped due to cross-compilation for x32"
	elif ! tc-is-cross-compiler; then
		local maturin=$(cargo_target_dir)/maturin
		"${maturin}" completions bash > "${T}"/${PN} || die
		"${maturin}" completions fish > "${T}"/${PN}.fish || die
		"${maturin}" completions zsh > "${T}"/_${PN} || die
	fi
}

src_test() {
	local -x MATURIN_TEST_PYTHON=${EPYTHON}
	local -x PIP_CONFIG_FILE=${T}/pip.conf
	local -x VIRTUALENV_SYSTEM_SITE_PACKAGES=1

	# need this for (new) python versions not yet recognized by pyo3
	local -x PYO3_USE_ABI3_FORWARD_COMPATIBILITY=1

	local CARGO_SKIP_TESTS=(
		# picky cli output test that easily benignly fail (bug #937992)
		cli_tests
		# fragile depending on rust version, also wants libpypy*-c.so for pypy
		errors::pyo3_no_extension_module
		# fails for unsupported rust targets, non-issue here (bug #973104)
		errors::pypi_compatibility_linux_tag
		# unimportant tests that require uv, and not obvious to get it
		# to work with network-sandbox (not worth the trouble)
		develop::develop_uv_cases::case_1_hello_world
		develop::develop_uv_cases::case_2_pyo3_ffi_pure
		# compliance tests using zig (if present) need old libc (bug #946967)
		integration::integration_cases::case_07_cffi_mixed_py_subdir
		integration::integration_cases::case_16_pyo3_stub_generation_zig
		# avoid need for wasm over a single hello world test
		integration::integration_wasm_hello_world
		# these currently attempt to install tomli regardless of python version
		pep517::pep517_default_profile
		pep517::pep517_editable_profile
		# unimportant and simpler to skip, does not work with just `git init`
		sdist::lib_with_parent_workspace_git_dep_sdist
	)

	if [[ ${EPYTHON} == *t ]]; then
		CARGO_SKIP_TESTS+=(
			# incompatible with free-threaded CPython
			develop::develop_pip_cases::case_02_pyo3_mixed
		)
	fi

	cargo_src_test
}

src_install() {
	# Install the maturin binary that was built by cargo
	cargo_src_install

	# Install documentation files
	dodoc Changelog.md README.md

	# Install shell completions only for native ABI
	if use abi_x86_x32 && [[ ${ABI} == x32 ]]; then
		ewarn "Shell completions skipped due to cross-compilation for x32"
	elif ! tc-is-cross-compiler; then
		dobashcomp "${T}"/${PN}
		dofishcomp "${T}"/${PN}.fish
		dozshcomp "${T}"/_${PN}
	fi

	# Install html docs
	use doc && dodoc -r "${T}"/html
}
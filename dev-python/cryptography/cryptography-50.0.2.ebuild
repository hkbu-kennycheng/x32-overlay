# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DISTUTILS_EXT=1
DISTUTILS_USE_PEP517=maturin
PYPI_VERIFY_REPO=https://github.com/pyca/cryptography
PYTHON_COMPAT=( python3_{12..15} python3_{14,15}t )
PYTHON_REQ_USE="threads(+)"

CARGO_OPTIONAL=yes
RUST_MIN_VER="1.83.0"
CRATES="
	asn1@0.24.1
	asn1_derive@0.24.1
	base64@0.23.0
	bitflags@2.13.1
	cc@1.4.0
	cfg-if@1.0.4
	find-msvc-tools@0.1.9
	foreign-types-shared@0.1.1
	foreign-types@0.3.2
	heck@0.5.0
	itoa@1.0.18
	libc@0.2.189
	once_cell@1.21.4
	openssl-macros@0.1.1
	openssl-sys@0.9.117
	openssl@0.10.81
	pem@4.0.0
	pkg-config@0.3.33
	portable-atomic@1.14.0
	proc-macro2@1.0.107
	pyo3-build-config@0.29.2
	pyo3-ffi@0.29.2
	pyo3-macros-backend@0.29.2
	pyo3-macros@0.29.2
	pyo3@0.29.2
	quote@1.0.47
	self_cell@1.3.0
	shlex@2.0.1
	syn@2.0.119
	target-lexicon@0.13.5
	unicode-ident@1.0.24
	vcpkg@0.2.15
"

inherit cargo distutils-r1 flag-o-matic multiprocessing pypi x32-rust

VEC_P=cryptography_vectors-$(ver_cut 1-3)
DESCRIPTION="Library providing cryptographic recipes and primitives"
HOMEPAGE="
	https://github.com/pyca/cryptography/
	https://pypi.org/project/cryptography/
"
SRC_URI+="
	${CARGO_CRATE_URIS}
	test? (
		$(pypi_sdist_url cryptography_vectors "$(ver_cut 1-3)")
		$(pypi_provenance_url "${VEC_P}.tar.gz" cryptography_vectors "$(ver_cut 1-3)")
			-> ${VEC_P}.tar.gz.provenance
	)
"

LICENSE="|| ( Apache-2.0 BSD ) PSF-2"
# Dependent crate licenses
LICENSE+="
	Apache-2.0 Apache-2.0-with-LLVM-exceptions BSD MIT Unicode-3.0
"
SLOT="0"
KEYWORDS="amd64 arm arm64 ~loong ~mips ppc ppc64 ~riscv ~s390 ~sparc x86"
IUSE="abi_x86_x32 abi_x86_64"
REQUIRED_USE="abi_x86_x32? ( abi_x86_64 )"

RDEPEND="
	>=dev-libs/openssl-1.0.2o-r6:0=
	>=dev-python/cffi-2.0.0:=[${PYTHON_USEDEP}]
"
DEPEND="
	${RDEPEND}
"

BDEPEND="
	${RUST_DEPEND}
	>=dev-util/maturin-1.9.4[${PYTHON_USEDEP}]
	dev-python/setuptools[${PYTHON_USEDEP}]
	test? (
		dev-python/certifi[${PYTHON_USEDEP}]
		dev-python/iso8601[${PYTHON_USEDEP}]
		dev-python/pretend[${PYTHON_USEDEP}]
		dev-python/pyasn1-modules[${PYTHON_USEDEP}]
		dev-python/pytz[${PYTHON_USEDEP}]
	)
"

# Files built without CFLAGS/LDFLAGS, acceptable for rust
QA_FLAGS_IGNORED="usr/lib.*/py.*/site-packages/cryptography/hazmat/bindings/_rust.*.so"

EPYTEST_PLUGINS=( hypothesis )
EPYTEST_XDIST=1
distutils_enable_tests pytest

src_unpack() {
	if use verify-provenance; then
		pypi_verify_provenance "${DISTDIR}/${P}.tar.gz"{,.provenance}
		use test && pypi_verify_provenance "${DISTDIR}/${VEC_P}.tar.gz"{,.provenance}
	fi

	cargo_src_unpack
}

src_prepare() {
	distutils-r1_src_prepare

	sed -i -e 's:--benchmark-disable::' pyproject.toml || die

	# work around availability macros not supported in GCC (yet)
	if [[ ${CHOST} == *-darwin* ]] ; then
		local darwinok=0
		if [[ ${CHOST##*-darwin} -ge 16 ]] ; then
			darwinok=1
		fi
		sed -i -e 's/__builtin_available(macOS 10\.12, \*)/'"${darwinok}"'/' \
			src/_cffi_src/openssl/src/osrandom_engine.c || die
	fi

	# Patch vendored ring crate for x32 (ILP32) compatibility;
	# no-op on non-x32 builds.
	x32_rust_patch_ring_vendor
}

python_compile() {
	if x32_rust_is_x32; then
		x32_rust_export_env
		DISTUTILS_ARGS=( --target "${X32_RUST_TARGET}" )
		# Per-impl wheel dir: ${T} is shared across python implementations,
		# so a single dir would make the glob pick up wheels built for
		# earlier impls.
		local wheel_dir="${T}/wheels-${EPYTHON}"
		maturin pep517 build-wheel -i ${EPYTHON} --compatibility off \
			--target "${X32_RUST_TARGET}" \
			--auditwheel=skip \
			--jobs="$(makeopts_jobs)" \
			--out "${wheel_dir}" \
			$(in_iuse debug && usex debug '--profile=dev' '') || die "maturin build-wheel failed"
		local wheel_file
		for wheel_file in "${wheel_dir}"/*.whl; do
			distutils_wheel_install "${BUILD_DIR}/install" "${wheel_file}"
			einfo "  Installed wheel: ${wheel_file##*/}"
		done
	else
		distutils-r1_python_compile
	fi
}

python_configure_all() {
	filter-lto # bug #903908
}

python_test() {
	local -x PYTHONPATH="${PYTHONPATH}:${WORKDIR}/${VEC_P}"
	local EPYTEST_IGNORE=(
		tests/bench
	)
	local EPYTEST_DESELECT=(
		# OOMs depending on overcommit setting and available memory
		tests/hazmat/primitives/test_argon2.py::TestArgon2::test_argon2_malloc_failure
	)

	epytest
}

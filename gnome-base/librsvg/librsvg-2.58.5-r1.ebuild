# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8
PYTHON_COMPAT=( python3_{10..13} )

CRATES="
	adler@1.0.2
	aho-corasick@1.1.2
	android-tzdata@0.1.1
	android_system_properties@0.1.5
	anes@0.1.6
	anstream@0.6.11
	anstyle-parse@0.2.3
	anstyle-query@1.0.2
	anstyle-wincon@3.0.2
	anstyle@1.0.6
	anyhow@1.0.79
	approx@0.5.1
	assert_cmd@2.0.13
	autocfg@1.1.0
	bit-set@0.5.3
	bit-vec@0.6.3
	bit_field@0.10.2
	bitflags@1.3.2
	bitflags@2.4.2
	block@0.1.6
	bstr@1.9.0
	bumpalo@3.14.0
	bytemuck@1.16.3
	byteorder@1.5.0
	cairo-rs@0.19.1
	cairo-sys-rs@0.19.1
	cast@0.3.0
	cc@1.0.83
	cfg-expr@0.15.6
	cfg-if@1.0.0
	chrono@0.4.33
	ciborium-io@0.2.2
	ciborium-ll@0.2.2
	ciborium@0.2.2
	clap@4.4.18
	clap_builder@4.4.18
	clap_complete@4.4.10
	clap_derive@4.4.7
	clap_lex@0.6.0
	color_quant@1.1.0
	colorchoice@1.0.0
	core-foundation-sys@0.8.6
	crc32fast@1.3.2
	criterion-plot@0.5.0
	criterion@0.5.1
	crossbeam-deque@0.8.5
	crossbeam-epoch@0.9.18
	crossbeam-utils@0.8.19
	crunchy@0.2.2
	cssparser-macros@0.6.1
	cssparser@0.31.2
	cstr@0.2.11
	data-url@0.3.1
	deranged@0.3.11
	derive_more@0.99.17
	difflib@0.4.0
	dlib@0.5.2
	doc-comment@0.3.3
	dtoa-short@0.3.4
	dtoa@1.0.9
	either@1.9.0
	encoding_rs@0.8.33
	equivalent@1.0.1
	errno@0.3.8
	exr@1.72.0
	fastrand@2.0.1
	fdeflate@0.3.4
	flate2@1.0.28
	float-cmp@0.9.0
	flume@0.11.0
	fnv@1.0.7
	form_urlencoded@1.2.1
	futf@0.1.5
	futures-channel@0.3.30
	futures-core@0.3.30
	futures-executor@0.3.30
	futures-io@0.3.30
	futures-macro@0.3.30
	futures-task@0.3.30
	futures-util@0.3.30
	fxhash@0.2.1
	gdk-pixbuf-sys@0.19.0
	gdk-pixbuf@0.19.0
	getrandom@0.2.12
	gif@0.12.0
	gio-sys@0.19.0
	gio@0.19.0
	glib-macros@0.19.0
	glib-sys@0.19.0
	glib@0.19.0
	gobject-sys@0.19.0
	half@2.3.1
	hashbrown@0.14.3
	heck@0.4.1
	hermit-abi@0.3.5
	iana-time-zone-haiku@0.1.2
	iana-time-zone@0.1.60
	idna@0.5.0
	image@0.24.8
	indexmap@2.2.2
	is-terminal@0.4.10
	itertools@0.10.5
	itertools@0.12.1
	itoa@1.0.10
	jpeg-decoder@0.3.1
	js-sys@0.3.68
	language-tags@0.3.2
	lazy_static@1.4.0
	lebe@0.5.2
	libc@0.2.153
	libloading@0.8.1
	libm@0.2.8
	linked-hash-map@0.5.6
	linux-raw-sys@0.4.13
	locale_config@0.3.0
	lock_api@0.4.11
	log@0.4.20
	lopdf@0.32.0
	mac@0.1.1
	malloc_buf@0.0.6
	markup5ever@0.11.0
	matches@0.1.10
	matrixmultiply@0.3.8
	md5@0.7.0
	memchr@2.7.1
	minimal-lexical@0.2.1
	miniz_oxide@0.7.2
	nalgebra-macros@0.2.1
	nalgebra@0.32.3
	new_debug_unreachable@1.0.4
	nom@7.1.3
	normalize-line-endings@0.3.0
	num-complex@0.4.5
	num-conv@0.1.0
	num-integer@0.1.46
	num-rational@0.4.1
	num-traits@0.2.18
	objc-foundation@0.1.1
	objc@0.2.7
	objc_id@0.1.1
	once_cell@1.19.0
	oorandom@11.1.3
	pango-sys@0.19.0
	pango@0.19.0
	pangocairo-sys@0.19.0
	pangocairo@0.19.1
	parking_lot@0.12.1
	parking_lot_core@0.9.9
	paste@1.0.14
	percent-encoding@2.3.1
	phf@0.10.1
	phf@0.11.2
	phf_codegen@0.10.0
	phf_generator@0.10.0
	phf_generator@0.11.2
	phf_macros@0.11.2
	phf_shared@0.10.0
	phf_shared@0.11.2
	pin-project-lite@0.2.13
	pin-utils@0.1.0
	pkg-config@0.3.29
	plotters-backend@0.3.5
	plotters-svg@0.3.5
	plotters@0.3.5
	png@0.17.11
	powerfmt@0.2.0
	ppv-lite86@0.2.17
	precomputed-hash@0.1.1
	predicates-core@1.0.6
	predicates-tree@1.0.9
	predicates@3.1.0
	proc-macro-crate@3.1.0
	proc-macro2@1.0.78
	proptest@1.4.0
	qoi@0.4.1
	quick-error@1.2.3
	quick-error@2.0.1
	quote@1.0.35
	rand@0.8.5
	rand_chacha@0.3.1
	rand_core@0.6.4
	rand_xorshift@0.3.0
	rawpointer@0.2.1
	rayon-core@1.12.1
	rayon@1.8.1
	rctree@0.6.0
	redox_syscall@0.4.1
	regex-automata@0.4.5
	regex-syntax@0.8.2
	regex@1.10.3
	rgb@0.8.37
	rustix@0.38.31
	rusty-fork@0.3.0
	ryu@1.0.16
	safe_arch@0.7.1
	same-file@1.0.6
	scopeguard@1.2.0
	selectors@0.25.0
	serde@1.0.196
	serde_derive@1.0.196
	serde_json@1.0.113
	serde_spanned@0.6.5
	servo_arc@0.3.0
	simba@0.8.1
	simd-adler32@0.3.7
	siphasher@0.3.11
	slab@0.4.9
	smallvec@1.13.1
	spin@0.9.8
	stable_deref_trait@1.2.0
	string_cache@0.8.7
	string_cache_codegen@0.5.2
	strsim@0.10.0
	syn@1.0.109
	syn@2.0.48
	system-deps@6.2.0
	target-lexicon@0.12.13
	tempfile@3.10.0
	tendril@0.4.3
	termtree@0.4.1
	thiserror-impl@1.0.56
	thiserror@1.0.56
	tiff@0.9.1
	time-core@0.1.2
	time-macros@0.2.18
	time@0.3.36
	tinytemplate@1.2.1
	tinyvec@1.6.0
	tinyvec_macros@0.1.1
	toml@0.8.10
	toml_datetime@0.6.5
	toml_edit@0.21.1
	toml_edit@0.22.4
	typenum@1.17.0
	unarray@0.1.4
	unicode-bidi@0.3.15
	unicode-ident@1.0.12
	unicode-normalization@0.1.22
	url@2.5.0
	utf-8@0.7.6
	utf8parse@0.2.1
	version-compare@0.1.1
	wait-timeout@0.2.0
	walkdir@2.4.0
	wasi@0.11.0+wasi-snapshot-preview1
	wasm-bindgen-backend@0.2.91
	wasm-bindgen-macro-support@0.2.91
	wasm-bindgen-macro@0.2.91
	wasm-bindgen-shared@0.2.91
	wasm-bindgen@0.2.91
	web-sys@0.3.68
	weezl@0.1.8
	wide@0.7.15
	winapi-i686-pc-windows-gnu@0.4.0
	winapi-util@0.1.6
	winapi-x86_64-pc-windows-gnu@0.4.0
	winapi@0.3.9
	windows-core@0.52.0
	windows-sys@0.48.0
	windows-sys@0.52.0
	windows-targets@0.48.5
	windows-targets@0.52.0
	windows_aarch64_gnullvm@0.48.5
	windows_aarch64_gnullvm@0.52.0
	windows_aarch64_msvc@0.48.5
	windows_aarch64_msvc@0.52.0
	windows_i686_gnu@0.48.5
	windows_i686_gnu@0.52.0
	windows_i686_msvc@0.48.5
	windows_i686_msvc@0.52.0
	windows_x86_64_gnu@0.48.5
	windows_x86_64_gnu@0.52.0
	windows_x86_64_gnullvm@0.48.5
	windows_x86_64_gnullvm@0.52.0
	windows_x86_64_msvc@0.48.5
	windows_x86_64_msvc@0.52.0
	winnow@0.5.39
	xml5ever@0.17.0
	yeslogic-fontconfig-sys@5.0.0
	zune-inflate@0.2.54
"

RUST_MIN_VER="1.71.1"
RUST_MULTILIB=1

inherit cargo gnome2 multilib-minimal python-any-r1 rust-toolchain vala

DESCRIPTION="Scalable Vector Graphics (SVG) rendering library"
HOMEPAGE="https://wiki.gnome.org/Projects/LibRsvg https://gitlab.gnome.org/GNOME/librsvg"
SRC_URI+=" ${CARGO_CRATE_URIS}"

LICENSE="LGPL-2.1+"
# Dependent crate licenses
LICENSE+="
	Apache-2.0 Apache-2.0-with-LLVM-exceptions BSD ISC MIT MPL-2.0
	Unicode-DFS-2016
"

SLOT="2"
KEYWORDS="amd64 arm arm64 ~loong ~mips ppc ppc64 ~riscv ~s390 sparc x86"

IUSE="gtk-doc +introspection +vala"
REQUIRED_USE="
	gtk-doc? ( introspection )
	vala? ( introspection )
"

RDEPEND="
	>=x11-libs/cairo-1.17.0[glib,svg(+),${MULTILIB_USEDEP}]
	>=media-libs/freetype-2.9:2[${MULTILIB_USEDEP}]
	>=x11-libs/gdk-pixbuf-2.20:2[introspection?,${MULTILIB_USEDEP}]
	>=dev-libs/glib-2.50.0:2[${MULTILIB_USEDEP}]
	>=media-libs/harfbuzz-2.0.0:=[${MULTILIB_USEDEP}]
	>=dev-libs/libxml2-2.9.1-r4:2=[${MULTILIB_USEDEP}]
	>=x11-libs/pango-1.50.0[${MULTILIB_USEDEP}]

	introspection? ( >=dev-libs/gobject-introspection-0.10.8:= )
"
DEPEND="${RDEPEND}"
BDEPEND="
	x11-libs/gdk-pixbuf
	${PYTHON_DEPS}
	$(python_gen_any_dep 'dev-python/docutils[${PYTHON_USEDEP}]')
	gtk-doc? ( dev-util/gi-docgen )
	virtual/pkgconfig
	vala? ( $(vala_depend) )

	dev-libs/gobject-introspection-common
	dev-libs/vala-common
"
# dev-libs/gobject-introspection-common, dev-libs/vala-common needed by eautoreconf

QA_FLAGS_IGNORED="
	usr/bin/rsvg-convert
	usr/lib.*/librsvg.*
"

PATCHES=(
	"${FILESDIR}"/librsvg-2.58.5-time-rust-1.80.patch
)

pkg_setup() {
	rust_pkg_setup
	python-any-r1_pkg_setup
}

src_prepare() {
	use vala && vala_setup
	gnome2_src_prepare
}

src_configure() {
	multilib-minimal_src_configure
}

multilib_src_configure() {
	local myconf=(
		--disable-static
		--disable-debug
		$(multilib_native_use_enable gtk-doc)
		$(multilib_native_use_enable introspection)
		$(multilib_native_use_enable vala)
		--enable-pixbuf-loader
	)

	if ! multilib_is_native_abi; then
		myconf+=(
			# Set the rust target, which can differ from CHOST
			RUST_TARGET="$(rust_abi)"
			# RUST_TARGET is only honored if cross_compiling, but non-native ABIs aren't cross as
			# far as C parts and configure auto-detection are concerned as CHOST equals CBUILD
			cross_compiling=yes
		)
	elif use amd64 && [[ ${ABI} == "x32" ]]; then
        myconf+=(
            # Set the rust target, which can differ from CHOST
            RUST_TARGET="x86_64-unknown-linux-gnux32"
            # RUST_TARGET is only honored if cross_compiling, but non-native ABIs aren't cross as
            # far as C parts and configure auto-detection are concerned as CHOST equals CBUILD
            cross_compiling=yes
        )
	fi

	ECONF_SOURCE=${S} \
	gnome2_src_configure "${myconf[@]}"

	if multilib_is_native_abi; then
		ln -s "${S}"/doc/html doc/html || die
	fi
}

src_compile() {
	multilib-minimal_src_compile
}

multilib_src_compile() {
	cargo_env gnome2_src_compile
}

multilib_src_test() {
	cargo_env default
}

src_test() {
	multilib-minimal_src_test
}

src_install() {
	multilib-minimal_src_install
}

multilib_src_install() {
	cargo_env gnome2_src_install
}

multilib_src_install_all() {
	find "${ED}" -name '*.la' -delete || die

	if use gtk-doc; then
		mkdir -p "${ED}"/usr/share/gtk-doc/html/ || die
		mv "${ED}"/usr/share/doc/Rsvg-2.0 "${ED}"/usr/share/gtk-doc/html/ || die
	fi
}

pkg_postinst() {
	multilib_foreach_abi gnome2_pkg_postinst
}

pkg_postrm() {
	multilib_foreach_abi gnome2_pkg_postrm
}

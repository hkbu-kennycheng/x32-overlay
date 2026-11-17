# profiles/x32/profile.bashrc
#
# Auto-apply x32 user patches and provide a transient git repo helper for
# rapid patch creation.
#
# This file is sourced into the ebuild environment via the profile-formats
# `profile-bashrcs` mechanism (see metadata/layout.conf).
#
# Notes on the execution environment:
#  * src_prepare runs unprivileged (FEATURES=userpriv), so this hook must
#    not attempt to write under /etc. The /etc/portage/patches symlink is
#    established at container/system setup time (see .devcontainer).
#  * The src_prepare default chain (ebuild's own src_prepare -> default)
#    can cause pre_src_prepare to be entered more than once per phase; all
#    logic here is idempotent.

x32_patches_dir() {
	# Canonical location of the x32 patch tree inside this overlay.
	# Overridable via X32_PATCHES_DIR for tests/containers with custom paths.
	echo "${X32_PATCHES_DIR:-/var/db/repos/x32-overlay/profiles/x32/patches}"
}

x32_apply_overlay_patches() {
	# Fallback patch application for when /etc/portage/patches does not
	# resolve to the overlay's patch tree. In that case eapply_user in the
	# ebuild's default src_prepare never sees the x32 patches, so apply
	# them manually here.
	local patches_src="$(x32_patches_dir)"
	local patches_dst="${EROOT}/etc/portage/patches"

	# Only meaningful during the prepare phase.
	[[ ${EBUILD_PHASE} == prepare ]] || return 0

	# If /etc/portage/patches resolves to the overlay patch tree (directly
	# or via a symlink), eapply_user already applies them -- do not apply
	# a second time.
	if [[ -e ${patches_dst} ]]; then
		[[ $(realpath "${patches_src}" 2>/dev/null) == \
			$(realpath "${patches_dst}" 2>/dev/null) ]] && return 0
	fi

	# Idempotency: the pre_src_prepare hook runs more than once per phase
	# (src_prepare nesting: default -> ... -> default). A marker file in
	# ${T} (per-${PF}) ensures each patch is applied exactly once.
	local marker="${T}/.x32-overlay-patches"
	[[ -f ${marker} && $(<"${marker}") == "${PF}" ]] && return 0

	# Apply version-specific (${P}, then ${P} without its release
	# revision) and version-agnostic (${PN}) patch directories. A dir
	# exists for every version carried by the overlay, so ${P} normally
	# matches; ${P%-r*} maps revisions (gtk-4.20.4-r1, gdb-17.2-r1) to
	# the base-version dir. Deduplicate by realpath.
	local d r f seen=()
	for d in "${patches_src}/${CATEGORY}/${P}" \
		 "${patches_src}/${CATEGORY}/${P%-r*}" \
		 "${patches_src}/${CATEGORY}/${PN}"; do
		[[ -d ${d} ]] || continue
		r=$(realpath "${d}" 2>/dev/null) || r=${d}
		local dup=0 s
		for s in "${seen[@]-}"; do
			[[ ${s} == "${r}" ]] && { dup=1; break; }
		done
		[[ ${dup} == 1 ]] && continue
		seen+=("${r}")
		for f in "${d}"/*.patch; do
			[[ -f ${f} ]] || continue
			einfo "Applying x32 patch: ${f#${patches_src}/}"
			(cd "${S}" && eapply "${f}") || \
				die "Failed to apply x32 patch: ${f}"
		done
	done
	[[ -d ${T} ]] && echo "${PF}" > "${marker}"
	return 0
}

x32_post_src_prepare() {
	# When X32_GIT_PATCH=1, initialize a transient git repo in ${S} so that
	# `git diff` produces clean patches against the pristine sources.
	if [[ ${X32_GIT_PATCH} == 1 && ! -e ${S}/.git ]]; then
		(
			cd "${S}" || return 0
			git init -q . 2>/dev/null || return 0
			git add -A 2>/dev/null || return 0
			git -c user.email=x32@gentoo.org -c user.name="x32-dev" \
				commit -qm "x32 baseline ${PF}" 2>/dev/null
		)
		einfo "Initialized transient git repo in ${S} (X32_GIT_PATCH=1)"
	fi
	return 0
}

pre_src_prepare() {
	x32_apply_overlay_patches
	return 0
}

post_src_prepare() {
	x32_post_src_prepare
	return 0
}

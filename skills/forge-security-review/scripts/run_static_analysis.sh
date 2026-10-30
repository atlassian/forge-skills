#!/usr/bin/env bash
#
# Deterministic static-analysis layer for the Forge security review skill.
#
# Runs two pinned, checksum-verified tools against a Forge project and writes every result
# under <project>/security-audit-artifacts/ (override with FORGE_SA_OUTPUT_DIR):
#
#   1. FSRT (github.com/atlassian-labs/FSRT)           -> fsrt/report.json, fsrt/fsrt.log
#   2. OpenGrep (github.com/opengrep/opengrep) running  -> opengrep/results.json,
#      the Forge rules in ../assets/opengrep-rules    opengrep/results.sarif, opengrep/opengrep.log
#
# A machine-readable status summary is written to static-analysis-summary.json and printed at
# the end. Exit codes:
#   0  every tool completed (with or without findings)
#   1  at least one tool did not complete; its status is NOT RUN, never "clean"
#   2  usage error
#
# Environment:
#   FORGE_SA_SKIP_FSRT=1      skip FSRT (reported as "skipped")
#   FORGE_SA_SKIP_OPENGREP=1  skip OpenGrep (reported as "skipped")
#   FORGE_SA_OUTPUT_DIR=path  artifacts directory (default <project>/security-audit-artifacts)
#   FORGE_LOG=level           FSRT log filter (default "warn", so scan failures are captured)
#
# Network: the first run downloads each binary once from its GitHub release and verifies the
# SHA-256 pinned below before executing it. Scans themselves make no network calls, except that
# FSRT fetches Atlassian API specifications into ~/.cache/fsrt on its first run. Nothing is
# uploaded anywhere.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RULES_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)/assets/opengrep-rules"

# ----------------------------------------------------------------------------------------------
# FSRT pin. A specific, immutable GitHub release tag on the atlassian-labs/FSRT repository that
# Atlassian controls. Each artifact's SHA-256 is pinned per platform and verified after download
# so a tampered or substituted release asset is rejected before it is ever executed.
# ----------------------------------------------------------------------------------------------
FSRT_RELEASE_TAG='forge-security-review-test'
FSRT_ASSET_PREFIX='fsrt-tkallady-release-workflow'
FSRT_ASSET_EXT_UNIX='zip'      # archive type of the macOS/Linux assets (zip for this release)
FSRT_ASSET_EXT_WINDOWS='zip'
FSRT_BASE_URL="https://github.com/atlassian-labs/FSRT/releases/download/${FSRT_RELEASE_TAG}"
FSRT_SHA256_aarch64_apple_darwin='fbee410150a79ec6d7efe992a20006e633218a17f1cab053c116a74061f8774d'
FSRT_SHA256_aarch64_unknown_linux_gnu='161876b5b81007615a7552ae25057ec35ffe518defdc6d83b720bba1b34cf5ac'
FSRT_SHA256_x86_64_unknown_linux_gnu='776282e121cfe15ed099a13a0cd2ea91944b00daa36aa04cf36ff28d870993e7'
FSRT_SHA256_x86_64_pc_windows_msvc='970c91957df7ddbe23cc45716f16a88c10e8e080efdc7b0df2c3bdf726ffcd83'

# ----------------------------------------------------------------------------------------------
# OpenGrep pin. Official release assets from github.com/opengrep/opengrep (LGPL-2.1, no
# telemetry). Each digest is the SHA-256 of the official release asset for that version.
# ----------------------------------------------------------------------------------------------
OPENGREP_VERSION='1.16.2'
OPENGREP_BASE_URL="https://github.com/opengrep/opengrep/releases/download/v${OPENGREP_VERSION}"
OPENGREP_SHA256_osx_arm64='2a8a1de5cec23ca15a111a036312f66cbbf40f5cb73d67a71bae4f14051e8a02'
OPENGREP_SHA256_osx_x86='138b44372a4db358a8af8a3859756c792dc0f5777f715ce2bec1b8b94b3d2af8'
OPENGREP_SHA256_manylinux_x86='6f74e2624cd9b54e2cbca500dc9905c132b610cba487d2493a948d9d08b8fcb9'
OPENGREP_SHA256_manylinux_aarch64='c1403d2e881800f41ce6d1a6f1a980ffb9d87ef156a1d73a49de9262ab56c0c8'
OPENGREP_SHA256_musllinux_x86='c1cf15b79dcf001828df2289adcf67e90a45415a76a35b4bf9b4e912b2fe13f8'
OPENGREP_SHA256_musllinux_aarch64='3703af69dd4c274ae51e1ed3838a9a95926eab6dff36e6b90f2f0086093dc4bb'
OPENGREP_SHA256_windows_x86='1232aea7e877d82289efe7c676dbf5a32524122a2c5b8ef69564e544802e6ff0'

# Files and directories the rules never need to see: dependencies, build output and the
# artifacts this script writes. Source under static/ (Custom UI) is scanned.
OPENGREP_EXCLUDES=(
	--exclude node_modules --exclude dist --exclude build --exclude .next --exclude out
	--exclude coverage --exclude vendor --exclude security-audit-artifacts
	--exclude '*.min.js' --exclude '*.min.css' --exclude '*.bundle.js' --exclude '*.chunk.js'
	--exclude '*.map'
)

IS_WINDOWS=0
FSRT_ASSET_EXT="${FSRT_ASSET_EXT_UNIX}"
FSRT_BIN="${SCRIPT_DIR}/fsrt"
OPENGREP_BIN="${SCRIPT_DIR}/opengrep"
FSRT_TARGET=''
OPENGREP_ASSET=''

# Per-tool state collected for the summary.
FSRT_STATUS='not_run'
FSRT_DETAIL=''
FSRT_FINDINGS=0
OPENGREP_STATUS='not_run'
OPENGREP_DETAIL=''
OPENGREP_FINDINGS=0
OPENGREP_ERRORS=0
OPENGREP_ERROR_FINDINGS=0
OPENGREP_WARNING_FINDINGS=0

usage() {
	echo "Usage: $0 <forge-project-root-directory>" >&2
}

log() {
	echo "[static-analysis] $*"
}

warn() {
	echo "[static-analysis] WARNING: $*" >&2
}

detect_platform() {
	local os arch
	os="$(uname -s 2>/dev/null || echo unknown)"
	arch="$(uname -m 2>/dev/null || echo unknown)"

	case "${os}" in
	Darwin)
		case "${arch}" in
		arm64 | aarch64)
			FSRT_TARGET='aarch64-apple-darwin'
			OPENGREP_ASSET='osx_arm64'
			;;
		x86_64)
			FSRT_TARGET='' # no FSRT release asset for Intel macOS yet
			OPENGREP_ASSET='osx_x86'
			;;
		esac
		;;
	Linux)
		local libc='manylinux'
		if ldd --version 2>&1 | grep -qi musl; then
			libc='musllinux'
		fi
		case "${arch}" in
		aarch64 | arm64)
			FSRT_TARGET='aarch64-unknown-linux-gnu'
			OPENGREP_ASSET="${libc}_aarch64"
			;;
		x86_64 | amd64)
			FSRT_TARGET='x86_64-unknown-linux-gnu'
			OPENGREP_ASSET="${libc}_x86"
			;;
		esac
		;;
	MINGW* | MSYS* | CYGWIN* | Windows_NT)
		case "${arch}" in
		x86_64 | amd64)
			IS_WINDOWS=1
			FSRT_ASSET_EXT="${FSRT_ASSET_EXT_WINDOWS}"
			FSRT_TARGET='x86_64-pc-windows-msvc'
			FSRT_BIN="${SCRIPT_DIR}/fsrt.exe"
			OPENGREP_ASSET='windows_x86'
			OPENGREP_BIN="${SCRIPT_DIR}/opengrep.exe"
			;;
		esac
		;;
	esac

	if [[ -z "${FSRT_TARGET}" && -z "${OPENGREP_ASSET}" ]]; then
		echo "Error: unsupported platform '${os}/${arch}'. Supported: macOS (arm64, x86_64 for OpenGrep), Linux (x86_64, arm64), Windows (x86_64)." >&2
		exit 2
	fi
}

require_cmd() {
	if ! command -v "$1" >/dev/null 2>&1; then
		echo "required command '$1' is not installed" >&2
		return 1
	fi
}

sha256_of() {
	if command -v sha256sum >/dev/null 2>&1; then
		sha256sum "$1" | awk '{print $1}'
	elif command -v shasum >/dev/null 2>&1; then
		shasum -a 256 "$1" | awk '{print $1}'
	elif command -v openssl >/dev/null 2>&1; then
		openssl dgst -sha256 "$1" | awk '{print $NF}'
	else
		echo "neither sha256sum, shasum nor openssl is available to verify a download" >&2
		return 1
	fi
}

# download_verified <url> <expected-sha256> <destination>
# Downloads to a temporary file, verifies the digest, then moves it into place. Any failure
# leaves nothing behind and returns non-zero.
download_verified() {
	local url="$1" expected="$2" dest="$3" tmp actual
	require_cmd curl || return 1
	tmp="$(mktemp "${dest}.XXXXXX")" || return 1
	log "Downloading ${url}"
	if ! curl -fsSL --retry 3 --connect-timeout 20 "${url}" -o "${tmp}"; then
		rm -f "${tmp}"
		echo "download failed: ${url}" >&2
		return 1
	fi
	actual="$(sha256_of "${tmp}")" || { rm -f "${tmp}"; return 1; }
	if [[ "${actual}" != "${expected}" ]]; then
		rm -f "${tmp}"
		echo "checksum mismatch for ${url}" >&2
		echo "  expected: ${expected}" >&2
		echo "  actual:   ${actual}" >&2
		return 1
	fi
	mv "${tmp}" "${dest}"
	log "Checksum verified: ${actual}"
}

# ----------------------------------------------------------------------------------------------
# FSRT
# ----------------------------------------------------------------------------------------------
install_fsrt() {
	local sha_var="FSRT_SHA256_${FSRT_TARGET//-/_}" expected url tmp_dir archive found
	expected="${!sha_var:-}"
	if [[ -z "${expected}" ]]; then
		echo "no pinned FSRT checksum for ${FSRT_TARGET}; refusing to download an unverified binary" >&2
		return 1
	fi
	require_cmd tar || return 1

	url="${FSRT_BASE_URL}/${FSRT_ASSET_PREFIX}-${FSRT_TARGET}.${FSRT_ASSET_EXT}"
	tmp_dir="$(mktemp -d 2>/dev/null || mktemp -d "${OUTPUT_DIR}/fsrt/tmp.XXXXXX")" || return 1
	archive="${tmp_dir}/fsrt-artifact.${FSRT_ASSET_EXT}"

	log "fsrt not found in ${SCRIPT_DIR}. Downloading the pinned release for ${FSRT_TARGET}..."
	if ! download_verified "${url}" "${expected}" "${archive}"; then
		rm -rf "${tmp_dir}"
		return 1
	fi

	mkdir -p "${tmp_dir}/extracted"
	case "${FSRT_ASSET_EXT}" in
	zip)
		require_cmd unzip || { rm -rf "${tmp_dir}"; return 1; }
		unzip -q "${archive}" -d "${tmp_dir}/extracted" || { rm -rf "${tmp_dir}"; return 1; }
		;;
	tar.gz | tgz)
		tar -xzf "${archive}" -C "${tmp_dir}/extracted" || { rm -rf "${tmp_dir}"; return 1; }
		;;
	*)
		echo "unsupported FSRT asset type: ${FSRT_ASSET_EXT}" >&2
		rm -rf "${tmp_dir}"
		return 1
		;;
	esac

	# Release assets have been packaged as zip -> tar.gz -> <dir>/fsrt. Unpack any nested
	# tarball, then locate the binary wherever it sits.
	local nested
	while IFS= read -r nested; do
		[[ -n "${nested}" ]] || continue
		mkdir -p "${tmp_dir}/nested"
		tar -xzf "${nested}" -C "${tmp_dir}/nested" || { rm -rf "${tmp_dir}"; return 1; }
	done < <(find "${tmp_dir}/extracted" -type f \( -name '*.tar.gz' -o -name '*.tgz' \))

	found="$(find "${tmp_dir}/extracted" "${tmp_dir}/nested" -type f \( -name fsrt -o -name fsrt.exe \) 2>/dev/null | head -n 1)"
	if [[ -z "${found}" ]]; then
		echo "could not find 'fsrt' or 'fsrt.exe' inside the downloaded artifact" >&2
		rm -rf "${tmp_dir}"
		return 1
	fi
	cp "${found}" "${FSRT_BIN}" && chmod +x "${FSRT_BIN}"
	rm -rf "${tmp_dir}"
	log "Installed fsrt to ${FSRT_BIN}"
}

fsrt_installed() {
	if [[ "${IS_WINDOWS}" -eq 1 ]]; then
		[[ -f "${FSRT_BIN}" ]]
	else
		[[ -x "${FSRT_BIN}" ]]
	fi
}

run_fsrt() {
	local out_dir="${OUTPUT_DIR}/fsrt" report log_file rc
	report="${out_dir}/report.json"
	log_file="${out_dir}/fsrt.log"

	if [[ "${FORGE_SA_SKIP_FSRT:-0}" == "1" ]]; then
		FSRT_STATUS='skipped'
		FSRT_DETAIL='FORGE_SA_SKIP_FSRT=1'
		return
	fi
	if [[ -z "${FSRT_TARGET}" ]]; then
		FSRT_STATUS='not_run'
		FSRT_DETAIL='no FSRT release asset for this platform'
		warn "FSRT: ${FSRT_DETAIL}"
		return
	fi
	mkdir -p "${out_dir}"
	rm -f "${report}"
	if ! fsrt_installed; then
		if ! install_fsrt 2>>"${log_file}"; then
			FSRT_STATUS='not_run'
			FSRT_DETAIL="download or verification failed: $(tail -n 1 "${log_file}" 2>/dev/null)"
			warn "FSRT: ${FSRT_DETAIL} (see fsrt/fsrt.log)"
			return
		fi
	fi
	log "Running fsrt against ${TARGET_DIR}"
	# FSRT logs through `tracing`; FORGE_LOG=warn makes scan failures visible, and --out keeps
	# the JSON report separate from the log so a failed scan cannot be mistaken for a clean one.
	FORGE_LOG="${FORGE_LOG:-warn}" "${FSRT_BIN}" --out "${report}" "${TARGET_DIR}" >"${log_file}" 2>&1
	rc=$?

	if [[ "${rc}" -ne 0 ]]; then
		FSRT_STATUS='not_run'
		FSRT_DETAIL="fsrt exited with status ${rc}; see fsrt/fsrt.log"
	elif [[ ! -s "${report}" ]]; then
		FSRT_STATUS='not_run'
		FSRT_DETAIL='fsrt produced no report; see fsrt/fsrt.log'
	elif grep -q -E 'Could not scan|Unable to scan' "${log_file}"; then
		FSRT_STATUS='not_run'
		FSRT_DETAIL="fsrt could not analyse this project: $(grep -E -m1 'Could not scan|Unable to scan' "${log_file}" | sed 's/^.*WARN *//')"
	else
		FSRT_STATUS='completed'
		FSRT_FINDINGS="$(count_occurrences '"check_name"' "${report}")"
		if grep -q -E 'error while running' "${log_file}"; then
			FSRT_STATUS='completed_with_warnings'
			FSRT_DETAIL='a checker reported errors; see fsrt/fsrt.log'
		fi
	fi

	if [[ "${FSRT_STATUS}" == 'not_run' ]]; then
		warn "FSRT: ${FSRT_DETAIL}"
	else
		log "FSRT ${FSRT_STATUS}: ${FSRT_FINDINGS} finding(s) -> ${report}"
		# Keep the report visible on stdout as earlier versions of this script did.
		cat "${report}"
		echo
	fi
}

# ----------------------------------------------------------------------------------------------
# OpenGrep
# ----------------------------------------------------------------------------------------------
install_opengrep() {
	local sha_var="OPENGREP_SHA256_${OPENGREP_ASSET}" expected url name
	expected="${!sha_var:-}"
	if [[ -z "${expected}" ]]; then
		echo "no pinned OpenGrep checksum for ${OPENGREP_ASSET}; refusing to download an unverified binary" >&2
		return 1
	fi
	name="opengrep_${OPENGREP_ASSET}"
	[[ "${IS_WINDOWS}" -eq 1 ]] && name="${name}.exe"
	url="${OPENGREP_BASE_URL}/${name}"
	log "opengrep not found in ${SCRIPT_DIR}. Downloading OpenGrep ${OPENGREP_VERSION} (${OPENGREP_ASSET})..."
	download_verified "${url}" "${expected}" "${OPENGREP_BIN}" || return 1
	chmod +x "${OPENGREP_BIN}"
	log "Installed opengrep to ${OPENGREP_BIN}"
}

opengrep_installed() {
	if [[ "${IS_WINDOWS}" -eq 1 ]]; then
		[[ -f "${OPENGREP_BIN}" ]]
	else
		[[ -x "${OPENGREP_BIN}" ]]
	fi
}

# count_occurrences <literal> <file>: number of times a literal string appears in a file.
count_occurrences() {
	local n
	n="$(grep -o -F -- "$1" "$2" 2>/dev/null | wc -l | tr -d ' ')"
	echo "${n:-0}"
}

run_opengrep() {
	local out_dir="${OUTPUT_DIR}/opengrep" results sarif log_file rc
	results="${out_dir}/results.json"
	sarif="${out_dir}/results.sarif"
	log_file="${out_dir}/opengrep.log"

	if [[ "${FORGE_SA_SKIP_OPENGREP:-0}" == "1" ]]; then
		OPENGREP_STATUS='skipped'
		OPENGREP_DETAIL='FORGE_SA_SKIP_OPENGREP=1'
		return
	fi
	if [[ -z "${OPENGREP_ASSET}" ]]; then
		OPENGREP_STATUS='not_run'
		OPENGREP_DETAIL='no OpenGrep release asset for this platform'
		warn "OpenGrep: ${OPENGREP_DETAIL}"
		return
	fi
	if [[ ! -d "${RULES_DIR}" ]] || ! ls "${RULES_DIR}"/*.yaml >/dev/null 2>&1; then
		OPENGREP_STATUS='not_run'
		OPENGREP_DETAIL="rule file missing at ${RULES_DIR}"
		warn "OpenGrep: ${OPENGREP_DETAIL}"
		return
	fi
	mkdir -p "${out_dir}"
	if ! opengrep_installed; then
		if ! install_opengrep 2>>"${log_file}"; then
			OPENGREP_STATUS='not_run'
			OPENGREP_DETAIL="download or verification failed: $(tail -n 1 "${log_file}" 2>/dev/null)"
			warn "OpenGrep: ${OPENGREP_DETAIL} (see opengrep/opengrep.log)"
			return
		fi
	fi

	rm -f "${results}" "${sarif}"
	log "Running OpenGrep ${OPENGREP_VERSION} with ${RULES_DIR} against ${TARGET_DIR}"
	# OpenGrep's launcher reads rule files as UTF-8; force a UTF-8 locale for the child only.
	# --disable-version-check keeps the scan fully offline.
	# The scan runs from inside the project and targets "." so that the exclude globs only ever
	# match directories inside the project, never a parent directory that happens to be called
	# build, dist or coverage. Result paths are therefore relative to the project root.
	(
		cd "${TARGET_DIR}" && LC_ALL="${LC_ALL:-C.UTF-8}" LANG="${LANG:-C.UTF-8}" PYTHONUTF8=1 \
			"${OPENGREP_BIN}" scan \
			--disable-version-check \
			--config "${RULES_DIR}" \
			--json-output "${results}" \
			--sarif-output "${sarif}" \
			--timeout 30 --timeout-threshold 3 --max-target-bytes 1000000 \
			"${OPENGREP_EXCLUDES[@]}" \
			. >"${log_file}" 2>&1
	)
	rc=$?

	# OpenGrep exits 0 when the scan completes (1 only with --error); anything else is a failure.
	if { [[ "${rc}" -ne 0 ]] && [[ "${rc}" -ne 1 ]]; } || [[ ! -s "${results}" ]] || ! grep -q -F '"results"' "${results}"; then
		OPENGREP_STATUS='not_run'
		OPENGREP_DETAIL="opengrep exited with status ${rc}; see opengrep/opengrep.log"
		warn "OpenGrep: ${OPENGREP_DETAIL}"
		return
	fi

	OPENGREP_STATUS='completed'
	OPENGREP_FINDINGS="$(count_occurrences '"check_id"' "${results}")"
	OPENGREP_ERROR_FINDINGS="$(count_occurrences '"severity":"ERROR"' "${results}")"
	OPENGREP_WARNING_FINDINGS="$(count_occurrences '"severity":"WARNING"' "${results}")"
	# Per-file parse errors and timeouts are listed under "errors" in the JSON output; each
	# entry carries a "code" field. Files that could not be analysed are coverage gaps.
	OPENGREP_ERRORS="$(count_occurrences '"code":' "${results}")"
	if [[ "${OPENGREP_ERRORS}" -gt 0 ]]; then
		OPENGREP_STATUS='completed_with_errors'
		OPENGREP_DETAIL="${OPENGREP_ERRORS} file-level error(s) or timeout(s) listed under \"errors\" in results.json"
	fi
	log "OpenGrep ${OPENGREP_STATUS}: ${OPENGREP_FINDINGS} finding(s) (${OPENGREP_ERROR_FINDINGS} ERROR, ${OPENGREP_WARNING_FINDINGS} WARNING), ${OPENGREP_ERRORS} file error(s) -> ${results}"
}

# ----------------------------------------------------------------------------------------------
# Summary
# ----------------------------------------------------------------------------------------------
json_escape() {
	local s="$1"
	s="${s//\\/\\\\}"
	s="${s//\"/\\\"}"
	printf '%s' "${s}"
}

write_summary() {
	local summary="${OUTPUT_DIR}/static-analysis-summary.json" overall='completed'
	if [[ "${FSRT_STATUS}" == 'not_run' || "${OPENGREP_STATUS}" == 'not_run' ]]; then
		overall='incomplete'
	fi
	cat >"${summary}" <<EOF
{
  "overall": "${overall}",
  "project": "$(json_escape "${TARGET_DIR}")",
  "artifacts_dir": "$(json_escape "${OUTPUT_DIR}")",
  "tools": {
    "fsrt": {
      "status": "${FSRT_STATUS}",
      "detail": "$(json_escape "${FSRT_DETAIL}")",
      "release": "${FSRT_RELEASE_TAG}",
      "findings": ${FSRT_FINDINGS},
      "report": "fsrt/report.json",
      "log": "fsrt/fsrt.log"
    },
    "opengrep": {
      "status": "${OPENGREP_STATUS}",
      "detail": "$(json_escape "${OPENGREP_DETAIL}")",
      "version": "${OPENGREP_VERSION}",
      "rules_dir": "$(json_escape "${RULES_DIR}")",
      "findings": ${OPENGREP_FINDINGS},
      "error_findings": ${OPENGREP_ERROR_FINDINGS},
      "warning_findings": ${OPENGREP_WARNING_FINDINGS},
      "file_errors": ${OPENGREP_ERRORS},
      "json": "opengrep/results.json",
      "sarif": "opengrep/results.sarif",
      "log": "opengrep/opengrep.log"
    }
  }
}
EOF
	echo
	echo "Static analysis summary (${summary}):"
	echo "  FSRT      ${FSRT_STATUS}${FSRT_DETAIL:+ - ${FSRT_DETAIL}} (${FSRT_FINDINGS} finding(s))"
	echo "  OpenGrep  ${OPENGREP_STATUS}${OPENGREP_DETAIL:+ - ${OPENGREP_DETAIL}} (${OPENGREP_FINDINGS} finding(s): ${OPENGREP_ERROR_FINDINGS} ERROR, ${OPENGREP_WARNING_FINDINGS} WARNING)"
	if [[ "${overall}" == 'incomplete' ]]; then
		echo "  RESULT    INCOMPLETE: a tool marked not_run did NOT analyse the project. Report it as a coverage gap; do not treat its absence of findings as a clean result." >&2
		return 1
	fi
	echo "  RESULT    all requested tools completed. Deterministic findings are leads: triage each one against its metadata.skill_rule file before reporting."
	return 0
}

# ----------------------------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------------------------
if [[ "$#" -ne 1 ]]; then
	usage
	exit 2
fi

TARGET_DIR="$1"
if [[ ! -d "${TARGET_DIR}" ]]; then
	echo "Error: target directory does not exist: ${TARGET_DIR}" >&2
	usage
	exit 2
fi
if [[ ! -f "${TARGET_DIR}/manifest.yml" && ! -f "${TARGET_DIR}/manifest.yaml" ]]; then
	echo "Error: no manifest.yml found in target directory: ${TARGET_DIR}" >&2
	echo "Hint: pass the Forge project root directory (the directory containing manifest.yml)." >&2
	exit 2
fi
TARGET_DIR="$(cd "${TARGET_DIR}" && pwd)"
OUTPUT_DIR="${FORGE_SA_OUTPUT_DIR:-${TARGET_DIR}/security-audit-artifacts}"
mkdir -p "${OUTPUT_DIR}/fsrt" "${OUTPUT_DIR}/opengrep"
OUTPUT_DIR="$(cd "${OUTPUT_DIR}" && pwd)"

detect_platform
run_fsrt
run_opengrep
write_summary

#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FSRT_BIN="${SCRIPT_DIR}/fsrt"
# Pinned to a specific, immutable GitHub release tag on the atlassian-labs/FSRT
# repository that Atlassian controls. Each artifact's SHA-256 checksum is
# pinned below (see set_artifact_url_for_platform) and verified after
# download so a tampered or substituted release asset is rejected before
# it is ever executed.
ARTIFACT_BASE_URL='https://github.com/atlassian-labs/FSRT/releases/download/forge-security-review-test'
ARTIFACT_URL=''
ARTIFACT_SHA256=''
IS_WINDOWS=0

set_artifact_url_for_platform() {
	local os arch target
	os="$(uname -s 2>/dev/null || echo unknown)"
	arch="$(uname -m 2>/dev/null || echo unknown)"

	case "${os}" in
	Darwin)
		case "${arch}" in
		arm64|aarch64)
			target='aarch64-apple-darwin'
			ARTIFACT_SHA256='fbee410150a79ec6d7efe992a20006e633218a17f1cab053c116a74061f8774d'
			;;
		*)
			echo "Error: unsupported macOS architecture '${arch}'. Supported: arm64/aarch64." >&2
			exit 1
			;;
		esac
		;;
	Linux)
		case "${arch}" in
		aarch64|arm64)
			target='aarch64-unknown-linux-gnu'
			ARTIFACT_SHA256='161876b5b81007615a7552ae25057ec35ffe518defdc6d83b720bba1b34cf5ac'
			;;
		x86_64|amd64)
			target='x86_64-unknown-linux-gnu'
			ARTIFACT_SHA256='776282e121cfe15ed099a13a0cd2ea91944b00daa36aa04cf36ff28d870993e7'
			;;
		*)
			echo "Error: unsupported Linux architecture '${arch}'. Supported: x86_64/amd64, arm64/aarch64." >&2
			exit 1
			;;
		esac
		;;
	MINGW*|MSYS*|CYGWIN*|Windows_NT)
		case "${arch}" in
		x86_64|amd64)
			target='x86_64-pc-windows-msvc'
			IS_WINDOWS=1
			FSRT_BIN="${SCRIPT_DIR}/fsrt.exe"
			ARTIFACT_SHA256='970c91957df7ddbe23cc45716f16a88c10e8e080efdc7b0df2c3bdf726ffcd83'
			;;
		*)
			echo "Error: unsupported Windows architecture '${arch}'. Supported: x86_64/amd64." >&2
			exit 1
			;;
		esac
		;;
	*)
		echo "Error: unsupported OS '${os}'. Supported OSes: macOS (arm64), Linux (x86_64/arm64), Windows (x86_64)." >&2
		exit 1
		;;
	esac

	ARTIFACT_URL="${ARTIFACT_BASE_URL}/fsrt-tkallady-release-workflow-${target}.zip"
}

verify_artifact_checksum() {
	local zip_path="$1"
	local actual_sha256

	if command -v sha256sum >/dev/null 2>&1; then
		actual_sha256="$(sha256sum "${zip_path}" | awk '{print $1}')"
	elif command -v shasum >/dev/null 2>&1; then
		actual_sha256="$(shasum -a 256 "${zip_path}" | awk '{print $1}')"
	else
		echo "Error: neither 'sha256sum' nor 'shasum' is available to verify the downloaded artifact." >&2
		exit 1
	fi

	if [[ "${actual_sha256}" != "${ARTIFACT_SHA256}" ]]; then
		echo "Error: checksum mismatch for downloaded artifact." >&2
		echo "  Expected: ${ARTIFACT_SHA256}" >&2
		echo "  Actual:   ${actual_sha256}" >&2
		exit 1
	fi

	echo "Checksum verified: ${actual_sha256}"
}

usage() {
	echo "Usage: $0 <forge-project-root-directory>" >&2
}

require_cmd() {
	if ! command -v "$1" >/dev/null 2>&1; then
		echo "Error: required command '$1' is not installed." >&2
		exit 1
	fi
}

download_fsrt() {
	require_cmd curl
	require_cmd unzip
	require_cmd tar

	local tmp_dir
	tmp_dir="$(mktemp -d)"
	trap 'rm -rf "${tmp_dir}"' RETURN

	local zip_path
	zip_path="${tmp_dir}/fsrt-artifact.zip"

	echo "fsrt not found in scripts directory. Downloading artifact for this platform..."
	echo "Artifact URL: ${ARTIFACT_URL}"
	curl -fL "${ARTIFACT_URL}" -o "${zip_path}"
	verify_artifact_checksum "${zip_path}"

	unzip -q "${zip_path}" -d "${tmp_dir}/unzipped"

	local search_root
	search_root="${tmp_dir}/unzipped"

	# Some artifacts unpack into a single top-level directory.
	# Traverse into it first to locate the fsrt binary reliably.
	local top_level_dir
	top_level_dir="$(find "${tmp_dir}/unzipped" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
	if [[ -n "${top_level_dir}" ]]; then
		search_root="${top_level_dir}"
	fi

	echo "Contents of ${tmp_dir}/unzipped:"
	ls -la "${tmp_dir}/unzipped"
	echo "Searching for fsrt under: ${search_root}"
	ls -la "${search_root}"

	local extracted_fsrt
	extracted_fsrt="$(find "${search_root}" -type f \( -name fsrt -o -name fsrt.exe \) | head -n 1)"

	# Some artifacts are packaged as zip -> tar.gz -> fsrt.
	if [[ -z "${extracted_fsrt}" ]]; then
		local nested_tar
		nested_tar="$(find "${search_root}" -type f \( -name '*.tar.gz' -o -name '*.tgz' \) | head -n 1)"

		if [[ -n "${nested_tar}" ]]; then
			local tar_extract_dir
			tar_extract_dir="${tmp_dir}/tar-extracted"
			mkdir -p "${tar_extract_dir}"
			echo "Found nested archive: ${nested_tar}"
			tar -xzf "${nested_tar}" -C "${tar_extract_dir}"
			echo "Contents of ${tar_extract_dir}:"
			ls -la "${tar_extract_dir}"
			extracted_fsrt="$(find "${tar_extract_dir}" -type f \( -name fsrt -o -name fsrt.exe \) | head -n 1)"
		fi
	fi

	if [[ -z "${extracted_fsrt}" ]]; then
		echo "Error: could not find 'fsrt' or 'fsrt.exe' in downloaded artifact." >&2
		exit 1
	fi

	cp "${extracted_fsrt}" "${FSRT_BIN}"
	chmod +x "${FSRT_BIN}"
	echo "Installed fsrt to ${FSRT_BIN}"
}

is_fsrt_installed() {
	if [[ "${IS_WINDOWS}" -eq 1 ]]; then
		[[ -f "${FSRT_BIN}" ]]
	else
		[[ -x "${FSRT_BIN}" ]]
	fi
}

if [[ "$#" -ne 1 ]]; then
	usage
	exit 1
fi

TARGET_DIR="$1"

set_artifact_url_for_platform

if [[ ! -d "${TARGET_DIR}" ]]; then
	echo "Error: target directory does not exist: ${TARGET_DIR}" >&2
	usage
	exit 1
fi

if [[ ! -f "${TARGET_DIR}/manifest.yml" ]]; then
	echo "Error: no manifest.yml found in target directory: ${TARGET_DIR}" >&2
	echo "Hint: pass the Forge project root directory (the directory containing manifest.yml)." >&2
	exit 1
fi

if ! is_fsrt_installed; then
	download_fsrt
fi

echo "Running fsrt against ${TARGET_DIR}"
"${FSRT_BIN}" "${TARGET_DIR}"

#!/usr/bin/env bash

# VMware Fusion Latest Version Downloader, Installer, and Updater
# This script automatically finds, downloads, and optionally installs the highest version available
#
# Inspired by this gist: https://gist.github.com/jetfir3/6b28fd279bbcadbae70980bd711a844f
#
# Usage: $0 [-y] [-i] [-d] [-f] [-t <dmg_path>]
#   -y: Skip download confirmation prompt
#   -i: Automatically install after download (implies -y)
#   -d: Download only (skip installation even if -i is specified)
#   -f: Force update even if same version is installed
#   -t: Test installation with existing DMG file (skips download)

ARCHIVE_BASE_URL="https://archive.org/download/vmwareworkstationarchive/Fusion"
SKIP_CONFIRMATION=false
AUTO_INSTALL=false
DOWNLOAD_ONLY=false
FORCE_UPDATE=false
TEST_DMG=""
VERSION_FILE="${HOME}/.local/.vmwarefusion_last_version"

usage() {
  local exit_code="${1:-1}"
  echo "Usage: $0 [-y] [-i] [-d] [-f] [-t <dmg_path>] [-h]"
  echo "  -y: Skip download confirmation prompt"
  echo "  -i: Automatically install after download (implies -y)"
  echo "  -d: Download only (skip installation even if -i is specified)"
  echo "  -f: Force update even if same version is installed"
  echo "  -t: Test installation with existing DMG file (skips download)"
  echo "  -h: Show this help"
  echo ""
  echo "Examples:"
  echo "  $0              # Interactive download"
  echo "  $0 -i           # Auto download + install (or update if newer)"
  echo "  $0 -i -f        # Force install even if same version"
  echo "  $0 -t ~/Downloads/VMware-Fusion-13.6.4.dmg  # Test install existing DMG"
  exit "$exit_code"
}

while getopts "yidft:h" opt; do
  case $opt in
    y) SKIP_CONFIRMATION=true ;;
    i) AUTO_INSTALL=true; SKIP_CONFIRMATION=true ;;
    d) DOWNLOAD_ONLY=true ;;
    f) FORCE_UPDATE=true ;;
    t) TEST_DMG="$OPTARG"; AUTO_INSTALL=true; SKIP_CONFIRMATION=true ;;
    h) usage 0 ;;
    *) usage 1 ;;
  esac
done

requirements_check() {
  for cmd in curl grep awk sed sort; do
    command -v "$cmd" >/dev/null 2>&1 || {
      echo "Error: $cmd is required but not installed." >&2
      exit 1
    }
  done

  if $AUTO_INSTALL && ! $DOWNLOAD_ONLY; then
    for cmd in hdiutil cp; do
      command -v "$cmd" >/dev/null 2>&1 || {
        echo "Error: $cmd is required for installation but not found." >&2
        exit 1
      }
    done
  fi
}

setup_sort() {
  if sort --version 2>/dev/null | grep -q "GNU coreutils"; then
    SORT_CMD="sort -V"
    SORT_UNIQUE_CMD="sort -uV"
  else
    SORT_CMD="sort -t. -k1,1n -k2,2n -k3,3n -k4,4n"
    SORT_UNIQUE_CMD="sort -t. -k1,1n -k2,2n -k3,3n -k4,4n -u"
  fi
}

# Normalize any version string to a comparable tuple: "MAJOR.MINOR.PATCH.UPDATE"
# Semver "13.6.4" -> "13.6.4.0"
# Year-half "25H2" -> "25.2.0.0", "26H1u1" -> "26.1.0.1"
normalize_version() {
  local ver="$1"
  if [[ $ver =~ ^([0-9]+)H([12])(u([0-9]+))?$ ]]; then
    local year="${BASH_REMATCH[1]}"
    local half="${BASH_REMATCH[2]}"
    local update="${BASH_REMATCH[4]:-0}"
    echo "${year}.${half}.0.${update}"
  elif [[ $ver =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    echo "${ver}.0"
  elif [[ $ver =~ ^([0-9]+)\.([0-9]+)$ ]]; then
    echo "${ver}.0.0"
  else
    echo "0.0.0.0"
  fi
}

version_greater_than() {
  local v1_norm v2_norm
  v1_norm=$(normalize_version "$1")
  v2_norm=$(normalize_version "$2")

  IFS='.' read -ra v1_parts <<< "$v1_norm"
  IFS='.' read -ra v2_parts <<< "$v2_norm"

  for i in {0..3}; do
    local v1_part=${v1_parts[$i]:-0}
    local v2_part=${v2_parts[$i]:-0}
    if [[ $v1_part -gt $v2_part ]]; then
      return 0
    elif [[ $v1_part -lt $v2_part ]]; then
      return 1
    fi
  done
  return 1
}

get_archive_major_versions() {
  local html
  html=$(curl -s -f -L --max-time 30 "$ARCHIVE_BASE_URL/" 2>/dev/null)
  local curl_result=$?

  if [[ $curl_result -ne 0 || -z "$html" ]]; then
    echo "Error: Failed to fetch archive.org page." >&2
    echo "The main VMware Fusion archive may be unavailable." >&2
    echo "" >&2
    echo "Check source availability:" >&2
    echo "   https://archive.org/details/vmwareworkstationarchive" >&2
    echo "" >&2
    echo "Or look for new source:" >&2
    echo "   https://archive.org/search?query=VMware+Fusion&sort=-addeddate" >&2
    exit 1
  fi

  # Match both old-style "13.x/" and new-style "25H2/", "26H1/" folders
  echo "$html" | grep -oE '<a href="([0-9]+\.x|[0-9]+H[12])/"' | \
    sed 's/<a href="\([^"]*\)\/.*/\1/' | \
    sort -u
}

get_archive_full_versions() {
  local major_version="$1"
  local html
  html=$(curl -s -f -L --max-time 30 "$ARCHIVE_BASE_URL/$major_version/" 2>/dev/null || return 1)

  # Match both semver and year-half filenames
  echo "$html" | grep -oE '<a href="VMware-Fusion-[^"]+\.dmg"' | \
    sed 's/<a href="\([^"]*\)".*/\1/' | \
    while read -r filename; do
      local version=""
      # Try semver first: VMware-Fusion-13.6.4-xxx.dmg
      if [[ $filename =~ VMware-Fusion-([0-9]+\.[0-9]+\.[0-9]+) ]]; then
        version="${BASH_REMATCH[1]}"
      # Then year-half: VMware-Fusion-25H2u1-xxx.dmg or VMware-Fusion-26H1-xxx.dmg
      elif [[ $filename =~ VMware-Fusion-([0-9]+H[12](u[0-9]+)?)-[0-9] ]]; then
        version="${BASH_REMATCH[1]}"
      fi
      if [[ -n "$version" ]]; then
        echo "$version $filename $major_version"
      fi
    done
}

find_latest_version() {
  local all_entries=()

  local major_versions
  major_versions=$(get_archive_major_versions)

  if [[ -z "$major_versions" ]]; then
    echo "Error: No major versions found on archive.org." >&2
    exit 1
  fi

  while IFS= read -r major_version; do
    [[ -z "$major_version" ]] && continue
    while IFS=' ' read -r version filename major_ver; do
      if [[ -n "$version" && -n "$filename" ]]; then
        all_entries+=("$version|$filename|$major_ver")
      fi
    done < <(get_archive_full_versions "$major_version" 2>/dev/null)
  done <<< "$major_versions"

  if [[ ${#all_entries[@]} -eq 0 ]]; then
    echo "Error: No versions found on archive.org." >&2
    exit 1
  fi

  local highest_entry=""
  local highest_version=""

  for entry in "${all_entries[@]}"; do
    IFS='|' read -r current_version _ _ <<< "$entry"
    if [[ -z "$highest_version" ]] || version_greater_than "$current_version" "$highest_version"; then
      highest_version="$current_version"
      highest_entry="$entry"
    fi
  done

  echo "$highest_entry"
}

get_installed_version() {
  if [[ -d "/Applications/VMware Fusion.app" ]]; then
    local version
    version=$(defaults read "/Applications/VMware Fusion.app/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "")
    echo "$version"
  else
    echo ""
  fi
}

get_stored_version() {
  if [[ -f "$VERSION_FILE" ]]; then
    cat "$VERSION_FILE" 2>/dev/null || echo ""
  else
    echo ""
  fi
}

store_version() {
  local version="$1"
  local build="$2"
  mkdir -p "$(dirname "$VERSION_FILE")"
  echo "${version}-${build}" > "$VERSION_FILE"
}

extract_build_from_filename() {
  local filename="$1"
  # Handle both "VMware-Fusion-13.6.4-24832108_universal.dmg"
  # and "VMware-Fusion-26H1u1-25689522_universal.dmg"
  if [[ $filename =~ -([0-9]{7,})_ ]]; then
    echo "${BASH_REMATCH[1]}"
  elif [[ $filename =~ -([0-9]{7,})\.dmg ]]; then
    echo "${BASH_REMATCH[1]}"
  else
    echo "unknown"
  fi
}

check_update_needed() {
  local latest_version="$1"
  local latest_filename="$2"
  local latest_build
  latest_build=$(extract_build_from_filename "$latest_filename")
  local latest_full="${latest_version}-${latest_build}"

  echo "=== Version Check ==="

  local installed_version
  installed_version=$(get_installed_version)

  if [[ -z "$installed_version" ]]; then
    echo "VMware Fusion: Not installed"
    echo "Latest available: $latest_full"
    echo "Action: Install"
    return 0
  fi

  local stored_version
  stored_version=$(get_stored_version)

  echo "Installed version: $installed_version"
  if [[ -n "$stored_version" ]]; then
    echo "Last installed: $stored_version"
  fi
  echo "Latest available: $latest_full"

  if $FORCE_UPDATE; then
    echo "Action: Force update (requested)"
    return 0
  fi

  if [[ "$stored_version" == "$latest_full" ]]; then
    echo "Action: Up to date (same version-build)"
    return 1
  elif version_greater_than "$latest_version" "$installed_version"; then
    echo "Action: Update (newer version available)"
    return 0
  elif [[ "$latest_version" == "$installed_version" && "$stored_version" != "$latest_full" ]]; then
    echo "Action: Update (same version, different build)"
    return 0
  else
    echo "Action: Up to date"
    return 1
  fi
}

download_vmware_fusion() {
  local major_version="$1"
  local filename="$2"
  local version="$3"
  local download_url="$ARCHIVE_BASE_URL/$major_version/$filename"
  local download_file="$DOWNLOAD_DIR/$filename"
  local max_retries=3
  local retry_delay=5
  local attempt=1

  echo "Downloading VMware Fusion $version..."
  echo "From: $download_url"
  echo "To: $download_file"
  echo ""

  while [ $attempt -le $max_retries ]; do
    echo "Attempt $attempt of $max_retries..."
    if [ $attempt -gt 1 ] && [ -f "$download_file" ]; then
      echo "Resuming partial download..."
    fi

    if curl -q --progress-bar -f -L -C - --max-time 300 -o "$download_file" "$download_url"; then
      echo -e "\nDownload successful!"
      return 0
    else
      echo "Attempt $attempt failed." >&2
      if [ $attempt -lt $max_retries ]; then
        echo "Retrying in $retry_delay seconds..."
        sleep $retry_delay
      fi
    fi
    ((attempt++))
  done

  echo "Error: Download failed after $max_retries attempts." >&2
  exit 1
}

install_vmware_fusion() {
  local dmg_file="$1"
  local version="$2"
  local filename="$3"

  echo ""
  echo "Starting VMware Fusion Installation"
  echo "==================================="

  if [[ ! -f "$dmg_file" ]]; then
    echo "Error: DMG file not found: $dmg_file"
    return 1
  fi

  if [[ -d "/Applications/VMware Fusion.app" ]]; then
    local current_version
    current_version=$(defaults read "/Applications/VMware Fusion.app/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "Unknown")
    echo "Current VMware Fusion version: $current_version"
    echo "Will replace with version: $version"
    echo ""
  fi

  echo "Mounting DMG file..."

  local mount_output
  mount_output=$(hdiutil attach "$dmg_file" -nobrowse 2>&1)
  local mount_result=$?

  if [[ $mount_result -ne 0 ]]; then
    echo "Error: Failed to mount DMG file (exit code: $mount_result)"
    echo "hdiutil error output: $mount_output"
    return 1
  fi

  echo "Debug - Mount output:"
  echo "$mount_output"
  echo "---"

  local mount_point=""
  mount_point=$(echo "$mount_output" | grep '/Volumes/' | awk -F'\t' '{print $3}' | head -1)

  if [[ -z "$mount_point" ]]; then
    mount_point=$(echo "$mount_output" | grep '/Volumes/' | sed 's/.*[[:space:]]\+\(\/Volumes\/.*\)$/\1/' | head -1)
  fi

  if [[ -z "$mount_point" ]]; then
    mount_point=$(echo "$mount_output" | grep '/Volumes/' | sed 's/.*[[:space:]]\([[:space:]]*\/Volumes\/.*\)/\1/' | sed 's/^[[:space:]]*//' | head -1)
  fi

  if [[ -z "$mount_point" ]]; then
    echo "Checking manually mounted volumes..."
    local possible_mounts
    possible_mounts=$(ls /Volumes/ | grep -i "vmware\|fusion" | head -1)
    if [[ -n "$possible_mounts" ]]; then
      mount_point="/Volumes/$possible_mounts"
    fi
  fi

  if [[ -z "$mount_point" ]]; then
    echo "Error: Could not determine mount point from hdiutil output."
    echo "All parsing methods failed."
    echo "Raw output lines:"
    echo "$mount_output" | cat -n
    echo "$mount_output" | grep '/dev/' | awk '{print $1}' | while read -r device; do
      echo "Attempting to detach device: $device"
      hdiutil detach "$device" -quiet 2>/dev/null || true
    done
    return 1
  fi

  echo "Mounted at: $mount_point"

  local fusion_app
  fusion_app=$(find "$mount_point" -name "VMware Fusion.app" -type d | head -1)
  if [[ -z "$fusion_app" ]]; then
    echo "Error: VMware Fusion.app not found in DMG."
    hdiutil detach "$mount_point" -quiet
    return 1
  fi

  echo "Found: $fusion_app"

  local dmg_version
  dmg_version=$(defaults read "$fusion_app/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "Unknown")
  echo "Version in DMG: $dmg_version"

  if [[ -d "/Applications/VMware Fusion.app" ]]; then
    echo "Removing existing VMware Fusion installation..."
    rm -rf "/Applications/VMware Fusion.app"
    if [[ $? -ne 0 ]]; then
      echo "Error: Failed to remove existing installation. You may need sudo privileges."
      hdiutil detach "$mount_point" -quiet
      return 1
    fi
  fi

  echo "Installing VMware Fusion..."
  cp -R "$fusion_app" "/Applications/"
  if [[ $? -ne 0 ]]; then
    echo "Error: Failed to copy application. You may need sudo privileges."
    hdiutil detach "$mount_point" -quiet
    return 1
  fi

  echo "Removing quarantine attribute..."
  xattr -dr com.apple.quarantine "/Applications/VMware Fusion.app" 2>/dev/null || true

  echo "Cleaning up..."
  hdiutil detach "$mount_point" -quiet
  if [[ $? -ne 0 ]]; then
    echo "Warning: Failed to unmount DMG. It may still be mounted at $mount_point"
  fi

  if [[ -d "/Applications/VMware Fusion.app" ]]; then
    local installed_version
    installed_version=$(defaults read "/Applications/VMware Fusion.app/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "Unknown")
    echo ""
    echo "Installation completed successfully!"
    echo "VMware Fusion $installed_version installed to /Applications/"

    if [[ -n "$filename" ]]; then
      local build_number
      build_number=$(extract_build_from_filename "$filename")
      store_version "$installed_version" "$build_number"
      echo "Version info stored: ${installed_version}-${build_number}"
    fi

    return 0
  else
    echo "Installation failed!"
    return 1
  fi
}

show_license_info() {
  echo ""
  echo "Public keys here: https://github.com/hegdepavankumar/VMware-Workstation-Pro-17-Licence-Keys"
}

main() {
  echo "VMware Fusion Latest Version Downloader & Installer"
  echo "===================================================="

  requirements_check

  if [[ -n "$TEST_DMG" ]]; then
    if [[ ! -f "$TEST_DMG" ]]; then
      echo "Error: Test DMG file not found: $TEST_DMG"
      exit 1
    fi

    echo "Test Mode: Installing existing DMG"
    echo "DMG File: $TEST_DMG"
    echo ""

    local dmg_filename
    dmg_filename=$(basename "$TEST_DMG")
    local test_version="Unknown"

    if [[ $dmg_filename =~ VMware-Fusion-([0-9]+\.[0-9]+\.[0-9]+) ]]; then
      test_version="${BASH_REMATCH[1]}"
    elif [[ $dmg_filename =~ VMware-Fusion-([0-9]+H[12](u[0-9]+)?)-[0-9] ]]; then
      test_version="${BASH_REMATCH[1]}"
    fi

    if [[ $(uname) != "Darwin" ]]; then
      echo "Error: Installation is only supported on macOS."
      exit 1
    fi

    if install_vmware_fusion "$TEST_DMG" "$test_version" "$dmg_filename"; then
      echo ""
      echo "You can now launch VMware Fusion from /Applications/ or Spotlight."
      echo ""
      echo "Public keys here: https://github.com/hegdepavankumar/VMware-Workstation-Pro-17-Licence-Keys"
    else
      echo "Installation failed."
      exit 1
    fi
    exit 0
  fi

  setup_sort

  DOWNLOAD_DIR="${HOME}/Downloads"
  mkdir -p "${DOWNLOAD_DIR}"

  echo "Scanning archive.org for the latest version..."
  local result
  result=$(find_latest_version)

  if [[ -z "$result" || "$result" == *"Error:"* ]]; then
    echo "Error: Could not determine the latest version." >&2
    exit 1
  fi

  IFS='|' read -r latest_version latest_filename latest_major_version <<< "$result"

  if [[ -z "$latest_version" || -z "$latest_filename" || -z "$latest_major_version" ]]; then
    echo "Error: Could not parse version information." >&2
    echo "Debug: result='$result'" >&2
    exit 1
  fi

  echo ""
  echo "Latest version found: VMware Fusion $latest_version"
  echo "File: $latest_filename"
  echo "Major version folder: $latest_major_version"
  if $AUTO_INSTALL && ! $DOWNLOAD_ONLY; then
    echo "Mode: Download + Install"
  else
    echo "Mode: Download Only"
  fi
  echo ""

  if ! $DOWNLOAD_ONLY; then
    if ! check_update_needed "$latest_version" "$latest_filename"; then
      if ! $SKIP_CONFIRMATION; then
        read -r -p "VMware Fusion is up to date. Download anyway? (y/N): " confirm
        case "$confirm" in
          [yY]|[yY][eE][sS])
            echo "Proceeding with download..."
            ;;
          *)
            echo "Operation cancelled."
            exit 0
            ;;
        esac
      else
        echo "VMware Fusion is up to date. Use -f to force update."
        exit 0
      fi
    fi
  fi
  echo ""

  local dmg_path="${DOWNLOAD_DIR}/${latest_filename}"
  local need_download=true

  if [[ -f "$dmg_path" ]]; then
    echo "File already exists: $dmg_path"
    if ! $SKIP_CONFIRMATION; then
      read -r -p "Re-download VMware Fusion $latest_version? (y/N): " confirm
      case "$confirm" in
        [yY]|[yY][eE][sS])
          need_download=true
          ;;
        *)
          need_download=false
          echo "Using existing file."
          ;;
      esac
    else
      need_download=false
      echo "Using existing file (auto mode)."
    fi
  fi

  if $need_download; then
    if ! $SKIP_CONFIRMATION; then
      read -r -p "Download VMware Fusion $latest_version? (y/N): " confirm
      case "$confirm" in
        [yY]|[yY][eE][sS])
          echo "Starting download..."
          ;;
        *)
          echo "Download cancelled."
          exit 0
          ;;
      esac
    else
      echo "Auto-downloading VMware Fusion $latest_version..."
    fi

    download_vmware_fusion "$latest_major_version" "$latest_filename" "$latest_version"

    if [[ $(uname) == "Darwin" ]]; then
      echo "Removing quarantine attribute from DMG..."
      xattr -d com.apple.quarantine "$dmg_path" &>/dev/null || true
    fi
  fi

  echo ""
  echo "Download completed successfully!"
  echo "File location: $dmg_path"

  if $AUTO_INSTALL && ! $DOWNLOAD_ONLY; then
    if [[ $(uname) != "Darwin" ]]; then
      echo "Warning: Installation is only supported on macOS. Skipping installation."
    else
      if install_vmware_fusion "$dmg_path" "$latest_version" "$latest_filename"; then
        echo ""
        echo "You can now launch VMware Fusion from /Applications/ or Spotlight."
        show_license_info
      else
        echo "Installation failed. The DMG file is available at: $dmg_path"
        exit 1
      fi
    fi
  else
    echo "Opening Downloads folder..."
    if [[ $(uname) == "Darwin" ]]; then
      open "$DOWNLOAD_DIR"
    fi

    if ! $DOWNLOAD_ONLY; then
      echo ""
      echo "To install manually, double-click the DMG file and drag VMware Fusion to Applications."
      show_license_info
    fi
  fi
}

main "$@"

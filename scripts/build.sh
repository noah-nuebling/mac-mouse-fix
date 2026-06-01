#!/usr/bin/env bash

# Mac Mouse Fix Build & Package Script
# Usage: ./scripts/build.sh [debug|release]

set -euo pipefail

CONF=${1:-release}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
ORIGINAL_ROOT="$ROOT"
IN_ICLOUD=0
if [[ "$ROOT" == *"/Library/Mobile Documents/"* ]]; then
    IN_ICLOUD=1
    BUILD_DIR="/tmp/MacMouseFix_build"
    echo "==> Detected iCloud Drive path. Redirecting compilation to ${BUILD_DIR} to avoid NSFileCoordinator deadlocks..."
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    rsync -a --exclude=".git" --exclude="DerivedData" --exclude="build" --exclude="*.app" --exclude="releases" "$ROOT/" "$BUILD_DIR/"
    ROOT="$BUILD_DIR"
fi
cd "$ROOT"

PROJECT_NAME="Mouse Fix"
SCHEME="App"
APP_NAME="Mac Mouse Fix.app"
ARCHIVE_PATH="$ROOT/.build/archive/Mac_Mouse_Fix.xcarchive"
APP_BUNDLE="$ROOT/Mac Mouse Fix.app"
SKIP_DMG="${SKIP_DMG:-0}"
SKIP_PACKAGE_RESOLVE="${SKIP_PACKAGE_RESOLVE:-1}"
SIGNING_IDENTITY="${CODE_SIGN_IDENTITY:-Apple Development}"
DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM-$(sed -n 's/.*DEVELOPMENT_TEAM = \([^;]*\);/\1/p' "${PROJECT_NAME}.xcodeproj/project.pbxproj" | grep -v '^$' | head -n 1)}"
if [[ "${SIGNING_IDENTITY}" != "-" ]] && ! security find-identity -v -p codesigning | grep -q "\"${SIGNING_IDENTITY}"; then
    echo "==> Warning: No '${SIGNING_IDENTITY}' signing identity found. Falling back to ad-hoc signing."
    SIGNING_IDENTITY="-"
fi
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$HOME/Library/Developer/Xcode/DerivedData/MacMouseFixCodex}"

create_dmg_with_layout() {
    local app_bundle="$1"
    local dmg_path="$2"
    local target_arch="$3"
    local display_app_name="Mac Mouse Fix.app"
    local dmg_dir
    dmg_dir=$(dirname "$dmg_path")
    local styled_dmg_path="${dmg_dir}/Mac Mouse Fix ${MARKETING_VERSION}.dmg"
    local staging_dir
    staging_dir=$(mktemp -d "${TMPDIR:-/tmp}/macmousefix-dmg-${target_arch}.XXXXXX")
    local fallback_volume
    fallback_volume="${staging_dir}/Mac Mouse Fix"

    cleanup_dmg_staging() {
        rm -rf "$staging_dir"
    }
    trap cleanup_dmg_staging RETURN

    mkdir -p "$staging_dir"
    ditto --noextattr --norsrc "$app_bundle" "${staging_dir}/${display_app_name}"
    xattr -cr "${staging_dir}/${display_app_name}" || true
    find -L "${staging_dir}/${display_app_name}" -xattrname com.apple.FinderInfo \
        -exec xattr -d -s com.apple.FinderInfo {} \; \
        -exec xattr -d com.apple.FinderInfo {} \; 2>/dev/null || true

    if command -v create-dmg >/dev/null 2>&1; then
        echo "==> Creating styled DMG with create-dmg for ${target_arch}..."
        rm -f "${styled_dmg_path}"
        create-dmg \
            --overwrite \
            --dmg-title "Mac Mouse Fix" \
            --no-code-sign \
            "${staging_dir}/${display_app_name}" \
            "${dmg_dir}"

        if [[ -f "${styled_dmg_path}" && "${styled_dmg_path}" != "${dmg_path}" ]]; then
            mv -f "${styled_dmg_path}" "${dmg_path}"
        fi
    fi

    if [[ ! -f "${dmg_path}" ]]; then
        echo "==> Falling back to plain DMG with Applications shortcut for ${target_arch}..."
        rm -rf "${fallback_volume}"
        mkdir -p "${fallback_volume}"
        cp -R "$app_bundle" "${fallback_volume}/${display_app_name}"
        ln -s /Applications "${fallback_volume}/Applications"

        hdiutil create \
            -volname "Mac Mouse Fix" \
            -srcfolder "${fallback_volume}" \
            -ov \
            -format UDZO \
            "${dmg_path}"
    fi
}

if [[ -n "${BUILD_ARCHS:-}" ]]; then
    read -r -a TARGET_ARCHS <<< "${BUILD_ARCHS}"
else
    TARGET_ARCHS=("arm64" "x86_64")
fi

if [[ "$CONF" == "debug" ]]; then
    XCODE_CONF="Debug"
else
    XCODE_CONF="Release"
fi

# Detect version from Xcode project
echo "==> Detecting version from project settings..."
MARKETING_VERSION="${MARKETING_VERSION:-$(sed -n -e 's/.*MARKETING_VERSION = "\(.*\)";/\1/p' -e 's/.*MARKETING_VERSION = \([^;]*\);/\1/p' "${PROJECT_NAME}.xcodeproj/project.pbxproj" | grep -v '^1.0$' | head -n 1)}"
MARKETING_VERSION="${MARKETING_VERSION:-3.1.0}"
BUILD_NUMBER="${CURRENT_PROJECT_VERSION:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' App/SupportFiles/Info.plist 2>/dev/null || true)}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"

echo "==> Version: ${MARKETING_VERSION} (Build: ${BUILD_NUMBER})"

# Detect architecture
ARCH=$(uname -m)
SDK="macosx"

# 1. Resolve dependencies
if [[ "${SKIP_PACKAGE_RESOLVE}" == "1" ]]; then
    echo "==> Skipping explicit package dependency resolution (SKIP_PACKAGE_RESOLVE=1)"
else
    echo "==> Resolving package dependencies..."
    xcodebuild -resolvePackageDependencies -project "${PROJECT_NAME}.xcodeproj" -scheme "${SCHEME}" -scmProvider xcode
fi

# 2. Build or Archive (Loop per architecture)
for TARGET_ARCH in "${TARGET_ARCHS[@]}"; do
    echo "=================================================="
    echo "==> Starting build process for architecture: ${TARGET_ARCH}"
    echo "=================================================="
    
    ARCH_APP_BUNDLE="${ROOT}/Mac Mouse Fix_${TARGET_ARCH}.app"
    ARCH_ARCHIVE_PATH="${ROOT}/.build/archive/Mac_Mouse_Fix_${TARGET_ARCH}.xcarchive"
    
    if [[ "$XCODE_CONF" == "Debug" ]]; then
        echo "==> Building project (${XCODE_CONF}) for ${TARGET_ARCH}..."
        xcodebuild build \
            -project "${PROJECT_NAME}.xcodeproj" \
            -scheme "${SCHEME}" \
            -configuration "${XCODE_CONF}" \
            -destination "platform=macOS" \
            -derivedDataPath "${DERIVED_DATA_PATH}" \
            -disableAutomaticPackageResolution \
            -scmProvider xcode \
            MARKETING_VERSION="${MARKETING_VERSION}" \
            CURRENT_PROJECT_VERSION="${BUILD_NUMBER}" \
            ARCHS="${TARGET_ARCH}" \
            COMPILER_INDEX_STORE_ENABLE=NO \
            CODE_SIGN_IDENTITY="${SIGNING_IDENTITY}" \
            DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM}"
        
        # Locate products
        echo "==> Locating built app..."
        BUILT_PRODUCTS_DIR="${DERIVED_DATA_PATH}/Build/Products/${XCODE_CONF}"
        
        if [[ -z "$BUILT_PRODUCTS_DIR" || ! -d "$BUILT_PRODUCTS_DIR/${APP_NAME}" ]]; then
            echo "ERROR: Could not locate built app in ${BUILT_PRODUCTS_DIR:-unknown}"
            exit 1
        fi
        
        TEMP_SIGN_DIR=$(mktemp -d "${TMPDIR:-/tmp}/macmousefix-sign-${TARGET_ARCH}.XXXXXX")
        cp -R "${BUILT_PRODUCTS_DIR}/${APP_NAME}" "${TEMP_SIGN_DIR}/${APP_NAME}"
    else
        echo "==> Archiving project (${XCODE_CONF}) for ${TARGET_ARCH}..."
        xcodebuild archive \
            -project "${PROJECT_NAME}.xcodeproj" \
            -scheme "${SCHEME}" \
            -configuration "${XCODE_CONF}" \
            -archivePath "${ARCH_ARCHIVE_PATH}" \
            -destination "generic/platform=macOS,name=Any Mac" \
            -scmProvider xcode \
            MARKETING_VERSION="${MARKETING_VERSION}" \
            CURRENT_PROJECT_VERSION="${BUILD_NUMBER}" \
            ARCHS="${TARGET_ARCH}" \
            CODE_SIGN_IDENTITY="${SIGNING_IDENTITY}" \
            DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM}" \
            SKIP_INSTALL=NO
        
        echo "==> Exporting app bundle from archive for ${TARGET_ARCH}..."
        TEMP_SIGN_DIR=$(mktemp -d "${TMPDIR:-/tmp}/macmousefix-sign-${TARGET_ARCH}.XXXXXX")
        cp -R "${ARCH_ARCHIVE_PATH}/Products/Applications/${APP_NAME}" "${TEMP_SIGN_DIR}/${APP_NAME}"
    fi

    # 3. Post-processing (Signing)
    echo "==> Removing extended attributes before signing for ${TARGET_ARCH}..."
    dot_clean -m "${TEMP_SIGN_DIR}/${APP_NAME}" || true
    xattr -cr "${TEMP_SIGN_DIR}/${APP_NAME}" || true
    find "${TEMP_SIGN_DIR}/${APP_NAME}" -name "._*" -exec rm -f {} \; 2>/dev/null || true
    find -L "${TEMP_SIGN_DIR}/${APP_NAME}" -xattrname com.apple.FinderInfo \
        -exec xattr -d -s com.apple.FinderInfo {} \; \
        -exec xattr -d com.apple.FinderInfo {} \; 2>/dev/null || true

    if [[ "${SIGNING_IDENTITY}" == "-" ]]; then
        echo "==> Signing app bundle (Ad-hoc) for ${TARGET_ARCH}..."
        codesign --force --deep --sign "${SIGNING_IDENTITY}" "${TEMP_SIGN_DIR}/${APP_NAME}"
    else
        echo "==> Preserving Xcode signing for ${TARGET_ARCH} (${SIGNING_IDENTITY})..."
    fi

    rm -rf "${ARCH_APP_BUNDLE}"
    cp -R "${TEMP_SIGN_DIR}/${APP_NAME}" "${ARCH_APP_BUNDLE}"
    rm -rf "${TEMP_SIGN_DIR}"

    echo "==> Successfully created ${ARCH_APP_BUNDLE}"

    # 4. Create DMG
    if [[ "${SKIP_DMG}" == "1" ]]; then
        echo "==> Skipping DMG creation for ${TARGET_ARCH} (SKIP_DMG=1)"
    else
        echo "==> Creating DMG for ${TARGET_ARCH}..."
        DMG_DIR="$ROOT/releases"
        mkdir -p "$DMG_DIR"
        
        # Target name for release.sh
        DMG_FINAL_NAME="Mac_Mouse_Fix_${MARKETING_VERSION}_${TARGET_ARCH}.dmg"
        DMG_FINAL_PATH="$DMG_DIR/$DMG_FINAL_NAME"
        rm -f "$DMG_FINAL_PATH"

        create_dmg_with_layout "${ARCH_APP_BUNDLE}" "${DMG_FINAL_PATH}" "${TARGET_ARCH}"

        if [[ -f "$DMG_FINAL_PATH" ]]; then
            echo "==> Successfully created $DMG_FINAL_PATH"
        else
            echo "==> Warning: DMG creation failed for ${TARGET_ARCH}."
        fi
    fi
    if [[ "${IN_ICLOUD}" == "1" ]]; then
        echo "==> Copying built app bundle back to iCloud path..."
        rm -rf "${ORIGINAL_ROOT}/Mac Mouse Fix_${TARGET_ARCH}.app"
        cp -R "${ARCH_APP_BUNDLE}" "${ORIGINAL_ROOT}/"
        if [[ "${SKIP_DMG}" != "1" && -f "${DMG_FINAL_PATH}" ]]; then
            mkdir -p "${ORIGINAL_ROOT}/releases"
            cp "${DMG_FINAL_PATH}" "${ORIGINAL_ROOT}/releases/"
        fi
    fi
done

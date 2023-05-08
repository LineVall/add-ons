#!/bin/bash

# ROM Source
export ROM_MANIFEST="https://github.com/bananadroid/android_manifest.git"
export ROM_NAME="BananaDroid"
export ROM_BRANCH="13"
export ROM_MAINTAINER="Djampt"
export LOCAL_MANIFEST="https://github.com/UnsatifsedError/local_manifests.git -b extra"

# Device Information
export TARGET_NAME="${ROM_NAME}"
export TARGET_DEVICE="Redmi Note 10 Pro"
export TARGET_CODE="sweet"
export TARGET_COMMON="sm6150-common"
export TARGET_KERNEL="sm6150"

export DEVICE_URL="https://github.com/UnsatifsedError/device_xiaomi_sweet.git"
export DEVICE_BRANCH="banana"
export DEVICE_PATH="device/xiaomi/${TARGET_CODE}"

export COMMON_URL="https://github.com/UnsatifsedError/device_xiaomi_sm6150-common.git"
export COMMON_BRANCH="banana"
export COMMON_PATH="device/xiaomi/${TARGET_COMMON}"

export KERNEL_URL="https://github.com/UnsatifsedError/kernel_xiaomi_sm6150.git"
export KERNEL_BRANCH="semlohey"
export KERNEL_PATH="kernel/xiaomi/${TARGET_KERNEL}"

export VENDOR_URL="https://github.com/UnsatifsedError/vendor_xiaomi-sweet.git"
export VENDOR_BRANCH="telulas"
export VENDOR_PATH="vendor/xiaomi/${TARGET_CODE}"

export VCOMMON_URL="https://github.com/UnsatifsedError/vendor_xiaomi_sm6150-common.git"
export VCOMMON_BRANCH="telulas"
export VCOMMON_PATH="vendor/xiaomi/${TARGET_COMMON}"

# Telegram Information
export TG_TOKEN="6265753905:AAG_NGaJW9ZyGw2HZoQgKzmHErcCWWy4JAQ"
export TG_SUCCESS="-1001807327703"
export TG_FAILED="-1001807327703"

# Additional Information
export DIR_ROOT="$HOME/banana"
export DIR_LOG="$HOME/logs/${TARGET_NAME}"
export DIR_CACHE="$HOME/cache/${TARGET_NAME}"
export DIR_MANIFEST=".repo/local_manifests"

export SCRIPT_START=$(date "+%Y%m%d-%H%M")
export LOG_FILE="${TARGET_NAME}-${SCRIPT_START}.log"
export LOG_SYNC="${TARGET_CODE}-sync-${LOG_FILE}"
export LOG_BUILD="${TARGET_CODE}-build-${LOG_FILE}"

if [ ! -d $DIR_ROOT ]; then
    mkdir -p $DIR_ROOT
fi

if [ ! -d $DIR_LOG ]; then
    mkdir -p $DIR_LOG
fi

if [ ! -d $DIR_CACHE ]; then
    mkdir -p $DIR_CACHE
fi

while [[ $# -gt 0 ]]; do
    # Don't show any dialog here. Let this loop checks for errors or shows help
    # We can only show dialogs when there's no error and no -r parameter
    #
    # * shift for parameters that have no value
    # * shift 2 for parameter that have a value
    #
    # Please don't exit any error here if possible. Let it show all error warnings
    # at once
    case "${1}" in
        -f|--fresh-build)
            FRESH_BUILD=1
            shift
            ;;
        -g|--build-gapps)
            BUILD_GAPPS=1
            GAPPS_VARIANT=$2
            shift 2
            ;;
        -s|--sync-source)
            SYNC_SOURCE=1
            shift
            ;;
        -t|--sync-trees)
            SYNC_TREES=1
            shift
            ;;
    esac
done

build_rom() {
    clear
    cd $DIR_ROOT
    echo "=================================================="
    echo "                   Building ROM"
    echo "=================================================="
    sleep 2
    set -exv

    source build/envsetup.sh
    lunch banana_$TARGET_CODE-userdebug
    if [ -d $DIR_ROOT/out ]; then
        if [[ "${FRESH_BUILD}" == 1 ]]; then
            rm -rf $DIR_ROOT/out
        else
            make installclean
        fi
    fi
    export CCACHE_DIR=$DIR_CACHE
    export CCACHE_EXEC=/usr/bin/ccache
    export USE_CCACHE=1
    ccache -o compression=true
    ccache -o compression_level=1
    ccache -o max_size=100G
    ccache -z
    export KBUILD_BUILD_USER=DcuoX
    export KBUILD_BUILD_HOST=SemoxCox
    export BUILD_USERNAME=DcuoX
    export BUILD_HOSTNAME=SemoxCox
    export SELINUX_IGNORE_NEVERALLOWS=true
    export TARGET_SUPPORTS_64_BIT_APPS=true
    make bacon -j$(nproc --all) | tee -a $DIR_LOG/$LOG_BUILD
}

send_notif() {
    clear
    cd $DIR_ROOT
    echo "=================================================="
    echo "               Sending Notification"
    echo "=================================================="
    set -exv

    N_FILE=$(cat $DIR_LOG/$LOG_BUILD | grep "Package Complete" | cut -d " " -f 6)
    N_NAME=$(echo $R_FILE | cut -d "/" -f 5)
    N_MD5=$(md5sum $DIR_ROOT/$N_FILE | awk '{print $1}')

    if [[ "${BUILD_GAPPS}" == 1 ]]; then
        if [[ "${GAPPS_VARIANT}" == "core" ]]; then
            N_VARIANT="CoreGApps"
        elif [[ "${GAPPS_VARIANT}" == "extra" ]]; then
            N_VARIANT="CoreGApps"
        else
            N_VARIANT="GApps"
        fi
    else
        N_VARIANT="Vanilla"
    fi

    N_DATE=$(cat $DIR_ROOT/out/build_date.txt)
    N_SIZE=$(wc -c $R_FILE | awk '{print $1}')

    N_NUM_D=$(cat $DIR_LOG/$LOG_BUILD | grep "build completed successfully" | cut -d " " -f 5 | sed "s/(//g")
    N_STR_D=$(cat $DIR_LOG/$LOG_BUILD | grep "build completed successfully" | cut -d " " -f 6 | sed "s/(//g" | sed "s/)//g")

    N_MSG="⭕️ <b>BananaDroid Build Completed</b> ⭕️
▫️ <b>Device:</b> <code>${TARGET_DEVICE} (${TARGET_CODE})</code>
▫️ Variant: <code>${N_VARIANT}</code>
▫️ Version: <code>${ROM_BRANCH}</code>
▫️ Date: <code>${N_DATE}</code>
▫️ Filename: <code>${N_NAME}</code>
▫️ MD5: <code>${N_MD5}</code>
▫️ Size: <code>${N_SIZE}</code>
▫️ Maintainer: <code>${ROM_MAINTAINER}</code>
▫️ Duration: <code>${N_NUM_D} (${N_STR_D})</code>
▫️ Download: <a href=\"${DL_LINK}\">Here</a>"

    curl -s -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" -d chat_id="${TG_SUCCESS}" -d "disable_web_page_preview=true" -d "parse_mode=html" -d text="${N_MSG}"
}

set_gapps() {
    export WITH_GAPPS=true

    case "${GAPPS_VARIANT}" in
        "core")
            export BUILD_CORE_GAPPS=true
            unset TARGET_USE_GOOGLE_TELEPHONY
            ;;
        "extra")
            export BUILD_CORE_GAPPS=true
            export TARGET_USE_GOOGLE_TELEPHONY=true
            ;;
        *)
            unset BUILD_CORE_GAPPS
            unset TARGET_USE_GOOGLE_TELEPHONY
            ;;
    esac
}

sync_source() {
    clear
    cd $DIR_ROOT
    echo "=================================================="
    echo "                Getting ROM Source"
    echo "=================================================="
    set -exv

    if [ ! -d $DIR_ROOT/$DIR_MANIFEST ]; then
        echo ":: Initialize repo"
        repo init --depth=1 --no-repo-verify -u $ROM_MANIFEST -b $ROM_BRANCH -g default,-mips,-darwin,-notdefault --git-lfs
    fi

    if [ ! -z "${LOCAL_MANIFEST}" ]; then
        if [ -d $DIR_ROOT/$DIR_MANIFEST ]; then
            rm -rf $DIR_ROOT/$DIR_MANIFEST
        fi

        git clone --depth=1 $LOCAL_MANIFEST $DIR_MANIFEST
    fi

    echo ":: Cloning source"
    repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags --optimized-fetch --prune
}

sync_tree() {
    clear
    cd $DIR_ROOT
    echo "=================================================="
    echo "               Getting Device Trees"
    echo "=================================================="
    set -exv

    if [ ! -d $DIR_ROOT/$DEVICE_PATH ]; then
        git clone $DEVICE_URL -b $DEVICE_BRANCH $DEVICE_PATH
    else
        cd $DIR_ROOT/$DEVICE_PATH
        if ! git diff --quiet origin/$DEVICE_BRANCH; then
            git pull --rebase
        fi
    fi

    cd $DIR_ROOT
    if [ ! -z $COMMON_URL ] ; then
        if [ ! -d $DIR_ROOT/$COMMON_PATH ]; then
            git clone $COMMON_URL -b $COMMON_BRANCH $COMMON_PATH
        else
            cd $DIR_ROOT/$COMMON_PATH
            if ! git diff --quiet origin/$COMMON_BRANCH; then
                git pull --rebase
            fi
        fi
    fi

    cd $DIR_ROOT
    if [ ! -d $DIR_ROOT/$KERNEL_PATH ]; then
        git clone $KERNEL_URL -b $KERNEL_BRANCH $KERNEL_PATH
    else
        cd $DIR_ROOT/$KERNEL_PATH
        if ! git diff --quiet origin/$KERNEL_BRANCH; then
            git pull --rebase
        fi
    fi

    cd $DIR_ROOT
    if [ ! -d $DIR_ROOT/$VENDOR_PATH ]; then
        git clone $VENDOR_URL -b $VENDOR_BRANCH $VENDOR_PATH
    else
        cd $DIR_ROOT/$VENDOR_PATH
        if ! git diff --quiet origin/$VENDOR_BRANCH; then
            git pull --rebase
        fi
    fi

    cd $DIR_ROOT
    if [ ! -z $VCOMMON_URL ]; then
        if [ ! -d $DIR_ROOT/$VCOMMON_PATH ]; then
            git clone $VCOMMON_URL -b $VCOMMON_BRANCH $VCOMMON_PATH
        else
            cd $DIR_ROOT/$VCOMMON_PATH
            if ! git diff --quiet origin/$VCOMMON_BRANCH; then
                git pull --rebase
            fi
        fi
    fi

    sleep 2
}

upload_rom() {
    clear
    cd $DIR_ROOT
    echo "=================================================="
    echo "                  Uploading ROMS"
    echo "=================================================="
    set -exv

    # Atiga
    R_FILE=$(cat $DIR_LOG/$LOG_BUILD | grep "Package Complete" | cut -d " " -f 6)
    R_NAME=$(echo $R_FILE | cut -d "/" -f 5)

    if [ -z $R_FILE ]; then
        exit 1
    fi

    R_SIZE=$(wc -c $R_FILE | awk '{print $1}')
    if [ $R_SIZE -gt 1073741824 ]; then
        R_SIZE=$(bc <<<"scale=2; $R_SIZE / 1073741824")
        R_SIZE="$R_SIZE GB"
    else
        R_SIZE=$(bc <<<"scale=0; $R_SIZE / 1048576")
        R_SIZE="$R_SIZE MB"
    fi

    DL_LINK=$(wtclient upload $DIR_ROOT/$R_FILE)
    DL_LINK=$(echo $DL_LINK | cut -d " " -f 5)

    sleep 2
}

set_gapps

if [[ "${BUILD_GAPPS}" == 1 ]]; then
    if [[ "${GAPPS_VARIANT}" == "core" ]]; then
        B_VARIANT="CoreGApps"
    elif [[ "${GAPPS_VARIANT}" == "extra" ]]; then
        B_VARIANT="CoreGApps"
    else
        B_VARIANT="GApps"
    fi
else
    B_VARIANT="Vanilla"
fi

B_MSG=" ⏳ <b>BananaDroid Build Started</b> ⏳
▫️ <b>Device:</b> <code>${TARGET_CODE}</code>
▫️ <b>Variant:</b> <code>${B_VARIANT}</code>"
curl -s -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" -d chat_id="${TG_FAILED}" -d "disable_web_page_preview=true" -d "parse_mode=html" -d text="${B_MSG}"

if [[ "${SYNC_SOURCE}" == 1 ]]; then
    sync_source | tee -a $DIR_LOG/$LOG_SYNC

    ERR_1=$(grep 'Cannot remove project' $DIR_LOG/$LOG_SYNC -m 1 || true)
    ERR_2=$(grep "^fatal: remove-project element specifies non-existent project" $DIR_LOG/$LOG_SYNC -m 1 || true)
    ERR_3=$(grep 'repo sync has finished' $DIR_LOG/$LOG_SYNC -m 1 || true)
    ERR_4=$(grep 'Failing repos:' $DIR_LOG/$LOG_SYNC -n -m 1 || true)
    ERR_5=$(grep 'fatal: Unable' $DIR_LOG/$LOG_SYNC || true)
    ERR_6=$(grep 'error.GitError' $DIR_LOG/$LOG_SYNC || true)
    ERR_7=$(grep 'error: Cannot checkout' $DIR_LOG/$LOG_SYNC || true)

    if [[ $ERR_1 == *'Cannot remove project'* ]]; then
        ERR_1=$(echo $ERR_1 | cut -d ":" -f 2 | tr -d ' ')
        rm -rf $ERR_1
    fi

    if [[ $ERR_2 == *'remove-project element specifies non-existent'* ]]; then
        exit 1
    fi

    if [[ $ERR_4 == *'Failing repos:'* ]]; then
        ERR_4=$(expr $(grep 'Failing repos:' $DIR_LOG/$LOG_SYNC -n -m 1 | cut -d ':' -f 1) + 1)
        ERR_4_2=$(expr $(grep 'Try re-running' $DIR_LOG/$LOG_SYNC -n -m 1 | cut -d ':' -f 1) - 1)
        FAIL_PATHS=$(head -h $ERR_4_2 $DIR_LOG/$LOG_SYNC | tail -n $ERR_4)
        for F_PATH in $FAIL_PATHS; do
            rm -rf $F_PATH
            P_PATH=$(echo $F_PATH | awk -F '/' '{print $NF}')
            rm -rf .repo/project-objects/*$P_PATH.git
            rm -rf .repo/projects/$F_PATH.git
        done
    fi

    if [[ $ERR_5 == *'fatal: Unable'* ]]; then
        FAIL_PATHS=$(grep 'fatal: Unable' $DIR_LOG/$LOG_SYNC | cut -d ':' -f 2 | cut -d "'" -f 2)
        for F_PATH in $FAIL_PATHS; do
            rm -rf $F_PATH
            P_PATH=$(echo $F_PATH | awk -F '/' '{print $NF}')
            rm -rf .repo/project-objects/*$P_PATH.git
            rm -rf .repo/project-objects/$F_PATH.git
            rm -rf .repo/projects/$F_PATH.git
        done
    fi

    if [[ $ERR_6 == *'error.GitError'* ]]; then
        rm -rf $(grep 'error.GitError' $DIR_LOG/$LOG_SYNC | cut -d ' ' -f 2)
    fi

    if [[ $ERR_7 == *'error: Cannot checkout'* ]]; then
        FAIL_PATHS=$(grep 'error: Cannot checkout' $DIR_LOG/$LOG_SYNC | cut -d ' ' -f 4 | tr -d ':')
        for F_PATH in $FAIL_PATHS; do
            rm -rf .repo/project-objects/$F_PATH.git
        done
    fi

    if [[ $ERR_3 == *'repo sync has finished'* ]]; then
        true
    else
        repo sync -c --no-clone-bundle --no-tags --optimized-fetch --prune --force-sync -j$(nproc --all)
    fi

    sleep 2
fi

if [[ "${SYNC_TREES}" == 1 ]]; then
    sync_tree
fi

build_rom

IS_ERROR=$(grep 'error:' $DIR_LOG/$LOG_BUILD -m 1 || true)

if [[ $IS_ERROR == *'error:'* ]]; then
    curl -F document=@"$DIR_ROOT/out/error.log" "https://api.telegram.org/bot${TG_TOKEN}/sendDocument?chat_id=${TG_FAILED}&caption=${TARGET_NAME}"

    exit 1
fi

IS_ERROR=$(grep 'FAILED:' $DIR_LOG/$LOG_BUILD -m 1 || true)

if [[ $IS_ERROR == *'FAILED:'* ]]; then
    curl -F document=@"$DIR_ROOT/out/error.log" "https://api.telegram.org/bot${TG_TOKEN}/sendDocument?chat_id=${TG_FAILED}&caption=${TARGET_NAME}"

    exit 1
fi

upload_rom

send_notif

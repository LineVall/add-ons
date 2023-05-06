#!/bin/bash

clear

# Rom information
export ROM_MANIFEST="https://github.com/SuperiorOS/manifest.git"
export ROM_NAME=$(echo $ROM_MANIFEST | cut -d "/" -f 4)
export ROM_BRANCH="thirteen"
export ROM_MAINTAINER="unsatifsed27"

# Device information
export TARGET_NAME="superior"
export TARGET_DEVICE="Redmi Note 10 Pro"
export TARGET_CODE="sweet"
export TARGET_COMMON="sm6150-common"
export TARGET_KERNEL="sm6150"

# Directories
export DIR_ROOT="$HOME/$TARGET_NAME"
export DIR_CACHE="$HOME/cache/$TARGET_NAME"
export DIR_LOG="$HOME/logs/$TARGET_NAME"
export DIR_MANIFEST=".repo/local_manifests"

if [ ! -d $DIR_ROOT ]; then
    mkdir -p $DIR_ROOT
fi

if [ ! -d $DIR_CACHE ]; then
    mkdir -p $DIR_CACHE
fi

if [ ! -d $DIR_LOG ]; then
    mkdir -p $DIR_LOG
fi

# Source extra
export DEVICE_PATH="device/xiaomi/$TARGET_CODE"
export DEVICE_BRANCH="superior"
export DEVICE_URL="https://github.com/UnsatifsedError/device_xiaomi_sweet.git -b $DEVICE_BRANCH"

export COMMON_PATH="device/xiaomi/$TARGET_COMMON"
export COMMON_BRANCH="superior"
export COMMON_URL="https://github.com/UnsatifsedError/device_xiaomi_sm6150-common.git -b $COMMON_BRANCH"

export KERNEL_PATH="kernel/xiaomi/$TARGET_KERNEL"
export KERNEL_BRANCH="semlohey"
export KERNEL_URL="https://github.com/UnsatifsedError/kernel_xiaomi_sm6150.git -b $KERNEL_BRANCH"

export VENDOR_PATH="vendor/xiaomi/$TARGET_CODE"
export VENDOR_BRANCH="telulas"
export VENDOR_URL="https://github.com/UnsatifsedError/vendor_xiaomi-sweet.git -b $VENDOR_BRANCH"

export VCOMMON_PATH="vendor/xiaomi/$TARGET_COMMON"
export VCOMMON_BRANCH="telulas"
export VCOMMON_URL="https://github.com/UnsatifsedError/vendor_xiaomi_sm6150-common.git -b $VCOMMON_BRANCH"

# Telegram information
export tg_token="6265753905:AAG_NGaJW9ZyGw2HZoQgKzmHErcCWWy4JAQ"
export tg_success="-1001807327703"
export tg_failed="-1001807327703"

# Additional information
export SCRIPT_START=$(date "+%Y%m%d-%H%M")
export LOG_FILE="${TARGET_NAME}-${SCRIPT_START}"

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
        -c|--clean-build)
            clean_build='true'
            unset fresh_build
            shift
            ;;
        -f|--fresh-build)
            fresh_build='true'
            unset clean_build
            shift
            ;;
        -g|--build-gapps)
            build_gapps='true'
            gapps_variant=$2
            shift 2
            ;;
        -i|--init)
            init_manifest='true'
            shift
            ;;
        -l|--local-manifest)
            use_local='true'
            LOCAL_MANIFEST_URL=$2
            shift 2
            ;;
        -r|--release)
            release='true'
            shift
            ;;
        -s|--sync-source)
            sync_source='true'
            shift
            ;;
        -t|--sync-tree)
            sync_tree='true'
            shift
            ;;
    esac
done

build_rom() {
    cd $DIR_ROOT

    B_START=$(date "+%Y-%m-%d %H:%M:%S")

    source build/envsetup.sh

    lunch banana_sweet-userdebug

    if [ -d $DIR_ROOT/out ]; then
        if [[ "${fresh_build}" == 'true' ]]; then
            rm -rf $DIR_ROOT/out
        elif [[ "${clean_build}" == 'true' ]]; then
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

    m banana -j$(nproc --all) | tee -a $DIR_LOG/build-$LOG_FILE.log

    B_FINISH=$(date "+%Y-%m-%d %H:%M:%S")
    IS_ERROR=$(grep 'FAILED:' $DIR_LOG/build-$LOG_FILE.log -m 1 || true)

    if [[ $is_error == *'FAILED:'* ]]; then
        curl -F document=@"out/error.log" "https://api.telegram.org/bot${tg_token}/sendDocument?chat_id=${tg_failed}&caption=${TARGET_NAME}"

        exit 1
    fi

    upload_rom

    notif_status
}

clone_source() {
    set -exv

    if [[ "${init_manifest}" == 'true' ]]; then
        repo init --depth=1 --no-repo-verify -u $ROM_MANIFEST -b $ROM_BRANCH -g default,-mips,-darwin,-notdefault --git-lfs
    fi

    if [ ! -z "$LOCAL_MANIFEST_URL" ]; then
        if [ -d "$DIR_ROOT/$DIR_MANIFEST" ]; then
            rm -rf $DIR_ROOT/$DIR_MANIFEST
        fi

        git clone $LOCAL_MANIFEST_URL --depth=1 $DIR_MANIFEST
    fi

    sync_log=$DIR_LOG/sync-$LOG_FILE.log
    repo sync -c --no-clone-bundle --no-tags --optimized-fetch --prune --force-sync -j8 | tee -a $sync_log

    if [[ $err_1 == *'Cannot remove project'* ]]; then
        err_1=$(echo $err_1 | cut -d ':' -f 2 | tr -d ' ')
        rm -rf $err_1
        repo sync -c --no-clone-bundle --no-tags --optimized-fetch --prune --force-sync -j$(nproc --all)
    elif [[ $err_2 == *'remove-project element specifies non-existent'* ]]; then
        exit 1
    elif [[ $err_3 == *'repo sync has finished'* ]]; then
        true
    elif [[ $err_4 == *'Failing repos:'* ]]; then
        err_4=$(expr $(grep 'Failing repos:' $sync_log -n -m 1 | cut -d ':' -f 1) + 1)
        err_4_2=$(expr $(grep 'Try re-running' $sync_log -n -m 1 | cut -d ':' -f 1) - 1)
        fail_paths=$(head -n $err_4_2 $sync_log | tail -n +$err_4)
        for path in $fail_paths; do
            rm -rf $path
            proj=$(echo $path | awk -F '/' '{print -NF}')
            rm -rf .repo/project-objects/$proj.git
            rm -rf .repo/projects/$path.git
        done
        repo sync -c --no-clone-bundle --no-tags --optimized-fetch --prune --force-sync -j$(nproc --all)
    elif [[ $err_5 == *'fatal: Unable'* ]]; then
        fail_paths=$(grep 'fatal: Unable' $sync_log | cut -d ':' -f 2 | cut -d "'" -f 2)
        for path in $fail_paths; do
            rm -rf $path
            proj=$(echo $path | awk -F '/' '{print -NF}')
            rm -rf .repo/project-objects/$proj.git
            rm -rf .repo/project-objects/$path.git
            rm -rf .repo/projects/$path.git
        done
        repo sync -c --no-clone-bundle --no-tags --optimized-fetch --prune --force-sync -j$(nproc --all)
    elif [[ $err_6 == *'error.GitError'* ]]; then
        rm -rf $(grep 'error.GitError' $sync_log | cut -d ' ' -f 2)
        repo sync -c --no-clone-bundle --no-tags --optimized-fetch --prune --force-sync -j$(nproc --all)
    elif [[ $err_7 == *'error: Cannot checkout'* ]]; then
        echo hi
        err_co=$(grep 'error: Cannot checkout' $sync_log | cut -d ' ' -f 4 | tr -d ':')
        for i in $err_co; do
            rm -rf .repo/project-objects/$i.git
        done
        repo sync -c --no-clone-bundle --no-tags --optimized-fetch --prune --force-sync -j$(nproc --all)
    elif [[ $err_8 == *'error: Downloading network changes failed.'* ]]; then
        repo sync -c --no-clone-bundle --no-tags --optimized-fetch --prune --force-sync -j4
    else
        exit 1
    fi
}

clone_tree() {
    if [ ! -d $DIR_ROOT/$DEVICE_PATH ]; then
        cd $DIR_ROOT
        git clone $DEVICE_URL $DEVICE_PATH
    else
        cd $DIR_ROOT/$DEVICE_PATH
        git remote update
        if ! git diff --quiet origin/$DEVICE_BRANCH; then
            git pull --rebase
        fi
    fi
    
    if [ ! -d $DIR_ROOT/$COMMON_PATH ]; then
        cd $DIR_ROOT
        git clone $COMMON_URL $COMMON_PATH
    else
        cd $DIR_ROOT/$COMMON_PATH
        git remote update
        if ! git diff --quiet origin/$COMMON_BRANCH; then
            git pull --rebase
        fi
    fi

    if [ ! -d $DIR_ROOT/$KERNEL_PATH ]; then
        cd $DIR_ROOT
        git clone $KERNEL_URL $KERNEL_PATH
    else
        cd $DIR_ROOT/$KERNEL_PATH
        git remote update
        if ! git diff --quiet origin/$KERNEL_BRANCH; then
            git pull --rebase
        fi
    fi

    if [ ! -d $DIR_ROOT/$VENDOR_PATH ]; then
        cd $DIR_ROOT
        git clone $VENDOR_URL $VENDOR_PATH
    else
        cd $DIR_ROOT/$VENDOR_PATH
        git remote update
        if ! git diff --quiet origin/$VENDOR_BRANCH; then
            git pull --rebase
        fi
    fi
    
    if [ ! -d $DIR_ROOT/$VCOMMON_PATH ]; then
        cd $DIR_ROOT
        git clone $VCOMMON_URL $VCOMMON_PATH
    else
        cd $DIR_ROOT/$VCOMMON_PATH
        git remote update
        if ! git diff --quiet origin/$VCOMMON_BRANCH; then
            git pull --rebase
        fi
    fi

    cd $DIR_ROOT
}

notif_status() {
    B_MSG="📢 Build Notification
==============================
📱 Device: <code>${TARGET_DEVICE} (${TARGET_CODE})</code>
⚙️ Rom Name: <code>${ROM_NAME}</code>
🔖 Branch: <code>${ROM_BRANCH}</code>
💽 Filename: <code>${R_NAME}</code>
⚖️Size: <code>${R_SIZE}</code>
🪪 Maintainer: <code>${ROM_MAINTAINER}</code>
🕑 Start: <code>${B_START}</code>
🕙 Finish: <code>${B_FINISH}</code>
📦 Download:<a href=\"${DL_LINK}\">Here</a>"

    curl -s -X POST "https://api.telegram.org/bot${tg_token}/sendMessage" -d chat_id="${tg_success}" -d "disable_web_page_preview=true" -d "parse_mode=html" -d text="${B_MSG}"
}

upload_rom() {
    R_FILE=$(cat $DIR_LOG/build-$LOG_FILE.log | grep "Package zip" | cut -d " " -f 6)
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
}

if [[ "${build_gapps}" == 'true' ]]; then
    export WITH_GAPPS=true

    case "${gapps_variant}" in
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
fi

cd $DIR_ROOT

if [[ "${sync_source}" == 'true' ]]; then
    clone_source
fi

if [[ "${sync_tree}" == 'true' ]]; then
    clone_tree
fi

build_rom

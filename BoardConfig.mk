#
# Copyright (C) 2022 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

DEVICE_PATH := device/infinix/Infinix-X6882

# Inherit from mt6789-common
include device/transsion/mt6789-common/BoardConfigCommon.mk

# Assert
TARGET_OTA_ASSERT_DEVICE := Infinix-X6882

# Brightness
override TW_DEFAULT_BRIGHTNESS := 2047
override TW_MAX_BRIGHTNESS := 4095

# Init
TARGET_INIT_VENDOR_LIB := libinit_Infinix-X6882
TARGET_RECOVERY_DEVICE_MODULES := libinit_Infinix-X6882

# TWRP Configs
TW_DEVICE_VERSION := X6882_by_rama982

# ---------------------------------------------------------------------------
# Android 14 .. 17+ forward compatibility
#
# The device ships a Trustonic KeyMint AIDL v1 HAL and a Gatekeeper 1.0 HIDL
# HAL, both byte-identical to the OP-250908V1487 vendor image.  vold and
# keystore2 refuse to unwrap a /data key when the build's security patch or
# OS release looks older than the values recorded in the metadata, so the
# build-time values and the runtime properties are both pinned to sentinels.
# The runtime half lives in recovery/root/init.recovery.mt6789.rc.
#
# override: BoardConfigCommon.mk and the product makefile chain both assign
# these, so override is what guarantees this file has the last word.
override PLATFORM_SECURITY_PATCH := 2099-12-31
override VENDOR_SECURITY_PATCH := $(PLATFORM_SECURITY_PATCH)
override BOOT_SECURITY_PATCH := $(PLATFORM_SECURITY_PATCH)
override PLATFORM_VERSION := 99.87.36
override PLATFORM_VERSION_LAST_STABLE := $(PLATFORM_VERSION)

# FBEv2 + metadata encryption (wrapped keys live in /metadata/vold)
TW_INCLUDE_CRYPTO := true
TW_INCLUDE_CRYPTO_FBE := true
TW_INCLUDE_FBE_METADATA_DECRYPT := true
BOARD_USES_METADATA_PARTITION := true
TW_FORCE_KEYMASTER_VER := true

# Filesystems for the dynamic partitions and /data
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true
BOARD_HAS_LARGE_FILESYSTEM := true

# Recovery tools
TW_INCLUDE_FASTBOOTD := true
TW_INCLUDE_REPACKTOOLS := true
TW_INCLUDE_RESETPROP := true
TW_EXCLUDE_APEX := true

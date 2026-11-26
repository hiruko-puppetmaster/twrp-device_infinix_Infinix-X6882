# Building and verifying `vendor_boot.img`

Recovery for the X6882 is a second ramdisk fragment inside `vendor_boot`.  The
kernel is **not** in this image: `boot.img` carries the GKI kernel, and
`vendor_boot.img` carries two ramdisk fragments.

| fragment | type | contents | source |
|---|---:|---|---|
| platform | 1 | MTK first-stage ramdisk (`/first_stage_ramdisk`: `e2fsck`, `snapuserd`, linker and libs) | AOSP vendor ramdisk + `device/transsion/mt6789-common/recovery/root/first_stage_ramdisk` |
| recovery | 2 | TWRP 12.1 recovery ramdisk (`system/bin/recovery`, `fastbootd`, 213 `.ko`) | the two device trees |

The recovery fragment's modules are retargeted to the boot kernel's
`UTS_RELEASE`; see `MODULES.md`.

## Source tree

```sh
mkdir -p ~/twrp && cd ~/twrp
repo init -u https://github.com/minimal-manifest-twrp/platform_manifest_twrp_aosp -b twrp-12.1
repo sync -j"$(nproc)"

git clone https://github.com/transsion-mt6789/twrp-device_infinix_Infinix-X6882.git \
    -b fox_12.1 device/infinix/Infinix-X6882
git clone https://github.com/transsion-mt6789/twrp-device_transsion_mt6789-common.git \
    -b fox_12.1 device/transsion/mt6789-common
```

The working copy of `device/infinix/Infinix-X6882` must contain the changes
described below (security sentinels, retargeted modules, `MODULES.md`,
`tools/retarget_vermagic.py`) and the common tree the AIDL keymint declaration
and fstab flags.  Do not rename `Infinix-X6882`.

## Build

```sh
source build/envsetup.sh
lunch twrp_X6882-eng
mka vendorbootimage -j"$(nproc)"
```

Output: `out/target/product/Infinix-X6882/vendor_boot.img`.

## Size budget (measured)

The device's current image and the stock `OP-250908V1487` image were parsed
with a v4 parser and with `magiskboot`; both agree on this layout.

| Section | Bytes |
|---|---:|
| v4 header (2,128 B, page padded) | 4,096 |
| platform fragment (LZ4) | 2,689,186 |
| recovery fragment (LZ4; shipped 48,159,435, local repack 48,166,872) | ~48,160,000 |
| DTB (`prebuilt/dtb.img`: 64 B MTK header + 212,029 B FDT) | 212,093 |
| ramdisk table (2 entries x 108 B) | 216 |
| **content, page padded** | **51,073,024** |
| AVB vbmeta (only if a vendor_boot footer is added) | 640 |
| **partition size / limit** | **67,108,864** |
| **headroom** | **16,035,200** |

The local repack of the extracted recovery root (`cpio -H newc` then
`lz4 -l -12`) produced 48,166,872 B, 7,437 B (+0.015%) over the shipped
fragment, so the fragment size is reproducible.  The module retarget changes
only the `vermagic=` string inside `.modinfo` and keeps every section size, so
it does not change the budget.

`BOARD_DTB_SIZE := 209018` in `BoardConfigCommon.mk` is stale (the prebuilt
DTB is 212,093 B), but AOSP's `core/Makefile` does not read it for
vendor_boot; `--dtb $(TARGET_PREBUILT_DTB)` uses the file size.  Leave it.

## Verify before flashing

```sh
IMG=out/target/product/Infinix-X6882/vendor_boot.img
stat -c '%s' "$IMG"                 # must be <= 67108864
sha256sum "$IMG"

rm -rf /tmp/vbcheck && mkdir /tmp/vbcheck && cd /tmp/vbcheck
cp "$IMG" vendor_boot.img
magiskboot unpack -h vendor_boot.img
# expect: HEADER_VER [4], PAGESIZE [4096], DTB_SZ [212093],
#         RAMDISK_SZ about 50848621, RAMDISK_FMT [raw]
sha256sum dtb
# 7a448812193b5fd93683637e47f64f1062d1160a148401fe193dd5c9e80139da

lz4 -d -c ramdisk.cpio > ramdisk.raw
mkdir root && cd root && cpio -idm < ../ramdisk.raw

grep -c first_stage_mount system/etc/recovery.fstab                  # 12
grep -c wrappedkey_v0 system/etc/recovery.fstab                      # 1
grep -c 'resetprop ro.build.version.security_patch 2099-12-31' \
    init.recovery.mt6789.rc                                          # 1
grep -c 'interface aidl android.hardware.security.keymint.IKeyMintDevice/default' \
    init.recovery.mt6789.rc                                          # 1

for k in lib/modules/*.ko vendor/lib/modules/*.ko; do
    modinfo -F vermagic "$k"
done | sort -u
# exactly one line:
# 5.10.274-android12-9-Satetsu-Shigure SMP preempt mod_unload modversions aarch64
```

`magiskboot` writes the concatenation of both fragments to `ramdisk.cpio`, so
the extracted root merges the platform and recovery files.  That is fine for
the checks above; the fstab, `init.recovery.mt6789.rc` and modules all come
from the recovery fragment.

## Runtime guards

Build-time sentinels live in `BoardConfig.mk`:

```make
override PLATFORM_SECURITY_PATCH := 2099-12-31
override VENDOR_SECURITY_PATCH := $(PLATFORM_SECURITY_PATCH)
override BOOT_SECURITY_PATCH := $(PLATFORM_SECURITY_PATCH)
override PLATFORM_VERSION := 99.87.36
override PLATFORM_VERSION_LAST_STABLE := $(PLATFORM_VERSION)
```

The same values are pushed at runtime by `on early-init` in
`device/transsion/mt6789-common/recovery/root/init.recovery.mt6789.rc`:

```rc
exec - root -- /system/bin/resetprop ro.build.version.security_patch 2099-12-31
exec - root -- /system/bin/resetprop ro.vendor.build.security_patch 2099-12-31
exec - root -- /system/bin/resetprop ro.build.version.release 99.87.36
```

`exec - root --` is valid init syntax (`-` means the default seclabel).  The
binary is the ramdisk's `/system/bin/resetprop`, which links `libresetprop.so`
from `/system/lib64`, and it runs before `vold` is started in `on early-fs`.

## Not verified here

- No full TWRP source tree and no `repo` in this environment, so
  `mka vendorbootimage` was not run.  The numbers above come from the
  device's existing image, the stock image, and a local ramdisk repack.
- No device access: boot, touch and FBEv2 decryption are untested.
- AVB: stock and dumped images are padded to 67,108,864 B and carry a 640 B
  vbmeta blob plus a 64 B AVB footer.  A plain `mkbootimg` output is
  unpadded and unsigned.  If the bootloader verifies `vendor_boot`,
  verification must be disabled for a custom image; that is a device-side
  step, not part of this build.

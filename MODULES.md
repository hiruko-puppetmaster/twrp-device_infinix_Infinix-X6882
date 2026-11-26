# Recovery kernel modules

`recovery/root/lib/modules` (210 files) and `recovery/root/vendor/lib/modules`
(3 touch drivers) are vendor modules built by Infinix/MediaTek for this device.
There is no vendor module source in the ACK tree, so they cannot be rebuilt
against a new GKI release. Their vermagic is therefore rewritten in place to
match the kernel that actually boots recovery.

## Provenance (measured)

| Set | Modules | vermagic |
|---|---:|---|
| this tree, as committed upstream | 210 | `5.10.226-android12-9-g08580a1e9742-dirty` |
| device `vendor_boot.img` recovery fragment | 213 | same, plus 3 touch drivers |
| device `vendor_dlkm.img` | 210 | same 207 + three stale `4.19.191+` GC modules |
| stock ROM `OP-250908V1487` | 210 | `5.10.226-android12-9-gf749d7d4fcd4-dirty` |

The device runs the `g08580a1e9742` build, so this tree is not stale relative
to the device; the newer `OP-250908` dump is a different firmware branch and
was deliberately not imported.

## Why the vermagic is rewritten

The active GKI kernel is:

```
5.10.274-android12-9-Satetsu-Shigure SMP preempt mod_unload modversions aarch64
```

The modules carry `5.10.226-...`, and the kernel compares vermagic verbatim
(`kernel/module.c:check_modinfo`). `CONFIG_MODULE_SIG` is off and
`CONFIG_MODULE_FORCE_LOAD=y`, so the release string is the only blocker.

The rewrite is safe because the GKI KMI is preserved. Measured against the
kernel's own `vmlinux.symvers`:

- 1,726 distinct kernel-provided symbols imported by these modules: **0 CRC
  mismatches**.
- 651 module-to-module imports resolve inside the shipped set.
- 1 pre-existing unresolved symbol, `mtk_drm_gateic_set_backlight`, imported
  by `leds-mtk-disp.ko`. It is unresolved in the stock image too; that module
  fails to load on stock as well.

Only the `vermagic=` release substring inside `.modinfo` is changed. The
section keeps its size, the ` SMP preempt mod_unload modversions aarch64`
suffix is preserved, and `__versions` / `__ksymtab` / `__kcrctab` are
byte-identical (verified for all 213 modules).

## Re-targeting

If the boot kernel changes, rewrite the modules to its `UTS_RELEASE`:

```sh
python3 tools/retarget_vermagic.py \
    "5.10.274-android12-9-Satetsu-Shigure" \
    "<new-uts-release>" \
    recovery/root/lib/modules \
    recovery/root/vendor/lib/modules
```

The new string must not be longer than the old one (40 characters for the
`g08580a1e9742-dirty` build).

Verify with `modinfo -F vermagic` on every file; all of them must print the
same string. Never mix two vermagic strings in one module directory.

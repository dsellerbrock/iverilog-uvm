# IEEE 1800 VPI header comparison

This is a source-level comparison of the normative VPI macro definitions in IEEE 1800-2017 and 1800-2023 against the pinned Icarus 13.0-devel public headers built from source commit `fb584a251dd4cc91e56a75be662ccd5ee05c64e9`.

The standards identify Annex K as `vpi_user.h` and Annex M as `sv_vpi_user.h` (confirmed in each annex heading and include line). Annex K was compared to the pinned `vpi_user.h`. Annex M adds definitions to Annex K, so its own `vpi*`/`cb*` definitions were compared against the combined pinned `vpi_user.h` + `sv_vpi_user.h` macro set. PLI and include-guard macros are outside this VPI-constant comparison.

Normative PDF page ranges extracted with `pdftotext -layout`:

- 2017 Annex K: PDF pages 1269–1285; Annex M: 1289–1298.
- 2023 Annex K: PDF pages 1307–1323; Annex M: 1327–1337.

The extracted four source texts, byte-identical copies of both pinned headers and their `_pli_types.h` dependency are preserved here. Header SHA-256 values match the files at `/home/dsell/toolchains/iverilog-fb584a25-20261020/include/iverilog/` on DAN-DESKTOP. The active macro maps were produced with Apple Clang 21.0.3 using `cc -dM -E -x c -I <this-directory> -include vpi_user.h /dev/null` and the same command with `sv_vpi_user.h`; the latter expands the base-header include.

Run the argument-driven comparator outside this evidence directory, with the working directory set to this evidence folder:

```sh
python3 /tmp/compare_vpi_annex.py \
  --annex-k-2017 annexK_2017.txt --annex-k-2023 annexK_2023.txt \
  --annex-m-2017 annexM_2017.txt --annex-m-2023 annexM_2023.txt \
  --vpi-header vpi_user.macros.txt --sv-header sv_vpi_user.macros.txt --output comparison.txt
```

The comparator includes assert-based checks for PDF line parsing and numeric alias evaluation. It evaluates integer and simple VPI alias/bitwise values, then reports same-name differences, missing standard names, and Icarus-only names. The report is macro-table evidence only; absent public macros do not by themselves establish missing runtime behavior.

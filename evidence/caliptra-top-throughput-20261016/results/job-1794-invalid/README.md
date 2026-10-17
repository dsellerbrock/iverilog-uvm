# Invalid throughput attempt 1794

All 18 fixed-window samples completed, but the analyzer rejected them because the Caliptra runner generated fresh ECC files `secp384_testvector.hex` and `secp384_testvector_all.hex` on each invocation. They differed across the base/main builds and repeats; the remaining 37 generated `.hex` files matched, and the captured simulator logs matched after removing only the mcycle marker. No rates from this job are accepted. Job 1794 output, sample logs, window markers, resource records, and hashes are preserved here. The next run uses the already campaign-qualified fixed-entropy ECC generator from attempt 1420.
Pinned measurement base: `f9f8e0a79f230f38da6cbb4445994ad1075ad531`; main snapshot: `7f508a8a3ab4f1a230d65abfa2543a12ca2f40a9`.

# IEEE 1800 §19.11.3 type-coverage probe — raw result, classification pending

**Standard:** IEEE 1800-2017 §19.11.3, pp. 588–590; IEEE 1800-2023 §19.11.3. The probe is the lead's exact AVG/MRG/WGT/ATL/AUTO reducer.

**Related option rules checked:** IEEE 1800-2017 §19.7, pp. 578–579, and 2023 §19.7, pp. 605–606. Table 19-1 identifies weight, at_least, auto_bin_max, and get_inst_coverage as instance-specific options. Option assignments in a covergroup definition are evaluated when the instance is created; the standard's example passes a covergroup constructor parameter to option.weight. Table 19-1 says get_inst_coverage defaults to zero and then its method result equals get_coverage; when enabled with merge_instances, it tracks individual instances.

**Probe:** tests/1800_audit/c19/p19_11_3_type_cov.sv. Each compile and runtime process used a 30-second timeout. The source is unchanged from the lead-provided reducer.

**Environment:** Slurm host DAN-DESKTOP; job 3419; 1 CPU, 1 GiB, 10-minute limit. Pinned current-main Icarus 13.0-devel cc25756d1. Executable and input hashes are in SHA256SUMS.

**Commands:** for each edition, compile iverilog -g<edition> -o <image> input/p19_11_3_type_cov.sv, then run vvp <image>, both wrapped by input/run_with_timeout.py 30 -- ... .

**Exit status:** compile and runtime exit code 0 in both editions.

**Raw stdout, identical in -g2017 and -g2023:**

    sorry: covergroup option 'at_least' is not a constant; using default 1.
    sorry: covergroup option 'auto_bin_max' is not a constant; using default 64.
    AVG  type=75.00 i1=100.00 i2=50.00
    MRG  type=66.67 i1=66.67 i2=66.67
    WGT  type=87.50
    ATL1 type=100.00 l1inst=100.00
    ATL2 type=100.00
    AUTO type=1.56 cov=0 tot=0

**Initial comparison with lead expectations:** AVG type and WGT type match. MRG type matches, but per-instance readings are both 66.67. Since the probe leaves option.get_inst_coverage at its default 0, §19.7 says this output equals get_coverage; a rerun with option.get_inst_coverage=1 is needed before judging per-instance values. The at_least and auto_bin_max constructor arguments fall back to defaults with the two exact sorry diagnostics above, so ATL1 and AUTO do not test their intended values. The option assignments are in the covergroup definition and their expressions are evaluated at instantiation under §19.7; classification of these diagnostics/behaviors is pending lead review. AUTO also reports cov=0 tot=0, but its type percentage is not the expected 2.08 with the configured 64:32 bins, so the lead's condition for commenting on #622 is not yet met.

**Dedupe:** pre-probe and post-probe open/closed searches are recorded in dedupe-open-closed.txt. Related issues #627, #622, #696, #686, and #513 were reviewed. No new issue has been filed pending lead classification.

# IEEE 1800 §19.7 / §19.11.3 follow-up reducers — raw results

**Standard:** IEEE 1800-2017 §19.7 pp.578–579 and §19.11.3 pp.588–590; IEEE 1800-2023 §§19.7 and 19.11.3. Section 19.7 evaluates definition option assignments when the covergroup instance is created. Its instance-specific table includes weight, at_least, auto_bin_max, and get_inst_coverage; its example uses a constructor formal for option.weight.

**Environment:** Slurm host DAN-DESKTOP; job 3420; 1 CPU, 1 GiB, 10-minute limit. Current-main Icarus 13.0-devel cc25756d1; both editions. Executable, inputs, and timeout harness hashes are in SHA256SUMS. Each compile/runtime process used a 30-second timeout.

**Exit status:** both probes compiled and ran with exit code 0 in -g2017 and -g2023.

**p19_07_option_args raw output, both editions:**

Compile diagnostics:

    sorry: covergroup option 'at_least' is not a constant; using default 1.
    sorry: covergroup option 'auto_bin_max' is not a constant; using default 64.
    sorry: covergroup option 'auto_bin_max' is not a constant; using default 64.

Runtime:

    ATL_ARG2 100.00 ATL_LIT2 0.00
    ATL_ARG3 100.00 ATL_LIT3 100.00
    ABM_CG_ARG 1.56 ABM_CP_ARG 1.56 ABM_LIT 25.00

Constructor-argument at_least falls back to 1 rather than 3. Both covergroup-level and coverpoint-level constructor-argument auto_bin_max fall back to 64 rather than 4. Literal controls work. Constructor-argument option.weight worked in the first probe.

**p19_11_3_type_cov_r2 raw output, both editions:**

    AVG  type=75.00 i1=100.00 i2=50.00
    MRG  type=66.67 i1=100.00 i2=50.00
    WGT  type=87.50
    AUTO type=4.69 cov=0 tot=0

The corrected merge instance readings and type percentage match expectations. AUTO's percentage is 3/64 as expected; get_coverage(ref,ref) leaves both outputs at zero, satisfying the lead's condition to comment on #622. The lead authorized, and A3 posted, the evidence comment at https://github.com/dsellerbrock/iverilog-uvm/issues/622#issuecomment-6293672271; no separate issue was opened for the covered behavior.

**Issue review:** see dedupe-open-closed.txt for the #689 body grep and exact closed/open search. The grep found a definition-only restriction on auto_bin_max placement, but no statement that its RHS must be constant. The search for the exact not-a-constant covergroup wording returned empty. No issue has been filed pending lead decision.

# IEEE 1800 §18.5.4 distribution probe

- Standard sections: IEEE 1800-2017 §18.5.4 (p. 512–513); IEEE 1800-2023 §18.5.3, “Distribution” (heading confirmed with `pdftotext`).
- Probe plan from the 1800-audit lead: 37,401 randomizations per edition across D1–D7; reject `dist` on `randc` and non-random variables.
- Source checkout: branch `m7-1800-audit-c08`, commit `27f53df24`, dirty before this probe; staged immutable inputs are in `input/`.
- Slurm host: DAN-DESKTOP. Compiler: `/home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb/bin/{iverilog,vvp}`, Icarus 13.0-devel commit `cc25756d1`. Job requests 1 CPU, 1 GiB, 6 minutes; each compile/run process is limited to 30 seconds with a process-group timeout.
- Open/closed issue searches and raw results: `dedupe-open-closed.txt`.
- The searches surfaced closed issue #12, which tracks broad `dist` weighting support and a later §11.8.2 subject-expression follow-up; the lead will decide whether any observed gap belongs as a comment there or is a distinct issue.
- Job 3431 compiled all files in both editions. It rejected `randc dist` but accepted the non-`rand` negative in both editions. The combined positive simulation exceeded the required 30-second process limit after reporting D1/D2 counts (2017 and 2023: D1 1020/1985/4995, D2 1007/0/4993; all `other=0`); D3–D7 are not assessed in this attempt. Full raw output, diagnostics, and hashes are in `remote-results/`.
- A follow-up splits the runtime suite into seven independently timed cases and removes unrelated static-initialization warnings.

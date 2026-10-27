# §18.17 randsequence production probe

Lead-directed both-edition probe based on the standard's production weights, if–else, case, and repeat examples (2017 §§18.17.1–18.17.4, pp. 545–547; 2023 §§18.17.1–18.17.4). The `if` oracle was corrected to expect depth 2 after six calls: push, push, pop, push, pop, push.

The weighted production uses 500 samples and a four-standard-deviation acceptance interval. The case and repeat checks are deterministic. The negative probe has two defaults in one case production, which §18.17.3 says is illegal. Compile and runtime processes use 30-second timeouts. The Slurm script uses the pinned current-main Icarus toolchain.

No issue is filed from this tranche until raw results are reviewed and the audit lead classifies the result.

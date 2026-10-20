# Slurm job 3569: setup failure, no samples

Pinned source: `fb584a251dd4cc91e56a75be662ccd5ee05c64e9`.

Job 3569 stopped before either build. Its `--shared` clone borrowed objects from the archived profile source, which is a partial clone, but the new clone had no promisor remote configuration. Checkout therefore left promised tracked blobs absent and the clean-source check failed. No performance or correctness result was produced. The checkout and submodule logs are retained here. Job 3570 uses the same pinned source with the GitHub promisor remote configured before checkout.

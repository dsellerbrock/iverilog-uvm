# Attempt 1615

This attempt is not a profile result. It built the pinned source and installed
the Caliptra window VPI plugin, then exited with code 2 before simulation.
The runner reported that the output directory already existed because the
batch script created `output/main` before calling it. The corrected script
creates only the parent directory and asserts that `output/main` is absent
before launch. Job log and the exact submitted script are preserved here.

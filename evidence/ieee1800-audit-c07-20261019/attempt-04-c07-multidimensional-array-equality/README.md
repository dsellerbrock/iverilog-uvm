# Clause 7.4 multidimensional equality attempt (invalid probe)

Slurm job 3224 ran against the pinned Icarus toolchain, but this attempt does
not establish multidimensional array equality behavior. The probe used chained
assignment to two unpacked array elements, which Icarus rejected as invalid
syntax before reaching the equality expressions. The batch condition also had
a shell bracket typo and reported the compile failure as inconclusive. Do not
use this run to classify §7.4.

The positive controls in this run passed: packed/unpacked array indexing and
copy, array slicing, one-dimensional unpacked equality, and dynamic-array
allocation/copy/size/delete passed in both editions. These controls are
reproduced with corrected exact-source capture in adjacent attempts.

```text
Slurm job  3224
results-3224.tar.gz  40450419f334fcb9d0233b95a0fff4a3f232451ce60cb6bb6dc03b3ad089798e
input/probes.tar.gz  ff76339eb0df6b1489e6f09add4e2135bc34c29a4a10c3263e99eae412dba3c6
run.sbatch  34665f562f8dd354308e152893132e8a439b653452fe5c0be127120b68d023cf
```

# IEEE 1800 clause 19.7 probe

The probe targets common coverage options in 2017/2023, the 2023-only
`real_interval` and `cross_retain_auto_bins` options, duplicate-option
rejection, and rejection of an instance option used as a type option.

Standards references: IEEE 1800-2017 §19.7 pp. 577–581; IEEE 1800-2023
§19.7–§19.7.1 pp. 605–609. The 2023-only options are listed in Table 19-1
(`cross_retain_auto_bins`) and Table 19-3 (`real_interval`).

The frozen inputs and run script are in this directory. Results are recorded
under `results/` after the Slurm probe completes.

Slurm job 2996 failed after 1 second (`ExitCode=1:0`) before any compiler
probe ran. The script attempted to hash `input/*.sv`, but the submitted
archive was in the run root and was never extracted. The recorded
`expected-rejection` statuses are false positives caused by the missing input
files, not standards results. The remote log was copied to `results/logs/`;
its SHA-256 is `0274a9c301d8cb2bcec1bff92e88ce9def7458d55c107af838ec05a9f48f1282`.
The complete raw output bundle is `results-2996.tar.gz` (SHA-256
`adf6fcff8444fc17ba7675787c99d15b790383c5cb5d7460dc9fa5b2f48150e7`); the
frozen probe archive SHA-256 was
`2d38d96306b6c335ea843befce8eda9961fe5d6f1e6ca060c22bdc14983ad1ea`.

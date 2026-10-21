# #671 T0/T1 with the #663 regression

- PR: #729, updated to include a focused regression for merged issue #663.
- Tested source commit: `d09d61a310f6bb39e8015161f8438c299b5112e5`.
- Slurm job 3266 on DAN-DESKTOP: `COMPLETED`, `ExitCode=0:0`, 2 CPUs / 3 GiB, 3:57 elapsed, 45-minute limit.
- Source archive excludes `evidence/`; SHA-256: `cb73bfa16a6d2046fbb247364a8a7509e8335d4266f483794c40aa3e924384b9`.
- T0 covers the #671 2017/2023 issue reproducers and the smoke set. T1 covers the Chapter 7 dynamic-array focus and class-parameterization focus, including the new #663 regression in legacy and JSON 2017/2023 modes.
- T0: issue reproducers passed 2/2 in legacy and 2/2 in JSON; smoke script exited 0. The smoke output includes its existing `PASS #544` check for the expected compile-time rejection.
- T1: Chapter 7 legacy 91/91 and JSON 84/84; class-parameter focus legacy 24/24 and JSON 18/18. The #663 source passed in legacy, 2017 JSON, and 2023 JSON.
- Build peak RSS: 1,671,592 KiB. Installed `iverilog` SHA-256 `a4bd3e1e29b86db17171137f504326b8e9f72e01b6b0e8eaa21a6fd5829581c1`; `vvp` SHA-256 `28c67d056e813dafbb5c7722f03e7e8b8ee060c832d7e24acc3cd86cfab70930`.
- Regression source SHA-256: `bb66921f3cb69c14f5cfcd3d31236c8c2221a8b23ef7c450c561632af3cef552`; Slurm script SHA-256: `e2c1fbb52adb192595caecbf5dc4de4cd02bc6c6d4d39e9571a27d4479bfd038`.
- All copied result and job logs passed `shasum -a 256 -c results/SHA256SUMS.remote`.

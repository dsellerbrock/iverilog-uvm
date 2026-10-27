# §23.11 checker bind

IEEE 1800-2017 and IEEE 1800-2023 §23.11 permit binding checker
instantiations into a module scope or instance. Probe:
[`sv_checker_bind.v`](../../../ivtest/ivltests/sv_checker_bind.v).

Both editions compile and run with `-s main`; each prints `PASSED`, verifying
that the bound checker instance detects the expected assertion violation.

# §18.5.8 rerun after probe self-check correction

Attempt 1 exposed a test-harness defect: the local reduction accumulator used `int s = 0` inside a static-lifetime `initial` block, so it initialized only once and accumulated across the 20 randomization iterations. Attempt 2 resets a module variable before every measured sum. The original inputs and logs remain at the evidence root.

The two negative cases are rerun unchanged. Both editions, with the same current-main toolchain and 20-second process-group timeouts.

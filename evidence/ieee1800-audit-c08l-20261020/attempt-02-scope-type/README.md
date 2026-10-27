# §8.23 / §8.26 typedef scope isolation

This rerun changes the §8.26 positive implementation return types to `bit [1:0]`
and keeps the exact `IntfC::t1_t` example. It separately probes five forms of
specialized/interface class typedef scope in variable and function return
positions. It also reruns m6 with a selected top module so its compile outcome
tests the nested-interface-class restriction rather than a missing-root error.

Both editions run with the pinned `cc25756d187314742d347267c2a513b3e640a7fb`
compiler and 30-second process-group timeouts. The standards references are
IEEE 1800-2017 §§8.23, 8.26.3, pp. 196–198, and their 2023 counterparts.

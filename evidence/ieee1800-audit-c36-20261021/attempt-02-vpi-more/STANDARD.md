# Standard rules exercised — IEEE 1800-2017 and IEEE 1800-2023

The same subclause numbering and materially identical rules were checked in both PDFs. The rule descriptions below are paraphrases.

| Clause | Rule tested |
|---|---|
| **§38.4 `vpi_control`** | `vpiFinish` causes the built-in `$finish` action after the application callback returns; the diagnostic level is its integer argument. |
| **§38.6 `vpi_get`** | Returns an integer or Boolean object property; `vpiSize` is an integer property. |
| **§38.11 `vpi_get_str`** | Returns a string object property through a temporary buffer; the probe uses the full name immediately. |
| **§38.13 `vpi_get_time`** | With a null object, returns simulation time in the simulation time unit; the caller selects simulation-time format in `s_vpi_time`. |
| **§38.19 `vpi_handle_by_index`** | Returns the selected indexed child; for a `reg` array, the array is the parent object. |
| **§38.34 `vpi_put_value`** | `vpiInertialDelay` removes existing scheduled events on that object before scheduling the new event. The probe tests delayed visibility of one write; it does not test cancellation of competing writes. |
| **§38.36.2 `cbAtStartOfSimTime`** | Schedules a callback before execution of events in a specified time queue and permits the callback at a time with no event. |
| **§38.39 `vpi_remove_cb`** | Removes a callback registered with `vpi_register_cb`; returns 1 on success and 0 on failure. |

The module timescale is 1 ns/1 ns. The callback is scheduled for simulation time 10, the VPI write for time 5, the SV process reads at time 6 and invokes `$report36b` at time 11. Thus the probe separately observes the old value immediately after scheduling, the updated value at time 6, and the start-of-time callback at time 10.

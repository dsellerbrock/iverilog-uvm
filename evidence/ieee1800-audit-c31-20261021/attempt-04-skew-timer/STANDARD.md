# IEEE basis and expected skew results

IEEE 1800-2017 and IEEE 1800-2023 §31.4.2 and §31.4.3 were read directly. The default-mode definitions include the phrases “The default behavior for `$timeskew` is timer-based” (§31.4.2) and “The default behavior for `$fullskew` is timer-based” (§31.4.3). Tables 31-8 and 31-9 label the optional arguments `event_based_flag` and `remain_active_flag` as “Constant expression.” In §31.4.2, `event_based_flag` changes the default to event-based behavior; `remain_active_flag` controls whether the check remains active under the specified conditioned-event and dormancy cases. Section 31.4.3 gives the corresponding mode selection and controls whether a second timestamp event replaces, is ignored, or makes the check dormant.

For `-gspecify` and 1 ns precision, limit 2 means the first time step where elapsed time is greater than the limit is one step after the exact 2 ns boundary. Therefore, timer-based checks with reference events at t10 and t50 should report around t12–t13 and t52–t53, even if no data event ever occurs. Event-based `$timeskew` waits for a data event and should remain silent when none occurs. `$skew` is the event-based control and should also remain silent without a data event.

| Case | Stimulus | Expected result |
|---|---|---|
| K1 | `$timeskew(posedge a1, posedge b1, 2)`; a1 rises at t10; b1 never rises | One report near t12–t13 |
| K2 | `$timeskew(posedge a2, posedge b2, 2)`; a2 rises at t10; b2 rises at t30 | One report near t12–t13, none at t30 |
| K3 | `$timeskew(posedge a3, posedge b3, 2, n3, 1)`; a3 rises at t10; b3 never rises | No report because the event-based flag is set |
| K4 | `$fullskew(posedge a4, posedge b4, 2, 2)`; a4 rises at t50; b4 never rises | One report near t52–t53 |
| C0 | `$skew(posedge a5, posedge b5, 2)`; a5 rises at t10; b5 never rises | No report |

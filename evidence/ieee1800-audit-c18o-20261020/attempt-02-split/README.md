# IEEE 1800 global constraints — split probes

- IEEE 1800-2017 §18.5.9 and IEEE 1800-2023 §18.5.8 define global
  constraints and active random objects.
- IEEE 1800-2017 §18.5.10 and IEEE 1800-2023 §18.5.9 require a uniform value
  distribution over legal value combinations.
- The run splits the heap case into the standard 8-bit instance and a small
  4-bit uniformity control, then isolates rand and non-rand child handles.
  Every compile and simulation has a 30-second process-group timeout.
- A prior combined run timed out before emitting results; its logs are kept in
  `../attempt-01-global/` and are not treated as semantic outcomes.

Open and closed issue searches for the warning's uniformity language are
recorded in `dedupe-uniformity-open-closed.txt`.

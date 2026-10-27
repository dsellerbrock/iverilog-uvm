# Standard basis — IEEE 1800-2017 and IEEE 1800-2023

The two editions were checked directly. These are paraphrases of the requirements exercised by this probe; clause numbering is stable across the editions.

- **§38.15 `vpi_get_value`**: retrieves an object's simulation value into caller-allocated `s_vpi_value` storage.
- **§38.17 `vpi_get_vlog_info`**: provides invocation options and product/version information, returning 1 on success and 0 on failure.
- **§38.21 `vpi_handle_by_name`**: returns a handle for a named object; a null scope searches from the top-level hierarchy.
- **§38.23 `vpi_iterate`**: returns an iterator for a one-to-many relationship and returns null when no matching objects exist. **§38.40 `vpi_scan`** traverses the iterator and returns null at exhaustion.
- **§38.34 `vpi_put_value`**: the `vpiNoDelay` mode sets the object without delay and ignores `time_p`, which may be null.
- **§38.36 / §38.36.1 `vpi_register_cb` / `cbValueChange`**: registers a simulation callback; `cbValueChange` is scheduled after a value change for supported object kinds. This probe monitors an integer variable.
- **§38.37 `vpi_register_systf`**: registers callbacks for user-defined system tasks/functions through caller-supplied `s_vpi_systf_data`.

The probe uses one simulator invocation per language edition and prints four deterministic result lines. It checks registration by invoking both registered tasks; a missing task prevents the corresponding run from completing successfully.

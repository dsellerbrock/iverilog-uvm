# Slurm job 3686 — probe output correction

The VPI build and all eight simulations completed. Variable iterator output is usable: `vpiVariables` returned zero in each case; `vpiReg` returned the referenced `logic v` only in `p37_var_ref` and did not return the unused `logic` or unused `reg v`. Child-handle strings are not classified from this run because multiple `vpi_get_str` results were passed in a single `printf`, allowing reuse of the VPI string buffer to alias the printed fields. The corrected probe prints each string immediately and is rerun as job 3687.

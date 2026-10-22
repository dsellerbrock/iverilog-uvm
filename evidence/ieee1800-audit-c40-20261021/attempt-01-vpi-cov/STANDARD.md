# Standard text for the Clause 40.5 VPI result

## `vpi_get` coverage property

IEEE 1800-2017 §40.5.3, p. 1130:

> “returns the number of covered items of the given coverage type in the given instance.”

IEEE 1800-2023 §40.5.2, p. 1166, gives the same sentence. Neither subclause specifies a special return value for an unavailable coverage type.

## Generic `vpi_get` error result

IEEE 1800-2017 §38.6, p. 1056, and IEEE 1800-2023 §38.6, p. 1092:

> “Should an error occur, `vpi_get()` shall return `vpiUndefined`.”

## Error reporting

IEEE 1800-2017 §38.2, p. 1052, and IEEE 1800-2023 §38.2, p. 1088, specify that `vpi_chk_error()` returns an error-severity level if the previous VPI routine call resulted in an error, and 0 if no error occurred. The probe observed `vpi_get(...) == -1` (`vpiUndefined`) followed by `vpi_chk_error(...) == 0` in both editions.

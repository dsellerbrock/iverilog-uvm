# IEEE 1800 §21.4.1

IEEE 1800-2017 §21.4.1 (p. 647): “When loading dynamic arrays and queues, the current size of the array is fixed; the array shall not be resized.”

IEEE 1800-2023 §21.4.1 states the same. The clause expressly includes dynamic arrays and queues. It constrains loading not to resize them; it does not prohibit using them as `$readmemb`/`$readmemh` arguments.

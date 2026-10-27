# IEEE basis for the probe

IEEE 1800-2017 and IEEE 1800-2023 §24.7 state that `$exit` called from a thread that does not originate in an initial procedure of a program block is ignored; a warning is optional. The test `r20_02_exit.sv` calls `$exit` from a module initial process while a separate program initial process is scheduled to print `PROG done` at time 5. Because the module call must be ignored, `PROG done` must appear; the program's subsequent completion can end simulation before the module's time-20 `LATE` display.

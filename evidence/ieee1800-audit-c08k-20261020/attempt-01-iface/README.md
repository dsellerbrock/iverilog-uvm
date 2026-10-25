# IEEE 1800-2017 §8.26 interface classes

The positive probe follows the `PutImp`, `GetImp`, `Fifo`, and `Stack` example
on pp. 194–195, then checks interface-typed dispatch and implicit interface
implementation inherited by a subclass. The nested-interface case is
edition-specific: 2017 forbids nesting in any class, while 2023 only forbids
nesting inside another interface class. Compile and run both supported
language editions with a 30-second process-group timeout.

The prior guard follow-up in this batch adds flushed markers around the §18.5.13
standard example's E1C1–E1C3 cases. This identifies which case emits the
null-path diagnostic when stdout and stderr are merged.

The pinned compiler source is `cc25756d187314742d347267c2a513b3e640a7fb`.

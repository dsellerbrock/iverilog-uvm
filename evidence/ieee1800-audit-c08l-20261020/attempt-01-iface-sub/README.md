# IEEE 1800 §8.26.2–§8.26.6.1 interface-class follow-up

The positive probe covers inherited virtual implementation, a non-virtual
inherited method overridden to implement an interface, types inherited by
`extends` but not `implements`, interface handle assignment and `$cast`, and
one implementation resolving a same-signature method from two interfaces.
Six isolated negative probes cover the corresponding type-use and conflict
rules, including a nested interface class (forbidden in both editions).

The nested-in-ordinary-class case from the previous batch is intentionally not
treated as a 2023 negative: 2017 §8.26 forbids that form, while 2023 §8.26
narrows the ban. See the recorded result for #845.

The probe follows IEEE 1800-2017 §§8.26.2–8.26.6.1, pp. 196–199, and runs under
both language editions with a 30-second process-group timeout. The pinned
compiler source is `cc25756d187314742d347267c2a513b3e640a7fb`.

# IEEE 1800 §13.5.3 default-argument depth probes

## Standard basis and quotations

IEEE 1800-2017 §13.5.3 (pp. 332–333) and IEEE 1800-2023 §13.5.3 (pp. 350–351) have the same relevant requirements. The optional direction list is `input`, `inout`, `output`, or `ref`. The standard says the default expression is evaluated “in the scope containing the subroutine declaration” on each call that uses the default. Both editions illustrate output binding with `output o = a`, annotated “default binds to m.a”; the call `m.t1()` is equivalent to `m.t1(m.a)`, not to a same-named variable in the caller. The lvalue default is tested using that default-as-actual rule: `ref int x = gv` should modify `gv`.

IEEE 1800-2017/2023 §13.5.2 says only a variable, class property, unpacked-structure member, or unpacked-array element may be passed by reference, and nets are excluded. This is the basis for the negative `ref int x = 5` control.

IEEE 1800-2017 §13.4.3 p.327 / IEEE 1800-2023 §13.4.3 p.345 requires a constant function to “not contain any fork constructs”; F1 is the existing #638 reproducer.

## Cases and expected results

Each source is compiled and, when compilation succeeds, run separately under `-g2017` and `-g2023`. D1 returns 5; D2 reports a null class handle; D3 writes 42 through an omitted output default; D4 increments `gv` from 5 to 6 through an omitted inout default; D5 writes 7 through an omitted ref default; D5 negative control with constant default `5` must fail compilation; D6 returns the `const ref` default target's value 11; D7 with module-scope `a=100` returns 101, while D7 with no enclosing `a` should fail because a later default is evaluated in declaration scope and cannot name the earlier formal; D8's explicit empty named argument uses the default and returns 5; D9 returns package-scope `gv=27` rather than caller-module `gv=99`; F1 must fail compilation.

## Dedupe

Open/closed issue search for `default argument`, `13.5.3`, `default value`, and `empty named argument` is recorded in `DEDUPE.md`. Existing issues #633 and #703 cover output/inout and ref defaults; #638 covers F1. Nearby matches for ports, property/sequence defaults, semaphore defaults, and a constructor keyword are unrelated. No issue has been filed by the runner.

## Run

See `RESULT.md` for paired outputs, exact diagnostics, job/toolchain, and scheduler metrics. All compile and simulation processes have a 60-second timeout.

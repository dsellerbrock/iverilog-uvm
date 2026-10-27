# IEEE 1800 operator rules used by `p11_ops`

All references below are in both IEEE 1800-2017 and IEEE 1800-2023.

## §11.3.2 operator precedence

Table 11-2 places unary `+`, `-`, `!`, and `~` above exponentiation, then multiplication, binary addition, shifts, relational operators, equality, bitwise `&`, bitwise `^`, and bitwise `|`. The table marks `**` **left-associative**. All operators associate left-to-right except `?:`, implication, and equivalence, which associate right-to-left. Therefore `1 + 2 << 1` is 6, `2 ** 3 ** 2` is 64, and `-2 ** 2` is 4.

## §11.3.3 integer literals

The standard's example (2017 p. 257; 2023 p. 272) gives these results for minus 12 divided by 3:

```systemverilog
-12 / 3       // -4
-'d12 / 3     // 1431655761
-'sd12 / 3    // -4
-4'sd12 / 3   // 1
```

## §11.4.8 four-state bitwise truth tables

`x` is the result when a 4-state input prevents a known answer; `z` inputs produce the listed 4-state result. 2017 Tables 11-11–11-13 and 2023 Tables 11-11–11-13:

AND (`&`):

| `&` | 0 | 1 | x | z |
| --- | --- | --- | --- | --- |
| 0 | 0 | 0 | 0 | 0 |
| 1 | 0 | 1 | x | x |
| x | 0 | x | x | x |
| z | 0 | x | x | x |

OR (`|`):

| `|` | 0 | 1 | x | z |
| --- | --- | --- | --- | --- |
| 0 | 0 | 1 | x | x |
| 1 | 1 | 1 | 1 | 1 |
| x | x | 1 | x | x |
| z | x | 1 | x | x |

XOR (`^`):

| `^` | 0 | 1 | x | z |
| --- | --- | --- | --- | --- |
| 0 | 0 | 1 | x | x |
| 1 | 1 | 0 | x | x |
| x | x | x | x | x |
| z | x | x | x | x |

## §11.4.10 shift operators

The clause says: “If the right operand has an x or z value, then the result shall be unknown.” `>>>` fills with the sign bit only when the result type is signed; an unsigned left operand is zero-filled.

## §11.4.11 conditional operator

The clause says: “When both the first and second expressions are of integral types, if the cond_predicate evaluates to an ambiguous value and the expressions are not logically equivalent, their results shall be combined bit by bit using Table 11-20 to calculate the final result.” The operator is right-associative.

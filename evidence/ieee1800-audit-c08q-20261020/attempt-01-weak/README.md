# IEEE 1800-2023 §8.30 weak references and §8.27 forward parameter overrides

Probe both global `weak_reference#(T)` and `std::weak_reference#(T)` spellings against the 2023 expected sequence, including null handling, reference identity, `get_id`, derived-class compatibility, and `clear()`. The negative uses `weak_reference#(int)` because §8.30 requires a class type. Garbage-collector timing is intentionally untested because the standard makes it implementation-dependent.

Also run the 2023 §8.27 forward typedef example with positional and named parameter overrides under both editions; expected output is `FP 1 2 64`.

`-g2023`: both weak-reference positives must print the six expected lines, and the non-class parameter must fail compilation. `-g2017`: compile the unqualified weak-reference source as an edition observation; no acceptance requirement. All invocations have 30-second timeouts.

Clause map (IEEE 1800-2023): §8.30.1 requires class-type parameter `T` and identifies the built-in `std` package; §8.30.2 says `new(null)` is allowed without a warning and two weak-reference objects are distinct even when they share a referent; §8.30.3 defines `get()`; §8.30.4 says `clear()` makes `get()` return null; §8.30.5 defines `get_id()` null, stability, uniqueness, and equality across a class inheritance tree. The standard makes garbage-collector clearing time implementation-dependent, so this probe does not test expiration timing. The adjacent forward-parameter control follows IEEE 1800-2023 §8.27 p.216 and runs in both editions.

## Archive integrity

- `results-3505.tar.gz`: 2327 bytes; SHA-256 `6b76bb71a8e278873785353b2e8ef86c2420da9d77552f71b3325eed3b71bb3f`.

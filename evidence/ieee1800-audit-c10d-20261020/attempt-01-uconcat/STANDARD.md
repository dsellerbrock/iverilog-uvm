# IEEE 1800 §10.10 basis

- 1800-2017 §10.10, p. 249; 1800-2023 §10.10, p. 264: an unpacked array concatenation may appear only as the source expression in an assignment-like context; the target supplies the array type. Fixed-size target length mismatch is an error.
- 1800-2017 §10.10.1, p. 250; 1800-2023 §10.10.1, p. 265: array assignment patterns allow replication/defaulting and require each item to match the target element type; unpacked array concatenations forbid replication/defaulting/explicit typing and can combine element and array values.
- 1800-2017 §10.10.2, p. 250; 1800-2023 §10.10.2, p. 265: unlike vector/string concatenations, an unpacked array concatenation has no self-determined type and must be in an assignment-like context.
- 1800-2017 §10.10.3, p. 251; 1800-2023 §10.10.3, p. 266: each concatenation item must have a self-determined type, but the complete unpacked array concatenation has none; therefore an unpacked array concatenation as an item in another is illegal. Self-determined vector/string concatenations may be items.

The lead-proposed U5 `C = {{1,2},{3}}` is not a legal positive: it nests unpacked array concatenations, which §10.10.3 explicitly forbids. It is probed as a negative. The corrected positive uses an inner sized vector concatenation, which is self-determined and legal as one unpacked-array-concatenation item.

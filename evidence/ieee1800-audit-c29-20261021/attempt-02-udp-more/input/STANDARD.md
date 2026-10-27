# Clause 29 requirements exercised

The 2017 and 2023 editions have the same relevant wording and syntax.

- §29.8 permits an omitted UDP instance name, allows an instance array, and limits an instance to two delays because UDP outputs do not support `z`.
- §29.9 allows level-sensitive and edge-sensitive rows in one table and specifies that level-sensitive rows determine the result when both kinds match.
- §29.10 illustrates conflicting included cases and confirms that the level-sensitive result wins.

The positive source checks a two-delay named instance, an unnamed instance, a scalar-output instance array, a table mixing level and edge rows, and a separate overlapping clear/falling-edge case whose conflicting next states make §29.10 precedence observable. The negative source supplies three delays and should fail compilation.

References: IEEE 1800-2017 §§29.8–29.10, pp. 836–838; IEEE 1800-2023 §§29.8–29.10, pp. 868–870.

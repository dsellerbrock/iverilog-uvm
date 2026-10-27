# IEEE 1800 Clause 5 basis

The relevant 2017/2023 rules are quoted below; edition-specific text is noted where it differs.

- §5.4, both editions: “Block comments shall not be nested.” (2017 p. 69; 2023 p. 73)
- §5.6.1, both editions: escaped identifiers start with `\` and end at white space; 2017 explicitly enumerates space, tab, and newline. The terminating white space is not part of the identifier. (2017 pp. 70–71; 2023 pp. 74–75)
- §5.7.1, both editions: the optional `s` before the base designator makes a based literal signed; negative values use two’s-complement form. `?` is an alternative for `z`, and underscores in a number are ignored except at the beginning. (2017 pp. 72–74; 2023 pp. 76–78)
- §5.7.1, 2017: “The number of bits that make up an unsized number ... shall be at least 32.” (2017 p. 73)
- §5.7.1, 2023: “An unsized number that requires more than 32 bits shall have at least the minimum width needed to properly represent the value, including a sign bit if the number is signed.” (2023 p. 77)
- §5.7.2: real literals may use scientific notation; the exponent marker can be `e` or `E`, and the default type is `real`. (2017 p. 75; 2023 p. 80)
- §5.9.1, both editions: Table 5-1 maps `\n`, `\t`, `\\`, `\"`, `\ddd` (1–3 octal digits), and `\xdd` (1–2 hexadecimal digits) to their characters. Therefore `\x41` is present in 2017 as well as 2023; it is not a newly added escape. (2017 pp. 77–78; 2023 pp. 83–84)
- §5.9.1, 2023 addition: “An escaped character not appearing in Table 5-1 is treated the same as if the character was not escaped.” 2023 also explicitly describes triple-quoted strings; those rules are not needed for this probe. (2023 p. 84)
- §5.12: attributes use `(* attr_spec { , attr_spec } *)`; Syntax 5-3 in 2017 and Syntax 5-4 in 2023, both from Annex A.9.1. (2017 p. 79; 2023 p. 85)

The 2023 wording confirms the relevant extension is the treatment of unlisted escaped characters and triple-quoted strings. The `\xdd` hexadecimal escape itself already exists in 2017.

# IEEE 1800 §10.9 basis

The matching rules are materially the same in the cited editions.

- 1800-2017 §10.9.1, p. 247; 1800-2023 §10.9.1, p. 262: a repeated array index key is an error; every array element must be covered.
- 1800-2017 §10.9.2, pp. 248–249; 1800-2023 §10.9.2, pp. 263–264: a member-name key applies first, a matching type key applies to fields not set by name, then `default` applies to the remaining members. Every member must be covered.
- Both editions describe recursive application of type/default keys to unmatched array and structure members, and array-pattern replication must represent an entire single dimension.

Short governing text from both editions: “Every element shall be covered by one of these rules”; “Every member shall be covered by one of these rules.” 2017 §10.9.1 explicitly says it “shall be an error to specify the same index more than once in a single array pattern expression.” The §10.9.2 matching rules do not state a corresponding explicit error for repeating a member-name key; the duplicate-member probe is therefore observational unless another governing clause applies.

# Open and closed issue dedupe: Clause 6.6 nets

The snapshot dedupe-all-issues.json contains all 425 repository issues at query time: 298 open and 127 closed. The search included uwire, wand, wor, triand, trior, tri0, tri1, supply strength, nettype, resolution function, interconnect, and §6.6 terms across open and closed issues.

No issue duplicates T1-T7 or I1-I3. Nearby records are distinct:

- #878 (open) covers unsupported trireg storage only.
- #435 (open) covers class-method resolution functions for user-defined nettypes, not the standard global Tsum function or basic nettype behavior.
- #897 (open) covers connection of distinct same-data-type user-defined nettypes on module ports.
- #436 (closed) covers operand resolution in interconnect concatenations, not interconnect use restrictions.
- The assignment-pattern and user-defined-nettype candidates for the unclassified U1-U4 results are analyzed separately in followup-controls/DEDUPE.md.

No issue was filed for these passing or correctly rejected cases.

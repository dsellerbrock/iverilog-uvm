# IEEE 1800 built-in `std` package

The clause and annex numbering match in IEEE 1800-2017 and 1800-2023.

- IEEE 1800-2017 §26.7 (pp. 784–785) states: “Users cannot insert additional declarations into the built-in package.” It also describes `std` as implicitly wildcard-imported into each compilation-unit scope; user code may redefine an imported name, and `std::` explicitly accesses the built-in declaration. Annex G §§G.1–G.6 (pp. 1219–1221) lists semaphore, mailbox, randomize, and process.
- IEEE 1800-2023 §26.7 (pp. 816–817) retains those rules. Annex G §§G.1–G.7 (pp. 1256–1258) lists the same contents and adds `weak_reference`.

The positive probe checks explicit `std::` access to semaphore, mailbox, process, and randomize; a user class named `semaphore` tests the §26.7 redefinition rule and built-in qualification. The negative probe attempts `package std; endpackage`. §26.7 identifies `std` as the built-in package but does not expressly say whether a separate user package may reuse that name; unless another normative rule settles it, the negative result is observational only.

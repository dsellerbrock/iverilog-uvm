# IEEE 1800 Clause 4 basis

Checked against the local IEEE 1800-2017 and IEEE 1800-2023 PDFs.

- Region order: the region list is “Preponed, Active, Inactive, NBA, Observed, Reactive, Re-Inactive, Re-NBA and Postponed.” See 2017 §3.4.2 and detailed §4.4.2.1–§4.4.2.9; 2023 §4.4.2 and §4.4.2.1–§4.4.2.9.
- §4.4.2.2: the Active region events “can be processed in any order.”
- §4.4.2.3: Inactive events are evaluated “after all the Active events are processed.” A module `#0` suspends to Inactive.
- §4.4.2.4: NBA events are evaluated “after all the Inactive events are processed.”
- §4.4.2.6: blocking assignments in program blocks are scheduled in Reactive.
- §4.4.2.7–§4.4.2.8: Re-Inactive follows Reactive; Re-NBA follows Re-Inactive.
- §4.4.2.9: “$monitor, $strobe, and other similar events are scheduled in the Postponed region.”
- §4.6: “Statements within a begin-end block shall be executed in the order in which they appear” and “NBAs shall be performed in the order the statements were executed.” The standard example schedules two NBAs to the same variable and ends with the second value.
- Correction to the requested citation: §4.7 is titled “Nondeterminism” in both PDFs. The same-variable NBA rule and example are in §4.6, so the probe cites §4.6 for that behavior.

The provided `p04_regions.sv` probe checks Active/Inactive/NBA/Reactive/Postponed observations and source-order NBA updates in both editions.

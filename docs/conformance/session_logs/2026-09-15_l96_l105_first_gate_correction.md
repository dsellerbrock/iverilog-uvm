# L96–L105 first broad gate correction

The frozen candidate failed its first integrated gate because five negative-test golds still expected pre-L96/L105 diagnostics. [Exact results](2026-09-15_l96_l105_first_gate_correction.json) retain the failed candidate and focused replay.

The constant assignment restriction fixture now diagnoses the illegal ref formal directly under13.4.3. The substr and putc negative fixtures retain their original errors and add counted string-parameter evaluation errors instead of allowing unreduced values to reach lowering. No compiler source, acceptance expectation, failure baseline or feature count changes in this correction.

The affected existing negative cases were added to the formal/nonlocal focused lists. Their expanded legacy/JSON replays pass. The broad gates will run on a new frozen candidate; results from this failed gate are not a successful qualification claim.

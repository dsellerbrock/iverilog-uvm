# IEEE 1800 clause 19 probe batch B — initial run

- Slurm job 2259 on DAN-DESKTOP, run `ieee1800-audit-c19b-20261017-01`; 1 CPU, 1 GiB, 10-minute cap.
- Compiler: Icarus 13.0 devel, source/toolchain revision `9b5fad2af`; executable hashes are in `results/combined.txt`.
- Probe source commit `16404e84d`; c19b probe files were uncommitted inputs staged into this isolated run. Their hashes and all compile logs are preserved in `results/`.
- Script exit: 1. The composite positive `p19_03_08_cg.sv` did not elaborate because calls to coverpoint/type `get_coverage` methods were unknown; `set_inst_name` was ignored with a warning. The class-local event expression also warned that it could not bind `m_z`.
- The standalone block-event probe failed parsing and triggered an Icarus assertion in both editions.
- The output-direction negative was rejected explicitly under §19.3 in both editions. The embedded-covergroup assignment-outside-`new` negative was accepted under both editions, contrary to the expected §19.4 restriction. The 2017/2023 outside-class `extends` negative was rejected in both; 2023 currently reported generic syntax errors rather than identifying footnote 29.
- This combined probe is not classification evidence for the features blocked by compile errors. Attempt 02 will split the constructs to isolate the remaining behaviors.

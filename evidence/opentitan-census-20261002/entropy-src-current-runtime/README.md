# Entropy Source current-runtime replay

This is a selected runtime-only replay of `lowrisc:dv:entropy_src_sim:0.1`. It reused census11's compiled image (`matrix-runtime.vvp`, SHA-256 `fa0c37e59b1cb6f9a5af7cc1d12d76727f7f34e940300525d4b481819ba8f2ee`), whose census11 compile command included **`-gcommercial-unsafe`**. Census11's driver, engine, and VVP target hashes match the current compiler image; this replay used current VVP runtime SHA-256 `215774b9c3f6f3affb0be206afe017554b64b51885516b55d51f9fd57e6cfca1`.

The run exits 0 in 27.866 s and prints `TEST PASSED CHECKS`; the weighted-soft warning is absent. Raw output and machine-readable provenance are in [runtime.log](runtime.log) and [result.json](result.json).

This does **not** make the matrix row PASS: the reused census11 compile has four covergroup-bin semantic warnings. The current matrix runtime classifier also records three `assumed dropped: 0` scoreboard information lines as runtime debt. The last complete 49-row census remains census11; this is selected runtime evidence only.

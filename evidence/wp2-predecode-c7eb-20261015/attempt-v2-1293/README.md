# Attempt 1293: predecode plus word-packed result

Pinned base: `c7ebca768c21c251d9c165c9aff0e363768030b1`.

The cached-metadata predecode prototype plus `vvp_vector4_t::setarray` result packing passed the paired valid/malformed cases and produced byte-identical output in the 100,000-access hotloop. Instructions fell from 1,128,370,208 to 1,024,422,692 (−9.212182%); packing added a further −2.646331% versus predecode alone. This remains below the 10% screen threshold. See `results/instructions.csv` and the raw Callgrind profiles.

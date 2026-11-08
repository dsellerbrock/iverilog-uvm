#ifndef IVL_z3_bdd_H
#define IVL_z3_bdd_H
/*
 * Exact uniform sampling over a bit-vector constraint set, by compiling it
 * into a reduced ordered BDD (IEEE 1800-2023 18.5.9: every legal value
 * combination is equally probable).
 *
 * The constraint set is the conjunction of ASSERTIONS. STAGES lists the
 * semantic variables in solve order: each stage is drawn uniformly over the
 * projection of the solution set onto that stage, given the stages already
 * drawn (solve...before, 18.5.9). One stage means plain joint uniformity.
 * Every other constant in the assertions is existentially quantified, so
 * auxiliary solver variables are not counted.
 *
 * Returns Z3_L_TRUE with VALUES holding one numeral per variable (flattened
 * stage order), Z3_L_FALSE if the projection is empty, and Z3_L_UNDEF when
 * the formula cannot be compiled. An empty RAND32 only checks: TRUE then
 * says the BDD compiles and has a solution, VALUES stays empty, and COUNT
 * (if given) receives the number of distinct staged-variable tuples,
 * saturated at UINT64_MAX. UNDEF
 * means the formula uses an unsupported operator or sort, or the BDD outgrows
 * NODE_BUDGET. UNDEF consumes no random words, so the caller can fall back
 * to another sampler without perturbing the object's random stream.
 */
# include  <z3.h>
# include  <cstddef>
# include  <cstdint>
# include  <functional>
# include  <vector>

Z3_lbool z3_bdd_sample(Z3_context ctx, const std::vector<Z3_ast>&assertions,
		       const std::vector<std::vector<Z3_ast> >&stages,
		       const std::function<uint32_t()>&rand32,
		       std::vector<Z3_ast>&values,
		       size_t node_budget = 1u << 20,
		       uint64_t*count = 0);

#endif /* IVL_z3_bdd_H */

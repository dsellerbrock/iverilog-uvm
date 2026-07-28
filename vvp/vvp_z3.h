#ifndef IVL_vvp_z3_H
#define IVL_vvp_z3_H
/*
 * Z3 SMT solver integration for SystemVerilog constrained randomization.
 * Parses constraint IR strings and solves using Z3 bitvector arithmetic.
 */

# include  <string>
# include  <vector>

class class_type;
class vvp_cobject;

/*
 * Apply constraints to a cobject's rand properties using Z3.
 * extra_ir: additional IR strings from randomize()-with constraints.
 *           "v:N:W" tokens in extra_ir are substituted with slot_vals[N].
 *
 * prop_active selects which class properties this call solves FOR. A
 * property that is not active is a STATE variable for the duration of
 * the solve (IEEE 1800-2017 18.3): its current value is asserted as a
 * constant, it gets no diversity objective, and no model value is
 * written back to it. Pass null for the default set — every property
 * declared `rand`/`randc` whose rand_mode() is on (18.8). An explicit
 * vector is how `randomize(a, b)` and `randomize(null)` narrow the set
 * (18.11); it is indexed by property id and a property beyond its end
 * is inactive.
 *
 * Returns true when the constraint set is satisfiable: either a model
 * was applied, the pre-filled values already satisfy it, or there were
 * no constraints at all. Returns false only when the hard constraints
 * are proven unsatisfiable — the caller must then restore the
 * pre-randomize state and make randomize() return 0 (IEEE 18.6.1).
 */
bool vvp_z3_randomize(const class_type* defn, vvp_cobject* cobj,
                      const std::vector<std::string>& extra_ir   = {},
                      const std::vector<uint64_t>&    slot_vals  = {},
                      const std::vector<bool>*        prop_active = nullptr);

/*
 * Solve a scope-form std::randomize(vars) with-clause. Variable N is
 * represented by p:N:width in ir. targets supplies one random diversity
 * target per variable; widths preserves each destination's packed width.
 * On SAT, values receives one model value per variable. On UNSAT it is
 * left empty and false is returned, allowing the caller to preserve every
 * destination as required by 18.12/18.6.1.
 */
bool vvp_z3_randomize_scope(const std::string&ir,
			    const std::vector<uint64_t>&targets,
			    const std::vector<unsigned>&widths,
			    const std::vector<uint64_t>&slot_vals,
			    std::vector<uint64_t>&values);

#endif /* IVL_vvp_z3_H */

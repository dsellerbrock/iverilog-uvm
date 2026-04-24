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
 * Returns true if a satisfying assignment was found and applied.
 * Returns false if unsatisfiable.
 */
bool vvp_z3_randomize(const class_type* defn, vvp_cobject* cobj,
                      const std::vector<std::string>& extra_ir   = {},
                      const std::vector<uint64_t>&    slot_vals  = {});

#endif /* IVL_vvp_z3_H */

#ifndef IVL_vvp_z3_H
#define IVL_vvp_z3_H
/*
 * Z3 SMT solver integration for SystemVerilog constrained randomization.
 * Parses constraint IR strings and solves using Z3 bitvector arithmetic.
 */

class class_type;
class vvp_cobject;

/*
 * Apply constraints to a cobject's rand properties using Z3.
 * Returns true if a satisfying assignment was found and applied.
 * Returns false if unsatisfiable or Z3 not available.
 */
bool vvp_z3_randomize(const class_type* defn, vvp_cobject* cobj);

#endif /* IVL_vvp_z3_H */

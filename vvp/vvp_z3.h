#ifndef IVL_vvp_z3_H
#define IVL_vvp_z3_H
/*
 * Z3 SMT solver integration for SystemVerilog constrained randomization.
 * Parses constraint IR strings and solves using Z3 bitvector arithmetic.
 */

# include  <string>
# include  <vector>
# include  <cstddef>
# include  <cstdint>

class class_type;
class vvp_cobject;
class vvp_object_t;
class vvp_vector4_t;

struct vvp_z3_ref_s {
      enum kind_t { PROP = 0, MEMBER = 1, ELEM = 2, SIZE = 3 };
      unsigned kind;
      unsigned property;
      unsigned leaf;
};

/* IEEE 1800-2017 18.5.9 / 1800-2023 18.5.8: one selected object graph
 * contributes one constraint problem. The caller retains the actual objects
 * and journals their values/history until every solve pass has succeeded. */
struct vvp_z3_object_s {
      vvp_cobject*object = nullptr;
      vvp_cobject*rng_owner = nullptr;
      bool explicit_selection = false;
      std::vector<bool> active;
      bool staged_selection = false;
      std::vector<vvp_z3_ref_s> staged_active;
      bool include_class_constraints = true;
      std::vector<std::string> inherited_ir;
      std::vector<std::string> extra_ir;
      std::vector<uint64_t> slot_vals;
      std::vector<vvp_vector4_t> class_slot_vals;
      std::vector<std::string> planned_class_ir;
      std::vector<vvp_vector4_t> slot_words;
      std::vector<vvp_object_t> object_vals;
      std::vector<size_t> priority;
      bool cyclic = false;

      const std::vector<bool>*selection() const
            { return explicit_selection ? &active : nullptr; }
};

// Reject unsupported cyclic storage before prefill mutates any participant.
bool vvp_z3_graph_history_supported(const std::vector<vvp_z3_object_s>&objects);
bool vvp_z3_randomize_graph(const std::vector<vvp_z3_object_s>&objects);

struct vvp_z3_plan_item_s {
      size_t object;
      bool class_ir;
      std::string ir;
      std::vector<size_t> capture_slots;
};
struct vvp_z3_plan_call_s { size_t object; size_t slot; };
struct vvp_z3_plan_deferred_elements_s {
      size_t object;
      unsigned property;
      unsigned stage;
};
struct vvp_z3_plan_stage_s {
      std::vector<vvp_z3_plan_call_s> before_calls;
      std::vector<std::vector<vvp_z3_ref_s> > active;
      std::vector<vvp_z3_plan_item_s> items;
};
struct vvp_z3_function_plan_s {
      std::vector<vvp_z3_plan_stage_s> stages;
      std::vector<vvp_z3_plan_deferred_elements_s> deferred_elements;
      std::string error;
};
bool vvp_z3_plan_function_stages(const std::vector<vvp_z3_object_s>&objects,
                                 vvp_z3_function_plan_s&plan);

std::string vvp_z3_mark_unknown_slots(const std::string&ir,
				      const std::vector<bool>&unknown);

/* Expand selected state queues for the legacy scope route. The object graph
 * route expands with its canonical selections during each solve pass.
 * Foreach guards exclude inactive reads (2017 18.5.8.1 / 2023 18.5.7.1). */
bool vvp_z3_expand_state_foreach(const std::string&ir,
      const std::vector<vvp_vector4_t>&slot_vals,
      const std::vector<vvp_object_t>&objects, vvp_cobject*receiver,
      const std::vector<bool>*active, std::string&expanded);

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
                      const std::vector<bool>*        prop_active = nullptr,
                      bool include_class_constraints = true,
                      const std::vector<vvp_object_t>*object_vals = nullptr,
                      const std::vector<vvp_vector4_t>*class_slot_vals = nullptr);

/*
 * Solve a scope-form std::randomize(vars) with-clause. Variable N is
 * represented by p:N:width in ir. targets supplies one random diversity
 * target per variable; widths preserves each destination's packed width.
 * On SAT, values receives one model value per variable. On UNSAT it is
 * left empty and false is returned, allowing the caller to preserve every
 * destination as required by 18.12/18.6.1.
 */
bool vvp_z3_randomize_scope(const std::string&ir,
			    const std::vector<std::string>&targets,
			    const std::vector<unsigned>&widths,
			    const std::vector<uint64_t>&slot_vals,
			    const std::vector<std::vector<uint64_t> >&object_vals,
			    const std::vector<std::vector<bool> >&object_known,
			    std::vector<std::string>&values);

bool vvp_z3_randomize_scope_queue(const std::string&ir,
			    unsigned element_width, uint64_t declared_max,
			    const std::vector<uint64_t>&slot_vals,
			    const std::vector<std::vector<uint64_t> >&object_vals,
			    const std::vector<std::vector<bool> >&object_known,
			    uint64_t diversity_seed,
			    std::vector<std::string>&elements);

#endif /* IVL_vvp_z3_H */

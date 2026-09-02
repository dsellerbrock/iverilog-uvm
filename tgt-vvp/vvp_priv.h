#ifndef IVL_vvp_priv_H
#define IVL_vvp_priv_H
/*
 * Copyright (c) 2001-2025 Stephen Williams (steve@icarus.com)
 *
 *    This source code is free software; you can redistribute it
 *    and/or modify it in source code form under the terms of the GNU
 *    General Public License as published by the Free Software
 *    Foundation; either version 2 of the License, or (at your option)
 *    any later version.
 *
 *    This program is distributed in the hope that it will be useful,
 *    but WITHOUT ANY WARRANTY; without even the implied warranty of
 *    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *    GNU General Public License for more details.
 *
 *    You should have received a copy of the GNU General Public License
 *    along with this program; if not, write to the Free Software
 *    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
 */

# include  "vvp_config.h"
# include  "ivl_target.h"
# include  <inttypes.h>
# include  <limits.h>
# include  <stdio.h>
# include  <string.h>

extern int debug_draw;

extern ivl_design_t vvp_get_saved_design(void);

/*
 * The target_design entry opens the output file that receives the
 * compiled design, and sets the vvp_out to the descriptor.
 */
extern FILE* vvp_out;

/*
 * Keep a count of errors that would render the output unusable.
 */
extern int vvp_errors;

extern unsigned transient_id;

/*
 * Set to non-zero when the user wants to display file and line number
 * information for procedural statements.
 */
extern unsigned show_file_line;

struct vector_info {
      unsigned base;
      unsigned wid;
};

/*
 * Convenient constants...
 */
  /* Width limit for typical immediate arguments. */
# define IMM_WID 32

  /* The number of words available in a thread. */
# define WORD_COUNT 16

/*
 * Mangle all non-symbol characters in an identifier, quotes in names
 */
extern const char *vvp_mangle_id(const char *);
extern const char *vvp_mangle_name(const char *);

extern char* draw_Cr_to_string(double value);

extern unsigned width_of_nexus(ivl_nexus_t nex);
extern ivl_variable_type_t data_type_of_nexus(ivl_nexus_t nex);

extern int can_elide_bufz(ivl_net_logic_t net, ivl_nexus_ptr_t nptr);

/*
 * This function draws a process (initial or always) into the output
 * file. It normally returns 0, but returns !0 of there is some sort
 * of error.
 */
extern int draw_process(ivl_process_t net, void*x);

extern int draw_task_definition(ivl_scope_t scope);
extern int draw_func_definition(ivl_scope_t scope);
extern void note_td_reference(const char*label);
extern void note_td_definition(const char*label);
extern void emit_td_stub_definitions(void);

/* DPI export (IEEE 1800-2017 35.5): collect exported SV subroutines while
   drawing scopes, then emit the runtime :export_dpi directives and a
   companion C stub file that provides the exported C symbols. */
extern void note_dpi_export(ivl_scope_t scope);
extern void emit_dpi_export_directives(void);
extern void emit_dpi_export_stub_file(const char*vvp_path);

extern int draw_scope(ivl_scope_t scope, ivl_scope_t parent);
/* True when a subroutine needs a per-call context, either because the
   subroutine is automatic or because a static subroutine contains explicit
   automatic declarations. */
extern int scope_needs_call_frame(ivl_scope_t scope);
extern void reset_evcd_metadata_budget(void);
extern void note_array_signal_use(ivl_signal_t sig);
extern void emit_deferred_array_decls(void);

extern void draw_lpm_mux(ivl_lpm_t net);
extern void draw_lpm_substitute(ivl_lpm_t net);

extern void draw_ufunc_vec4(ivl_expr_t expr);
extern void draw_ufunc_real(ivl_expr_t expr);
extern void draw_ufunc_string(ivl_expr_t expr);
extern void draw_ufunc_object(ivl_expr_t expr);
extern int draw_function_input_arguments(ivl_scope_t scope,
                                         unsigned port_base,
                                         unsigned argc,
                                         ivl_expr_t const*argv);
extern int draw_vif_statement_input_arguments(ivl_scope_t scope,
                                              unsigned port_base,
                                              unsigned argc,
                                              ivl_expr_t const*argv);
extern int draw_vif_statement_output_arguments(ivl_scope_t scope,
                                               unsigned port_base,
                                               unsigned argc,
                                               ivl_expr_t const*argv);
extern int draw_vif_function_input_arguments(ivl_scope_t scope,
                                             unsigned port_base,
                                             unsigned argc,
                                             ivl_expr_t const*argv,
                                             const unsigned char*is_default);
extern void draw_static_function_setup_begin(ivl_scope_t scope);
extern void draw_static_function_setup_exec(ivl_scope_t scope);
extern void draw_static_function_arg_mode(ivl_scope_t scope, unsigned mode);
extern void draw_static_function_setup_leave(ivl_scope_t scope);
extern int draw_vif_function_call(ivl_expr_t expr);
extern void draw_ufunc_uarray(ivl_expr_t expr, ivl_signal_t dst_sig,
			      unsigned dst_base);
extern void draw_ufunc_uarray_object(ivl_expr_t expr, int as_queue,
				     uint64_t queue_max_size);

extern char* process_octal_codes(const char*txt, unsigned wid);

/*
 * modpath.c symbols.
 *
 * draw_modpath arranges for a .modpath record to be written out.
 *
 * cleanup_modpath() cleans up any pending .modpath records that may
 * have been scheduled by draw_modpath() but not yet written.
 *
 * Note: draw_modpath drive_label must be malloc'ed by the
 * caller. This function will free the string sometime in the future.
 */
extern void draw_modpath(ivl_signal_t path_sig, char*drive_label, unsigned drive_index);
extern void cleanup_modpath(void);

/*
 * This function draws the execution of a vpi_call statement, along
 * with the tricky handling of arguments. If this is called with a
 * statement handle, it will generate a %vpi_call
 * instruction. Otherwise, it will generate a %vpi_func instruction.
 */
extern void draw_vpi_task_call(ivl_statement_t net);
extern int draw_vpi_deferred_call(ivl_statement_t net, unsigned parm_base,
				  const char*task_name, long source_id,
				  ivl_scope_t scope, int is_final);

extern void draw_vpi_func_call(ivl_expr_t expr);
extern void draw_vpi_rfunc_call(ivl_expr_t expr);
extern void draw_vpi_sfunc_call(ivl_expr_t expr);

extern void draw_class_in_scope(ivl_type_t classtype);
/* Emit the .class definition for a scope-less class type (parameterized
 * specialization, synthesized covergroup class) exactly once. */
extern void ensure_class_type_emitted(ivl_type_t class_type);

/*
 * Enumeration draw routine.
 */
void draw_enumeration_in_scope(ivl_enumtype_t enumtype);

/*
 * Switches (tran)
 */
extern void draw_switch_in_scope(ivl_switch_t sw);

/* Draw_net_input and friends uses this. */
struct vvp_nexus_data {
	/* draw_net_input uses this */
      const char*net_input;
	/* draw_isnald_net_input uses these */
      const char*island_input;
      /* Aggregate driver stream local to this side of a tran island.  EVCD
       * needs this before the island resolves both hierarchy sides. */
      const char*island_local_input;
      ivl_island_t island;
	/* */
      unsigned drivers_count;
      int flags;
	/* draw_net_in_scope uses these to identify the controlling word. */
      ivl_signal_t net;
      unsigned net_word;
};
#define VVP_NEXUS_DATA_STR 0x0001


/*
 * Given a nexus, draw a string that represents the functor output
 * that feeds the nexus. This function can be used to get the input to
 * a functor, event, or even a %load in cases where I have the
 * ivl_nexus_t object. The draw_net_input function will get the string
 * cached in the nexus, if there is one, or will generate a string and
 * cache it.
 */
extern const char* draw_net_input(ivl_nexus_t nex);
void EOC_cleanup_drivers(void);

/*
 * This is different from draw_net_input in that it is intended to be
 * used within the network of an island. This finds and prepares the
 * link for a nexus within the scope of the given island, instead of
 * the net as a whole.
 */
extern const char* draw_island_net_input(ivl_island_t island, ivl_nexus_t nex);
extern const char* draw_island_local_input(ivl_island_t island,
                                           ivl_nexus_t nex);
extern unsigned draw_island_local_drivers(ivl_island_t island,
                                          ivl_nexus_t nex);

/*
 * This function is different from draw_net_input in that it will
 * return a reference to a net as its first choice. This reference
 * will follow the net value, even if the net is assigned or
 * forced. The draw_net_input above will return a reference to the
 * *input* to the net and so will not follow direct assignments to
 * the net. When a preferred scope is provided, signals in that scope
 * are chosen first so automatic method/task waits bind to the active
 * receiver handle before falling back to other nexus members.
 */
extern const char*draw_input_from_net(ivl_nexus_t nex, ivl_scope_t scope);

/* Load the class/interface object carried by a nexus. Unlike
   draw_input_from_net(), this handles one word of a fixed unpacked object
   array with %load/obja instead of inventing a nonexistent scalar label. */
extern void draw_object_from_net(ivl_nexus_t nex, ivl_scope_t scope);

/*
 * This evaluates an expression and leaves the result in the numbered
 * integer index register. It also will set bit-4 to 1 if the value is
 * not fully defined (i.e. contains x or z).
 */
extern void draw_eval_expr_into_integer(ivl_expr_t expr, unsigned ix);

/*
 * This evaluates an expression as a condition flag and leaves the
 * result in a flag that is returned. This result may be used as an
 * operand for conditional jump instructions.
 */
extern int draw_eval_condition(ivl_expr_t expr);

/*
 * Return true if the signal is the return value of a function.
 */
extern int signal_is_return_value(ivl_signal_t sig);

extern int number_is_unknown(ivl_expr_t ex);
extern int number_is_immediate(ivl_expr_t ex, unsigned lim_wid, int negative_is_ok);
extern long get_number_immediate(ivl_expr_t ex);
extern uint64_t get_number_immediate64(ivl_expr_t ex);

/*
 * draw_eval_vec4 evaluates vec4 expressions. The result of the
 * evaluation is the vec4 result in the top of the vec4 expression stack.
 */
extern void draw_eval_vec4(ivl_expr_t ex);
extern void resize_vec4_wid(ivl_expr_t expr, unsigned wid);

/*
 * draw_eval_real evaluates real value expressions. The result of the
 * evaluation is the real result in the top of the real expression stack.
 */
extern void draw_eval_real(ivl_expr_t ex);

/*
 * draw_expr_into_idx evaluates an arbitrary (vec4 or real) expression
 * and converts the result into an integer, left in index/word register
 * <use_idx>. Used anywhere an expression needs to become a run-time
 * word/element offset (delays, array indices, ...).
 */
extern void draw_expr_into_idx(ivl_expr_t expr, int use_idx);

/*
 * The draw_eval_string function evaluates the expression as a string,
 * and pushes the string onto the string stack.
 */
extern void draw_eval_string(ivl_expr_t ex);

/*
 * The draw_eval_string function evaluates the expression as an object,
 * and pushes the object onto the object stack.
 */
extern int draw_eval_object(ivl_expr_t ex);
extern int vvp_expr_is_whole_fixed_array_property(ivl_expr_t ex);
extern int vvp_expr_is_fixed_uarray_value(ivl_expr_t ex);

/* Evaluate a whole positional queue/dynamic-array value and materialize the
   destination declaration when its runtime kind differs or TARGET_TYPE is a
   bounded queue whose maximum must be applied. Returns -1 without evaluating
   EX when the caller's ordinary value-copy path is sufficient. */
extern int draw_eval_container_value_for_target(ivl_expr_t ex,
                                                 ivl_type_t target_type);

/* Apply the same destination materialization to an object-stack value that
   has already been evaluated. Returns one when conversion bytecode was
   emitted and zero when the ordinary value-copy path is sufficient. */
extern int draw_convert_container_value_for_target(ivl_type_t source_type,
                                                    ivl_type_t target_type);

/* Evaluate the frontend's typed explicit-cast marker. Unlike an implicit
   assignment, an explicit cast always creates a fresh temporary of the cast
   type, including same-kind unbounded queue/dynamic-array casts. */
extern int draw_eval_explicit_container_cast(ivl_expr_t marker);

/* Append every object-valued member of an already-evaluated collection to a
   queue builder, materializing TARGET_ELEMENT_TYPE when that element is
   itself a positional queue/dynamic array. */
extern void emit_append_object_collection(ivl_type_t target_element_type);

/* Recover the declared container type denoted by an expression. The t-dll
   representation deliberately omits net_type from SELECT nodes, so nested
   container selections must walk back to a typed property/signal and then
   descend one element type per SELECT. */
static inline ivl_type_t receiver_container_type_(ivl_expr_t expr);

/* Materialize the typed internal marker used for an associative-array
   `'{default:value}' pattern. The value is evaluated once and a fresh map is
   left on the object stack. */
extern int draw_eval_assoc_default(ivl_expr_t marker,
                                   ivl_type_t element_type);
extern int draw_eval_assoc_pattern(ivl_expr_t marker,
                                   ivl_type_t element_type);

/*
 * Like draw_eval_object, but applies unpacked-struct VALUE semantics when the
 * result is about to be copied into a variable / container element / container
 * insert: a value-type struct read from existing storage is cloned into a fresh
 * object so the stored copy is independent (class handles keep reference
 * semantics). Pass the destination element/variable type as element_type.
 */
extern int draw_eval_object_value_copy(ivl_expr_t ex, ivl_type_t element_type);

static inline int expr_is_string_assoc_key_(ivl_expr_t expr)
{
      if (!expr)
            return 0;

      return ivl_expr_value(expr) == IVL_VT_STRING
          || ivl_expr_type(expr) == IVL_EX_STRING;
}

static inline int expr_is_object_assoc_key_(ivl_expr_t expr)
{
      if (!expr)
            return 0;

      switch (ivl_expr_value(expr)) {
          case IVL_VT_CLASS:
          case IVL_VT_DARRAY:
          case IVL_VT_QUEUE:
            return 1;
          default:
            return 0;
      }
}

static inline const char* draw_eval_assoc_key_(ivl_expr_t expr, int*errors)
{
      if (expr_is_string_assoc_key_(expr)) {
            draw_eval_string(expr);
            return "str";
      }

      if (expr_is_object_assoc_key_(expr)) {
            int rc = draw_eval_object(expr);
            if (errors)
                  *errors += rc;
            return "obj";
      }

      draw_eval_vec4(expr);
      return "v";
}

static inline int expr_has_numeric_container_index_(ivl_expr_t expr)
{
      ivl_expr_t idx_expr;

      if (!expr)
            return 0;

      idx_expr = ivl_expr_oper1(expr);
      if (!idx_expr)
            return 0;

      switch (ivl_expr_value(idx_expr)) {
          case IVL_VT_STRING:
          case IVL_VT_CLASS:
          case IVL_VT_DARRAY:
          case IVL_VT_QUEUE:
            return 0;
          default:
            return 1;
      }
}

static inline int expr_is_queue_container_(ivl_expr_t expr)
{
      ivl_type_t net_type;

      if (!expr)
            return 0;

      net_type = receiver_container_type_(expr);
      if (net_type && ivl_type_base(net_type) == IVL_VT_QUEUE)
            return 1;

      return ivl_expr_value(expr) == IVL_VT_QUEUE;
}

static inline int type_is_object_like_(ivl_type_t type)
{
      if (!type)
            return 0;

      switch (ivl_type_base(type)) {
          case IVL_VT_CLASS:
          case IVL_VT_DARRAY:
          case IVL_VT_QUEUE:
          case IVL_VT_NO_TYPE:
            return 1;
          default:
            return 0;
      }
}

/* Structural shape equality for container element typing: enough to
 * tell "one element of the target" apart from "a same-shape collection
 * to splice" in queue pattern assignments and container literals. */
static inline int container_type_shape_eq_(ivl_type_t a, ivl_type_t b)
{
      if (a == b)
            return 1;
      if (!a || !b)
            return 0;
      if (ivl_type_base(a) != ivl_type_base(b))
            return 0;
      switch (ivl_type_base(a)) {
          case IVL_VT_QUEUE:
          case IVL_VT_DARRAY:
            return container_type_shape_eq_(ivl_type_element(a),
                                            ivl_type_element(b));
          case IVL_VT_BOOL:
          case IVL_VT_LOGIC:
            return ivl_type_packed_width(a) == ivl_type_packed_width(b);
          default:
            return 1;
      }
}

/* Queue OR plain dynamic array: both are 0-based runtime-sized
 * containers held as vvp_darray objects, so the object-stack indexed
 * load path for the queue/object opcodes serves both. */
static inline int expr_is_dynarray_container_(ivl_expr_t expr)
{
      ivl_type_t net_type;

      if (!expr)
            return 0;

      net_type = receiver_container_type_(expr);
      if (net_type && (ivl_type_base(net_type) == IVL_VT_QUEUE
                       || ivl_type_base(net_type) == IVL_VT_DARRAY))
            return 1;

      return ivl_expr_value(expr) == IVL_VT_QUEUE
          || ivl_expr_value(expr) == IVL_VT_DARRAY;
}

/* Decide whether a queue-pattern operand is a same-shape COLLECTION to
 * splice element-wise (IEEE 1800-2017 10.10 unpacked array
 * concatenation: {q_a, q_b} concatenates), or a single ELEMENT of the
 * target queue (e.g. the literal {1} in `qq = {{1},{2,3}}` with
 * qq[$][$] — its type IS the target's element type, so it must be
 * appended whole, not spliced). */
static inline int queue_pattern_operand_is_object_collection_(ivl_expr_t expr,
                                                              ivl_type_t element_type)
{
      ivl_type_t expr_type;
      ivl_type_t src_element_type;

      if (!expr || !type_is_object_like_(element_type))
            return 0;

      /* t-dll exports a whole fixed array as IVL_EX_ARRAY, while its
       * ivl_signal_net_type is only the scalar leaf. A multidimensional
       * operand is therefore a collection of subarrays: splice its
       * slowest-varying members into an object-container destination. A
       * one-dimensional fixed array remains one assignment-compatible
       * queue/dynamic-array element. */
      if (ivl_expr_type(expr) == IVL_EX_ARRAY
          && ivl_expr_signal(expr)
          && ivl_signal_dimensions(ivl_expr_signal(expr)) > 0)
            return ivl_signal_dimensions(ivl_expr_signal(expr)) > 1;

      if ((ivl_expr_type(expr) == IVL_EX_SIGNAL
           || ivl_expr_type(expr) == IVL_EX_ARRAY)
          && (ivl_expr_type(expr) == IVL_EX_ARRAY
              || !ivl_expr_oper1(expr))
          && ivl_expr_signal(expr))
            expr_type = ivl_signal_net_type(ivl_expr_signal(expr));
      else
            expr_type = ivl_expr_net_type(expr);
      if (!expr_type)
            return expr_is_queue_container_(expr)
                || ivl_expr_value(expr) == IVL_VT_DARRAY;

      if (ivl_type_base(expr_type) != IVL_VT_QUEUE
          && ivl_type_base(expr_type) != IVL_VT_DARRAY)
            return 0;

      /* Operand type matches the target's ELEMENT type exactly: it is
       * one element, even though it is itself a container. */
      if (container_type_shape_eq_(expr_type, element_type))
            return 0;

      /* Operand's own element type matches the target's element type:
       * a same-shape collection — splice. */
      if (container_type_shape_eq_(ivl_type_element(expr_type), element_type))
            return 1;

      src_element_type = ivl_type_element(expr_type);
      return type_is_object_like_(src_element_type);
}

/* Kind-generic version: also recognizes containers spliced into queues
 * of NON-object elements (`q = {q1, 5, q2}` with int elements — IEEE
 * 1800-2017 10.10). The object-like case defers to the shape-aware
 * classifier above. */
static inline int queue_pattern_operand_is_collection_(ivl_expr_t expr,
                                                       ivl_type_t element_type)
{
      ivl_type_t expr_type;

      if (!expr)
            return 0;
      if (type_is_object_like_(element_type))
            return queue_pattern_operand_is_object_collection_(expr, element_type);
      if ((ivl_expr_type(expr) == IVL_EX_SIGNAL
           || ivl_expr_type(expr) == IVL_EX_ARRAY)
          && (ivl_expr_type(expr) == IVL_EX_ARRAY
              || !ivl_expr_oper1(expr))
          && ivl_expr_signal(expr))
            expr_type = ivl_signal_net_type(ivl_expr_signal(expr));
      else
            expr_type = ivl_expr_net_type(expr);
      if (expr_type)
            return ivl_type_base(expr_type) == IVL_VT_QUEUE
                || ivl_type_base(expr_type) == IVL_VT_DARRAY;
      return expr_is_queue_container_(expr)
          || ivl_expr_value(expr) == IVL_VT_DARRAY;
}

static inline int expr_is_assoc_queue_container_(ivl_expr_t expr)
{
      ivl_type_t net_type;

      if (!expr)
            return 0;

      net_type = receiver_container_type_(expr);
      return net_type && ivl_type_base(net_type) == IVL_VT_QUEUE
          && ivl_type_queue_assoc_compat(net_type);
}

static inline ivl_signal_t signal_assoc_queue_receiver_(ivl_expr_t expr)
{
      ivl_signal_t sig;
      ivl_type_t net_type;

      if (!expr)
            return 0;

      if (ivl_expr_type(expr) != IVL_EX_SIGNAL
          && ivl_expr_type(expr) != IVL_EX_ARRAY)
            return 0;

      sig = ivl_expr_signal(expr);
      if (!sig)
            return 0;

      net_type = ivl_signal_net_type(sig);
      if (!net_type || ivl_type_base(net_type) != IVL_VT_QUEUE)
            return 0;

      /* A selected word of a fixed object array has no scalar v<sig>_0
       * functor. Its canonical word expression must be evaluated and the
       * map loaded through the object stack before exists/traversal runs. */
      if (ivl_signal_dimensions(sig) > 0 && ivl_expr_oper1(expr))
            return 0;

      return ivl_type_queue_assoc_compat(net_type) ? sig : 0;
}

static inline ivl_type_t property_receiver_class_type_(ivl_expr_t expr)
{
      ivl_signal_t sig;
      ivl_expr_t base_expr;
      ivl_type_t base_type = 0;

      if (!expr)
            return 0;

      if (ivl_expr_type(expr) == IVL_EX_PROPERTY) {
            base_expr = ivl_expr_oper2(expr);
            if (base_expr) {
                  base_type = ivl_expr_net_type(base_expr);
                  if (base_type && ivl_type_properties(base_type) > 0)
                        return base_type;

                  /* Synthesized queue-method/property expressions retain
                   * their class receiver as an IVL_EX_SIGNAL operand, but
                   * that operand does not necessarily carry an expression
                   * net type. Recover the declared class type from the
                   * signal itself before classifying the property index. */
                  if (ivl_expr_type(base_expr) == IVL_EX_SIGNAL
                      || ivl_expr_type(base_expr) == IVL_EX_ARRAY
                      || ivl_expr_type(base_expr) == IVL_EX_PROPERTY)
                        sig = ivl_expr_signal(base_expr);
                  else
                        sig = 0;
                  if (sig) {
                        base_type = ivl_signal_net_type(sig);
                        if (base_type && ivl_type_properties(base_type) > 0)
                              return base_type;
                  }

                  if (ivl_expr_type(base_expr) == IVL_EX_PROPERTY)
                        return property_receiver_class_type_(base_expr);
            }
      }

      if (ivl_expr_type(expr) == IVL_EX_SIGNAL
          || ivl_expr_type(expr) == IVL_EX_ARRAY
          || ivl_expr_type(expr) == IVL_EX_PROPERTY)
            sig = ivl_expr_signal(expr);
      else
            sig = 0;
      if (sig)
            return ivl_signal_net_type(sig);

      base_expr = ivl_expr_oper2(expr);
      if (!base_expr)
            return 0;

      base_type = ivl_expr_net_type(base_expr);
      if (base_type && ivl_type_properties(base_type) > 0)
            return base_type;

      if (ivl_expr_type(base_expr) == IVL_EX_PROPERTY)
            return property_receiver_class_type_(base_expr);

      return 0;
}

static inline ivl_type_t property_expr_type_(ivl_expr_t expr)
{
      ivl_type_t base_type;

      if (!expr || ivl_expr_type(expr) != IVL_EX_PROPERTY)
            return 0;

      base_type = property_receiver_class_type_(expr);
      if (!base_type || ivl_type_properties(base_type) <= 0)
            return 0;

      return ivl_type_prop_type(base_type, ivl_expr_property_idx(expr));
}

/* The target API represents a fixed unpacked-array class property as a
 * one-bit-width wrapper carrying unpacked ranges in its "packed" dimension
 * accessors.  Its element type is the kind actually stored in each property
 * slot.  Keep this test in one place: an index on such a PROPERTY selects a
 * property slot, while an index on a scalar queue/darray property selects an
 * element inside the one container held by slot zero. */
static inline int type_is_fixed_uarray_property_(ivl_type_t type)
{
      return type && ivl_type_element(type)
          && !ivl_type_is_packed_vector(type)
          && ivl_type_packed_dimensions(type) > 0
          && ivl_type_packed_width(type) == 1;
}

static inline int property_selects_fixed_uarray_slot_(ivl_expr_t expr)
{
      return expr && ivl_expr_type(expr) == IVL_EX_PROPERTY
          && ivl_expr_oper1(expr)
          && type_is_fixed_uarray_property_(property_expr_type_(expr));
}

/* Declared type of the value denoted by a property expression. An index on a
 * fixed unpacked-array property selects one property slot; an index on a
 * queue, dynamic-array, or associative-array property selects one container
 * element. In either case the denoted value has the declared element type.
 * An unselected property denotes its complete declared type. */
static inline ivl_type_t property_expr_value_type_(ivl_expr_t expr)
{
      ivl_type_t prop_type = property_expr_type_(expr);

      if (expr && ivl_expr_type(expr) == IVL_EX_PROPERTY
          && ivl_expr_oper1(expr)
          && (type_is_fixed_uarray_property_(prop_type)
              || (prop_type
                  && (ivl_type_base(prop_type) == IVL_VT_DARRAY
                      || ivl_type_base(prop_type) == IVL_VT_QUEUE))))
            return ivl_type_element(prop_type);

      return prop_type;
}

static inline int type_is_runtime_container_(ivl_type_t type)
{
      return type && (ivl_type_base(type) == IVL_VT_QUEUE
                      || ivl_type_base(type) == IVL_VT_DARRAY);
}

/* A direct word selection from a fixed unpacked array whose leaf is a
 * queue/dynamic/associative array is still exported as IVL_EX_SIGNAL. It is
 * nevertheless an object-array WORD, not the scalar v<sig>_0 container used
 * by the traditional signal fast paths. Keep that distinction centralized so
 * every read/method family retains the fixed prefix. */
static inline int expr_selects_fixed_container_slot_(ivl_expr_t expr)
{
      ivl_signal_t sig;

      if (!expr || (ivl_expr_type(expr) != IVL_EX_SIGNAL
                    && ivl_expr_type(expr) != IVL_EX_ARRAY))
            return 0;

      sig = ivl_expr_signal(expr);
      return sig && ivl_signal_dimensions(sig) > 0 && ivl_expr_oper1(expr)
          && type_is_runtime_container_(ivl_signal_net_type(sig));
}

/* Recover the declared runtime-container type of an expression value rather
   than its assignment-context type. t-dll intentionally omits net_type from
   SELECT, TERNARY, and UFUNC nodes, and a PROPERTY node can carry the outer
   property declaration even when it denotes one indexed value. Reconstruct
   provenance from those nodes before consulting the contextual fallback.

   A SELECT is accepted only when its immediate source resolves to a runtime
   container and the selected element is itself a runtime container. A
   TERNARY has one recoverable source type only when both value arms have the
   same structural container type. This avoids inventing a type across
   packed/scalar, mixed-kind, or otherwise malformed nodes. IVL expression
   trees are acyclic, so plain structural recursion has no source-visible
   depth limit. */
static inline ivl_type_t receiver_container_type_(ivl_expr_t expr)
{
      ivl_type_t type;

      if (!expr)
            return 0;

      if (ivl_expr_type(expr) == IVL_EX_PROPERTY) {
            type = property_expr_value_type_(expr);
            if (type)
                  return type_is_runtime_container_(type) ? type : 0;
      }

      /* Context-typed assignment-pattern items may report the complete outer
         destination as ivl_expr_net_type(), even when the expression is a
         bare queue/dynamic-array signal. Its declaration is authoritative.
         Keep indexed signals on the selected/contextual path below. */
      if ((ivl_expr_type(expr) == IVL_EX_SIGNAL
           || ivl_expr_type(expr) == IVL_EX_ARRAY)
          && (ivl_expr_type(expr) == IVL_EX_ARRAY
              || !ivl_expr_oper1(expr))
          && ivl_expr_signal(expr)) {
            type = ivl_signal_net_type(ivl_expr_signal(expr));
            if (type_is_runtime_container_(type))
                  return type;
      }

      if (ivl_expr_type(expr) == IVL_EX_UFUNC) {
            ivl_scope_t def = ivl_expr_def(expr);
            ivl_signal_t result = def && ivl_scope_ports(def) > 0
                  ? ivl_scope_port(def, 0) : 0;

            type = result ? ivl_signal_net_type(result) : 0;
            if (type_is_runtime_container_(type))
                  return type;
      }

      if (ivl_expr_type(expr) == IVL_EX_TERNARY) {
            ivl_type_t true_type = receiver_container_type_(
                  ivl_expr_oper2(expr));
            ivl_type_t false_type = receiver_container_type_(
                  ivl_expr_oper3(expr));

            if (type_is_runtime_container_(true_type)
                && container_type_shape_eq_(true_type, false_type))
                  return true_type;
      }

      type = ivl_expr_net_type(expr);
      if (type_is_runtime_container_(type))
            return type;

      if ((ivl_expr_type(expr) == IVL_EX_SIGNAL
           || ivl_expr_type(expr) == IVL_EX_ARRAY)
          && ivl_expr_signal(expr)) {
            type = ivl_signal_net_type(ivl_expr_signal(expr));
            return type_is_runtime_container_(type) ? type : 0;
      }

      if (ivl_expr_type(expr) != IVL_EX_SELECT)
            return 0;

      type = receiver_container_type_(ivl_expr_oper1(expr));
      type = type ? ivl_type_element(type) : 0;
      return type_is_runtime_container_(type) ? type : 0;
}

/* Evaluate one already-canonical fixed-property slot expression into WORD and
   preserve its X/Z/conversion and explicit range results in caller-owned
   flags. */
extern void draw_fixed_uarray_slot_index_(ivl_expr_t expr, ivl_type_t type,
                                          int word, int*x_flag,
                                          int*in_range_flag);

/* Evaluate one mailbox ref-output l-value now and leave a captured writable
 * target on the object stack. The target remains valid across a blocking
 * %mbx/get or %mbx/peek and consumes the returned value through
 * %ref/store/mbx. */
extern int draw_capture_lval_ref(ivl_lval_t lval);

/* Runtime queue mutation operands are exact 64-bit element counts. Zero is
 * the static spelling for unbounded, while a live declaration carrier keeps
 * known-unbounded distinct from absent metadata. */
static inline uint64_t queue_type_max_count_(ivl_type_t type)
{
      if (!type || ivl_type_base(type) != IVL_VT_QUEUE
          || ivl_type_queue_assoc_compat(type))
            return 0;
      return ivl_type_queue_max_size(type);
}

/* Object-receiver runtime handlers always prefer live declaration metadata
 * and use this exact operand only when an older value lacks such metadata. */
static inline uint64_t queue_live_max_operand_(ivl_type_t type)
{
      return queue_type_max_count_(type);
}

static inline uint64_t queue_receiver_max_operand_(ivl_expr_t receiver,
					    ivl_type_t type)
{
      (void)receiver;
      return queue_live_max_operand_(type);
}

/* Emit the strict recursive container-layout suffix understood by new VVP.
 * Q0 means a known-unbounded queue; D and A carry no bound. The element chain
 * stops at the first non-container type. */
static inline void emit_container_layout_suffix_(ivl_type_t type)
{
      ivl_type_t cur = type;
      int emitted = 0;
      while (cur) {
            const ivl_variable_type_t base = ivl_type_base(cur);
            if (base != IVL_VT_QUEUE && base != IVL_VT_DARRAY)
                  break;
            fputc(emitted ? ',' : '!', vvp_out);
            if (base == IVL_VT_DARRAY) {
                  fputc('D', vvp_out);
            } else if (ivl_type_queue_assoc_compat(cur)) {
                  fputc('A', vvp_out);
            } else {
                  fprintf(vvp_out, "Q%" PRIu64,
                          ivl_type_queue_max_size(cur));
            }
            emitted = 1;
            cur = ivl_type_element(cur);
      }
}

/* Keep the legacy zero-bound VVP spellings intact so older generated VVP
 * remains parseable. Bounded object receivers use explicit /max variants. */
static inline void emit_object_queue_insert_(const char*kind,
                                             uint64_t max_count,
                                             unsigned vec_width)
{
      if (strcmp(kind, "v") == 0) {
            if (max_count)
                  fprintf(vvp_out, "    %%qinsert/o/v/max %" PRIu64 ", %u;\n",
                          max_count, vec_width);
            else
                  fprintf(vvp_out, "    %%qinsert/o/v %u;\n", vec_width);
      } else if (max_count) {
            fprintf(vvp_out, "    %%qinsert/o/%s/max %" PRIu64 ";\n",
                    kind, max_count);
      } else {
            fprintf(vvp_out, "    %%qinsert/o/%s;\n", kind);
      }
}

static inline void emit_object_queue_store_(char mode, const char*kind,
                                            uint64_t max_count,
                                            unsigned vec_width)
{
      if (strcmp(kind, "v") == 0) {
            if (max_count)
                  fprintf(vvp_out, "    %%store/qo/%c/v/max %" PRIu64 ", %u;\n",
                          mode, max_count, vec_width);
            else
                  fprintf(vvp_out, "    %%store/qo/%c/v %u;\n",
                          mode, vec_width);
      } else if (max_count) {
            fprintf(vvp_out, "    %%store/qo/%c/%s/max %" PRIu64 ";\n",
                    mode, kind, max_count);
      } else {
            fprintf(vvp_out, "    %%store/qo/%c/%s;\n", mode, kind);
      }
}

static inline int property_is_object_expr_(ivl_expr_t expr)
{
      ivl_type_t prop_type = property_expr_value_type_(expr);

      if (!prop_type)
            return 0;

      switch (ivl_type_base(prop_type)) {
          case IVL_VT_CLASS:
          case IVL_VT_DARRAY:
          case IVL_VT_QUEUE:
          case IVL_VT_NO_TYPE:
            return 1;
          default:
            return 0;
      }
}

static inline int property_is_indexed_queue_expr_(ivl_expr_t expr)
{
      ivl_type_t base_type;
      ivl_type_t prop_type;

      if (!expr_has_numeric_container_index_(expr))
            return 0;

      if (property_selects_fixed_uarray_slot_(expr))
            return 0;

      base_type = property_receiver_class_type_(expr);
      if (!base_type || ivl_type_properties(base_type) <= 0)
            return 0;

      prop_type = ivl_type_prop_type(base_type, ivl_expr_property_idx(expr));
      /* receiver_container_type_ describes the selected VALUE. For an
       * associative property whose value is itself a queue, that is correctly
       * the inner positional queue, but this classifier must still inspect the
       * OUTER property in order not to reinterpret the associative key as a
       * positional index. */
      if (prop_type && ivl_type_base(prop_type) == IVL_VT_QUEUE
          && ivl_type_queue_assoc_compat(prop_type))
            return 0;

      if (expr_is_queue_container_(expr))
            return 1;

      return prop_type && ivl_type_base(prop_type) == IVL_VT_QUEUE
          && !ivl_type_queue_assoc_compat(prop_type);
}

static inline ivl_type_t property_assoc_container_type_(ivl_expr_t expr)
{
      ivl_type_t base_type;
      ivl_type_t prop_type;

      if (!expr || ivl_expr_type(expr) != IVL_EX_PROPERTY)
            return 0;

      base_type = property_receiver_class_type_(expr);
      if (!base_type || ivl_type_properties(base_type) <= 0)
            return 0;

      prop_type = ivl_type_prop_type(base_type, ivl_expr_property_idx(expr));
      if (!prop_type || ivl_type_base(prop_type) != IVL_VT_QUEUE)
            return 0;

      return ivl_type_queue_assoc_compat(prop_type) ? prop_type : 0;
}

static inline int property_is_assoc_indexed_expr_(ivl_expr_t expr)
{
      return expr && ivl_expr_oper1(expr) != 0
          && !property_selects_fixed_uarray_slot_(expr)
          && property_assoc_container_type_(expr) != 0;
}

static inline int property_is_indexed_darray_expr_(ivl_expr_t expr)
{
      ivl_type_t base_type;
      ivl_type_t prop_type;

      if (!expr_has_numeric_container_index_(expr))
            return 0;

      if (property_selects_fixed_uarray_slot_(expr))
            return 0;

      base_type = property_receiver_class_type_(expr);
      if (!base_type || ivl_type_properties(base_type) <= 0)
            return 0;

      prop_type = ivl_type_prop_type(base_type, ivl_expr_property_idx(expr));
      return prop_type && ivl_type_base(prop_type) == IVL_VT_DARRAY;
}

/* True when this property expression selects an ELEMENT of a container
   property -- a dynamic array, a queue, or an associative array held in a
   class property -- as opposed to naming the property slot itself (or a
   slot of a fixed-size unpacked array property, where the index really is
   a property-slot index).

   The distinction matters wherever an opcode takes a property id plus an
   index: for a container property the runtime holds ONE object in the
   slot (the container), so a slot-indexed opcode reads the container
   instead of the element -- silently, for index 0. */
static inline int property_is_indexed_container_expr_(ivl_expr_t expr)
{
      if (!expr || ivl_expr_type(expr) != IVL_EX_PROPERTY)
            return 0;
      if (ivl_expr_oper1(expr) == 0)
            return 0;

      return property_is_indexed_darray_expr_(expr)
          || property_is_indexed_queue_expr_(expr)
          || property_is_assoc_indexed_expr_(expr);
}

static inline int same_property_receiver_path_(ivl_expr_t lhs, ivl_expr_t rhs)
{
      if (lhs == rhs)
            return 1;

      if (!lhs || !rhs)
            return lhs == rhs;

      if (ivl_expr_type(lhs) != ivl_expr_type(rhs))
            return 0;

      switch (ivl_expr_type(lhs)) {
          case IVL_EX_SIGNAL:
          case IVL_EX_ARRAY:
            return ivl_expr_signal(lhs) == ivl_expr_signal(rhs);

          case IVL_EX_PROPERTY:
            if (ivl_expr_property_idx(lhs) != ivl_expr_property_idx(rhs))
                  return 0;
            if (ivl_expr_signal(lhs) != ivl_expr_signal(rhs))
                  return 0;
            return same_property_receiver_path_(ivl_expr_oper2(lhs),
                                                ivl_expr_oper2(rhs));

          case IVL_EX_NULL:
            return 1;

          default:
            return 0;
      }
}

static inline ivl_expr_t property_synthesized_last_index_target_(ivl_expr_t expr)
{
      ivl_expr_t idx_expr;
      ivl_expr_t rhs_expr;
      ivl_expr_t lhs_expr;

      if (!expr)
            return 0;

      idx_expr = ivl_expr_oper1(expr);
      if (!idx_expr || ivl_expr_type(idx_expr) != IVL_EX_BINARY
          || ivl_expr_opcode(idx_expr) != '-')
            return 0;

      rhs_expr = ivl_expr_oper2(idx_expr);
      if (!rhs_expr || !number_is_immediate(rhs_expr, IMM_WID, 1)
          || number_is_unknown(rhs_expr)
          || get_number_immediate(rhs_expr) != 1)
            return 0;

      lhs_expr = ivl_expr_oper1(idx_expr);
      if (!lhs_expr || ivl_expr_type(lhs_expr) != IVL_EX_SFUNC)
            return 0;

      if (strcmp(ivl_expr_name(lhs_expr), "$ivl_queue_method$size") != 0)
            return 0;

      if (ivl_expr_parms(lhs_expr) != 1)
            return 0;

      return ivl_expr_parm(lhs_expr, 0);
}

static inline int property_uses_synthesized_last_index_(ivl_expr_t expr)
{
      ivl_expr_t target_expr = property_synthesized_last_index_target_(expr);

      if (!target_expr)
            return 0;

      return same_property_receiver_path_(expr, target_expr);
}

static inline int emit_property_queue_last_index_(ivl_expr_t expr,
                                                  unsigned pidx,
                                                  unsigned ix)
{
      ivl_expr_t idx_expr;

      if (!property_uses_synthesized_last_index_(expr))
            return 0;

      idx_expr = ivl_expr_oper1(expr);

      fprintf(vvp_out, "    %%prop/obj %u, 0; eval_queue_last_index\n", pidx);
      fprintf(vvp_out, "    %%qsize/o;\n");
      fprintf(vvp_out, "    %%subi 1, 0, 32;\n");
      if (idx_expr && ivl_expr_signed(idx_expr))
            fprintf(vvp_out, "    %%ix/vec4/s %u;\n", ix);
      else
            fprintf(vvp_out, "    %%ix/vec4 %u;\n", ix);

      return 1;
}

/* The packed element descriptor %load/arr/dar and %store/arr/dar share
   for a fixed unpacked array's elements. Keep bits 8..13 in their original
   positions so VVP images using the earlier 8-bit-width encoding remain
   readable; width bits 8..23 occupy the previously unused bits 14..29.

      kind bits  7..0  = element width bits 7..0
      kind bit      8  = signed
      kind bit      9  = four-state
      kind bit     10  = descending fixed range (load source/store target)
      kind bit     11  = object elements
      kind bit     12  = string elements
      kind bit     13  = queue result
      kind bits 29..14 = element width bits 23..8

   Returns 0 (and reports) when the element kind cannot be carried. */
#define VVP_ARRDAR_WIDTH_MAX       0x00ffffffu
#define VVP_ARRDAR_WIDTH_KIND(w)   (((w) & 0xffu) | (((w) & 0xffff00u) << 6))
#define VVP_ARRDAR_SIGNED          (1u << 8)
#define VVP_ARRDAR_FOUR            (1u << 9)
#define VVP_ARRDAR_DESC            (1u << 10)
#define VVP_ARRDAR_OBJ             (1u << 11)
#define VVP_ARRDAR_STRING          (1u << 12)
#define VVP_ARRDAR_QUEUE           (1u << 13)

extern int uarray_container_kind_(ivl_signal_t sig, unsigned*kind_out,
				  const char*file, unsigned lineno);

/* Emit the fixed-array -> container load, flat or nested according to
   the source's declared dimensionality. */
extern void emit_load_arr_dar_(ivl_signal_t sig, unsigned kind);

/* Flat one-dimensional fixed-array slice variants. canonical_base/count
   address numeric-low storage; left/right preserve the selected range's
   declared order for SystemVerilog value correspondence and DPI metadata. */
extern void emit_load_arr_dar_slice_(ivl_signal_t sig, unsigned kind,
				     unsigned canonical_base, unsigned count,
				     int left, int right);

/* Emit the container -> fixed-array store, flat or nesting according to
   the destination's declared dimensionality. */
extern void emit_store_arr_dar_(ivl_signal_t sig, unsigned kind);
extern void emit_store_arr_dar_slice_(ivl_signal_t sig, unsigned kind,
				      unsigned canonical_base, unsigned count,
				      int left, int right);

/* Sized DPI fixed-array formals use the direct C-pointer ABI, not an
   svOpenArrayHandle. A multidimensional signal therefore needs its canonical
   flat word storage, rather than the nested object tree used by open arrays. */
extern void emit_load_arr_dar_dpi_(ivl_signal_t sig, unsigned kind);
extern void emit_store_arr_dar_dpi_(ivl_signal_t sig, unsigned kind);

extern int show_stmt_assign(ivl_statement_t net);
extern int show_stmt_assign_nb_cobject(ivl_statement_t net, uint64_t delay);
extern void show_stmt_file_line(ivl_statement_t net, const char*desc);

/*
 */
extern int test_immediate_vec4_ok(ivl_expr_t expr);
extern void draw_immediate_vec4(ivl_expr_t expr, const char*opcode);

/*
 * Draw a delay statement.
 */
extern void draw_delay(const void*ptr, unsigned wid, const char*input,
		       ivl_expr_t rise_exp, ivl_expr_t fall_exp,
		       ivl_expr_t decay_exp, unsigned per_bit,
		       unsigned whole_vector);

/*
 * These functions manage word register allocation.
 */
extern int allocate_word(void);
extern void clr_word(int idx);

/*
 * These functions manage flag bit allocation.
 */
extern int allocate_flag(void);
extern void clr_flag(int idx);

/*
 * These are used to count labels as I generate code.
 */
extern unsigned local_count;
extern unsigned thread_count;

extern void darray_new(ivl_type_t element_type, unsigned size_reg);

/*
 * Streaming-operator support (IEEE 1800-2017 11.4.14) for dynamically
 * sized operands.  draw_stream_pack_pieces() recognizes internal
 * system functions named "$ivl_stream$pack$<l|r>$<slice>", evaluates
 * each operand (flattening container/string operands), joins the
 * pieces, and emits %stream/end/{l,r} <slice>, <tw> leaving the
 * stream on the vec4 stack.  Returns 0 on success, -1 if the name is
 * not a stream-pack function.
 */
extern int draw_stream_pack_pieces(ivl_expr_t expr, unsigned tw);
extern void stream_elem_type_text(ivl_type_t element_type,
                                  char*buf, size_t bufsz);

/*
 * Array reduction methods (IEEE 1800-2017 7.12.3): lower the internal
 * system function "$ivl_darray_method$reduce|<kind>" to an inline
 * loop over the array receiver, leaving the accumulated value on the
 * vec4 stack.  Defined in eval_object.c (it shares the array-receiver
 * helpers with the locator loops), called from draw_sfunc_vec4.
 */
extern int draw_array_reduce_vec4(ivl_expr_t expr);

/*
 * These are various statement code generators.
 */
extern int show_statement(ivl_statement_t net, ivl_scope_t sscope);

typedef struct vvp_randsequence_flow_s {
      unsigned break_label;
      unsigned return_label;
} vvp_randsequence_flow_t;
extern vvp_randsequence_flow_t vvp_randsequence_flow_push(
      ivl_randsequence_block_t kind, unsigned label);
extern void vvp_randsequence_flow_pop(vvp_randsequence_flow_t saved);

extern int show_stmt_break(ivl_statement_t net, ivl_scope_t sscope);
extern int show_stmt_continue(ivl_statement_t net, ivl_scope_t sscope);
extern int show_stmt_forever(ivl_statement_t net, ivl_scope_t sscope);
extern int show_stmt_forloop(ivl_statement_t net, ivl_scope_t sscope);
extern int show_stmt_repeat(ivl_statement_t net, ivl_scope_t sscope);
extern int show_stmt_while(ivl_statement_t net, ivl_scope_t sscope);
extern int show_stmt_do_while(ivl_statement_t net, ivl_scope_t sscope);

#endif /* IVL_vvp_priv_H */

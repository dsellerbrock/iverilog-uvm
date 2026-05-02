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

extern int draw_scope(ivl_scope_t scope, ivl_scope_t parent);
extern void note_array_signal_use(ivl_signal_t sig);
extern void emit_deferred_array_decls(void);

extern void draw_lpm_mux(ivl_lpm_t net);
extern void draw_lpm_substitute(ivl_lpm_t net);

extern void draw_ufunc_vec4(ivl_expr_t expr);
extern void draw_ufunc_real(ivl_expr_t expr);
extern void draw_ufunc_string(ivl_expr_t expr);
extern void draw_ufunc_object(ivl_expr_t expr);

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

extern void draw_vpi_func_call(ivl_expr_t expr);
extern void draw_vpi_rfunc_call(ivl_expr_t expr);
extern void draw_vpi_sfunc_call(ivl_expr_t expr);

extern void draw_class_in_scope(ivl_type_t classtype);

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
 * The draw_eval_string function evaluates the expression as a string,
 * and pushes the string onto the string stack.
 */
extern void draw_eval_string(ivl_expr_t ex);

/*
 * The draw_eval_string function evaluates the expression as an object,
 * and pushes the object onto the object stack.
 */
extern int draw_eval_object(ivl_expr_t ex);

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

      net_type = ivl_expr_net_type(expr);
      if (net_type && ivl_type_base(net_type) == IVL_VT_QUEUE)
            return 1;

      return ivl_expr_value(expr) == IVL_VT_QUEUE;
}

static inline int expr_is_assoc_queue_container_(ivl_expr_t expr)
{
      ivl_type_t net_type;

      if (!expr)
            return 0;

      net_type = ivl_expr_net_type(expr);
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

                  if (ivl_expr_type(base_expr) == IVL_EX_PROPERTY)
                        return property_receiver_class_type_(base_expr);
            }
      }

      sig = ivl_expr_signal(expr);
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

static inline int property_is_object_expr_(ivl_expr_t expr)
{
      ivl_type_t prop_type = property_expr_type_(expr);

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

      if (expr_is_assoc_queue_container_(expr))
            return 0;

      if (expr_is_queue_container_(expr))
            return 1;

      base_type = property_receiver_class_type_(expr);
      if (!base_type || ivl_type_properties(base_type) <= 0)
            return 0;

      prop_type = ivl_type_prop_type(base_type, ivl_expr_property_idx(expr));
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
          && property_assoc_container_type_(expr) != 0;
}

static inline int property_is_indexed_darray_expr_(ivl_expr_t expr)
{
      ivl_type_t base_type;
      ivl_type_t prop_type;

      if (!expr_has_numeric_container_index_(expr))
            return 0;

      base_type = property_receiver_class_type_(expr);
      if (!base_type || ivl_type_properties(base_type) <= 0)
            return 0;

      prop_type = ivl_type_prop_type(base_type, ivl_expr_property_idx(expr));
      return prop_type && ivl_type_base(prop_type) == IVL_VT_DARRAY;
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

extern int show_stmt_assign(ivl_statement_t net);
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
		       ivl_expr_t decay_exp);

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
 * These are various statement code generators.
 */
extern int show_statement(ivl_statement_t net, ivl_scope_t sscope);

extern int show_stmt_break(ivl_statement_t net, ivl_scope_t sscope);
extern int show_stmt_continue(ivl_statement_t net, ivl_scope_t sscope);
extern int show_stmt_forever(ivl_statement_t net, ivl_scope_t sscope);
extern int show_stmt_forloop(ivl_statement_t net, ivl_scope_t sscope);
extern int show_stmt_repeat(ivl_statement_t net, ivl_scope_t sscope);
extern int show_stmt_while(ivl_statement_t net, ivl_scope_t sscope);
extern int show_stmt_do_while(ivl_statement_t net, ivl_scope_t sscope);

#endif /* IVL_vvp_priv_H */

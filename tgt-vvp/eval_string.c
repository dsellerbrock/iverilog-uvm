/*
 * Copyright (c) 2012-2013 Stephen Williams (steve@icarus.com)
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

# include  "vvp_priv.h"
# include  <string.h>
# include  <assert.h>

static void fallback_eval(ivl_expr_t expr)
{
      draw_eval_vec4(expr);
      fprintf(vvp_out, "    %%pushv/str; Cast BOOL/LOGIC to string\n");
}

static void string_ex_concat(ivl_expr_t expr)
{
      unsigned repeat;

      assert(ivl_expr_parms(expr) != 0);
      assert(ivl_expr_repeat(expr) != 0);

	/* Push the first string onto the stack, no matter what. */
      draw_eval_string(ivl_expr_parm(expr,0));

      for (repeat = 0 ; repeat < ivl_expr_repeat(expr) ; repeat += 1) {
	    unsigned idx;
	    for (idx = (repeat==0)? 1 : 0 ; idx < ivl_expr_parms(expr) ; idx += 1) {
		  ivl_expr_t sub = ivl_expr_parm(expr,idx);

		    /* Special case: If operand is a string literal,
		       then concat it using the %concati/str
		       instruction. */
		  if (ivl_expr_type(sub) == IVL_EX_STRING) {
			fprintf(vvp_out, "    %%concati/str \"%s\";\n",
				ivl_expr_string(sub));
			continue;
		  }

		  draw_eval_string(sub);
		  fprintf(vvp_out, "    %%concat/str;\n");
	    }
      }
}

static void string_ex_property(ivl_expr_t expr)
{
      ivl_signal_t sig = ivl_expr_signal(expr);
      unsigned pidx = ivl_expr_property_idx(expr);
      ivl_expr_t base_expr = ivl_expr_oper2(expr);
      unsigned lab_null = local_count++;
      unsigned lab_out = local_count++;
      ivl_expr_t idx_expr = ivl_expr_oper1(expr);
      int queue_indexed = property_is_indexed_queue_expr_(expr);
      int assoc_indexed = property_is_assoc_indexed_expr_(expr);

      if (sig) {
	    fprintf(vvp_out, "    %%load/obj v%p_0;\n", sig);
      } else if (base_expr && ivl_expr_type(base_expr) == IVL_EX_NULL) {
	      /* Compile-progress fallback: null receiver property access
	         yields an empty string. */
	    fprintf(vvp_out, "    %%pushi/str \"\";\n");
	    return;
      } else {
	    draw_eval_object(base_expr);
      }
      fprintf(vvp_out, "    %%test_nul/obj;\n");
      fprintf(vvp_out, "    %%jmp/1 T_%u.%u, 4;\n", thread_count, lab_null);
      if (assoc_indexed) {
            const char*key_kind;
	    fprintf(vvp_out, "    %%prop/obj %u, 0; eval_assoc_property\n", pidx);
            key_kind = draw_eval_assoc_key_(idx_expr, 0);
	    fprintf(vvp_out, "    %%aa/load/str/%s;\n", key_kind);
	    fprintf(vvp_out, "    %%pop/obj 2, 0;\n");
	      } else if (queue_indexed) {
		    if (!emit_property_queue_last_index_(expr, pidx, 3))
			  draw_eval_expr_into_integer(idx_expr, 3);
		    fprintf(vvp_out, "    %%prop/obj %u, 0; eval_queue_property\n", pidx);
		    fprintf(vvp_out, "    %%load/qo/str;\n");
		    fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
	      } else {
	    fprintf(vvp_out, "    %%prop/str %u;\n", pidx);
	    fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
      }
      fprintf(vvp_out, "    %%jmp T_%u.%u;\n", thread_count, lab_out);
      fprintf(vvp_out, "T_%u.%u;\n", thread_count, lab_null);
      fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
      fprintf(vvp_out, "    %%pushi/str \"\";\n");
      fprintf(vvp_out, "T_%u.%u;\n", thread_count, lab_out);
}

static void string_ex_signal(ivl_expr_t expr)
{
      ivl_signal_t sig = ivl_expr_signal(expr);

      if (ivl_signal_data_type(sig) != IVL_VT_STRING) {
	    fallback_eval(expr);
	    return;
      }

	/* Special Case: If the signal is the return value of the
	   function, then use a different opcode to get the value. */
      if (signal_is_return_value(sig)) {
	    assert(ivl_signal_dimensions(sig) == 0);
	    fprintf(vvp_out, "    %%retload/str 0; Load %s (string_ex_signal)\n",
		    ivl_signal_basename(sig));
	    return;
      }

	/* Simple case: This is a simple variable. Generate a load
	   statement to load the string into the stack. */
      if (ivl_signal_dimensions(sig) == 0) {
	    fprintf(vvp_out, "    %%load/str v%p_0;\n", sig);
	    return;
      }

	/* There is a word select expression, so load the index into a
	   register and load from the array. */
      ivl_expr_t word_ex = ivl_expr_oper1(expr);
      int word_ix = allocate_word();
      draw_eval_expr_into_integer(word_ex, word_ix);
      note_array_signal_use(sig);
      fprintf(vvp_out, "    %%load/stra v%p, %d;\n", sig, word_ix);
      clr_word(word_ix);
}

static void string_ex_select(ivl_expr_t expr)
{
	/* The sube references the expression to be selected from. */
      ivl_expr_t sube = ivl_expr_oper1(expr);
	/* This is the select expression */
      ivl_expr_t shift= ivl_expr_oper2(expr);

	/* sube may be a null/unresolved placeholder from compile-progress fallbacks. */
      if (ivl_expr_type(sube) != IVL_EX_SIGNAL &&
	  ivl_expr_type(sube) != IVL_EX_ARRAY &&
	  ivl_expr_type(sube) != IVL_EX_PROPERTY) {
	    /* Compile-progress fallback: unsupported select base type in
	       string context lowers to empty string. */
	    if (shift) {
		  int tmp_ix = allocate_word();
		  draw_eval_expr_into_integer(shift, tmp_ix);
		  clr_word(tmp_ix);
	    }
	    fprintf(vvp_out, "    %%pushi/str \"\"; ; select fallback\n");
	    return;
      }

	/* Common fast path: signal-backed roots. */
      ivl_signal_t sig = ivl_expr_signal(sube);
      if (sig) {
	    ivl_variable_type_t sig_type = ivl_signal_data_type(sig);
            ivl_type_t net_type = ivl_signal_net_type(sig);

	      /* Dynamic array / queue of strings. */
	    if (sig_type == IVL_VT_DARRAY || sig_type == IVL_VT_QUEUE) {
                  if (net_type && ivl_type_queue_assoc_compat(net_type)
                      && expr_is_object_assoc_key_(shift)) {
                        draw_eval_object(shift);
                        fprintf(vvp_out, "    %%aa/load/sig/str/obj v%p_0;\n", sig);
                        return;
                  }
		  draw_eval_expr_into_integer(shift, 3);
		  fprintf(vvp_out, "    %%load/dar/str v%p_0;\n", sig);
		  return;
	    }

	      /* Unpacked static array of strings. */
	    if (sig_type == IVL_VT_STRING && ivl_signal_dimensions(sig) > 0) {
		  int word_ix = allocate_word();
		  draw_eval_expr_into_integer(shift, word_ix);
		  note_array_signal_use(sig);
		  fprintf(vvp_out, "    %%load/stra v%p, %d;\n", sig, word_ix);
		  clr_word(word_ix);
		  return;
	    }
      }

      if (ivl_expr_type(sube) == IVL_EX_PROPERTY) {
	    if (expr_is_queue_container_(sube)) {
		  draw_eval_object(sube);
		  draw_eval_expr_into_integer(shift, 3);
		  fprintf(vvp_out, "    %%load/qo/str;\n");
		  return;
	    }
      }

      if (shift) {
	    int tmp_ix = allocate_word();
	    draw_eval_expr_into_integer(shift, tmp_ix);
	    clr_word(tmp_ix);
      }
      fprintf(vvp_out, "    %%pushi/str \"\"; ; select fallback\n");
}

static void string_ex_string(ivl_expr_t expr)
{
      const char*val = ivl_expr_string(expr);

	/* Special case: The elaborator converts the string "" to an
	   8-bit zero, which is in turn escaped to the 4-character
	   string \000. Detect this special case and convert it back
	   to an empty string. [Perhaps elaboration should be fixed?] */
      if (ivl_expr_width(expr)==8 && (strcmp(val,"\\000") == 0)) {
	    fprintf(vvp_out, "    %%pushi/str \"\";\n");
	    return;
      }

      fprintf(vvp_out, "    %%pushi/str \"%s\";\n", val);
}

static void string_ex_substr(ivl_expr_t expr)
{
      ivl_expr_t arg;
      unsigned arg1;
      unsigned arg2;
      assert(ivl_expr_parms(expr) == 3);

      arg = ivl_expr_parm(expr,0);
      draw_eval_string(arg);

	/* Evaluate the arguments... */
      arg = ivl_expr_parm(expr, 1);
      arg1 = allocate_word();
      draw_eval_expr_into_integer(arg, arg1);

      arg = ivl_expr_parm(expr, 2);
      arg2 = allocate_word();
      draw_eval_expr_into_integer(arg, arg2);

      fprintf(vvp_out, "    %%substr %u, %u;\n", arg1, arg2);
      clr_word(arg1);
      clr_word(arg2);
}

static void string_ex_pop(ivl_expr_t expr)
{
      static int warned_non_signal_pop = 0;
      const char*fb;
      ivl_expr_t arg;

      if (strcmp(ivl_expr_name(expr), "$ivl_queue_method$pop_back")==0)
	    fb = "b";
      else
	    fb = "f";

      arg = ivl_expr_parm(expr, 0);
      if (ivl_expr_type(arg) != IVL_EX_SIGNAL) {
	    ivl_type_t net_type = ivl_expr_net_type(arg);
	    if ((net_type && ivl_type_base(net_type) == IVL_VT_QUEUE)
	        || ivl_expr_value(arg) == IVL_VT_QUEUE) {
		  draw_eval_object(arg);
		  fprintf(vvp_out, "    %%qpop/o/%s/str;\n", fb);
		  return;
	    }
	    if (!warned_non_signal_pop) {
		  fprintf(stderr, "Warning: %s requires signal, got expr type %d;"
			  " skipping pop"
			  " (further similar warnings suppressed)\n",
			  ivl_expr_name(expr), ivl_expr_type(arg));
		  warned_non_signal_pop = 1;
	    }
	    fprintf(vvp_out, "    %%pushi/str \"\"; ; pop fallback\n");
	    return;
      }

      fprintf(vvp_out, "    %%qpop/%s/str v%p_0;\n", fb, ivl_expr_signal(arg));
}

static void draw_sfunc_string(ivl_expr_t expr)
{
    assert(ivl_expr_value(expr) == IVL_VT_STRING);
    draw_vpi_sfunc_call(expr);
}

void draw_eval_string(ivl_expr_t expr)
{

      switch (ivl_expr_type(expr)) {
	  case IVL_EX_STRING:
	    string_ex_string(expr);
	    break;

	  case IVL_EX_SIGNAL:
	    string_ex_signal(expr);
	    break;

	  case IVL_EX_CONCAT:
	    string_ex_concat(expr);
	    break;

	  case IVL_EX_PROPERTY:
	    string_ex_property(expr);
	    break;

	  case IVL_EX_SELECT:
	    string_ex_select(expr);
	    break;

	  case IVL_EX_SFUNC:
	    if (strcmp(ivl_expr_name(expr), "$ivl_string_method$substr") == 0)
		  string_ex_substr(expr);
	    else if (strcmp(ivl_expr_name(expr), "$ivl_queue_method$pop_back")==0)
		  string_ex_pop(expr);
	    else if (strcmp(ivl_expr_name(expr), "$ivl_queue_method$pop_front")==0)
		  string_ex_pop(expr);
	    else
		  draw_sfunc_string(expr);
	    break;

	  case IVL_EX_UFUNC:
	    draw_ufunc_string(expr);
	    break;

	  default:
	    fallback_eval(expr);
	    break;
      }
}

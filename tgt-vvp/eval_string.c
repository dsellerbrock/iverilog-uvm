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
      unsigned repeat = ivl_expr_repeat(expr);
      unsigned idx;

      assert(ivl_expr_parms(expr) != 0);

	/* IEEE 1800-2017/2023 11.4.12.1 evaluates each operand exactly
	 * once, then replicates the completed unit string. The old nested
	 * repeat loop re-evaluated calls and other side-effecting operands
	 * once per copy. */
      draw_eval_string(ivl_expr_parm(expr,0));

      for (idx = 1 ; idx < ivl_expr_parms(expr) ; idx += 1) {
	    ivl_expr_t sub = ivl_expr_parm(expr,idx);

	      /* Special case: If operand is a string literal,
	         then concat it using the %concati/str instruction. */
	    if (ivl_expr_type(sub) == IVL_EX_STRING) {
		  fprintf(vvp_out, "    %%concati/str \"%s\";\n",
			  ivl_expr_string(sub));
		  continue;
	    }

	    draw_eval_string(sub);
	    fprintf(vvp_out, "    %%concat/str;\n");
      }

      if (repeat != 1) {
	    int repeat_ix = allocate_word();
	    fprintf(vvp_out, "    %%pushi/vec4 %u, 0, 32;\n", repeat);
	    fprintf(vvp_out, "    %%ix/vec4 %d;\n", repeat_ix);
	    fprintf(vvp_out, "    %%rep/str/u %d;\n", repeat_ix);
	    clr_word(repeat_ix);
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
	/* Indexed queue or plain-darray property: element access
	 * within the container value (%load/qo/str serves both). */
      int queue_indexed = property_is_indexed_queue_expr_(expr)
	    || property_is_indexed_darray_expr_(expr);
      int assoc_indexed = property_is_assoc_indexed_expr_(expr);
      ivl_type_t declared_prop_type = property_expr_type_(expr);
      int fixed_idx_word = 0;
      int fixed_idx_x_flag = -1;
      int fixed_idx_in_range_flag = -1;

      if (idx_expr && !queue_indexed && !assoc_indexed
	  && property_selects_fixed_uarray_slot_(expr)) {
	    fixed_idx_word = allocate_word();
	    draw_fixed_uarray_slot_index_(idx_expr, declared_prop_type,
					 fixed_idx_word, &fixed_idx_x_flag,
					 &fixed_idx_in_range_flag);
      }

      if (sig) {
	    fprintf(vvp_out, "    %%load/obj v%p_0;\n", sig);
      } else if (base_expr && ivl_expr_type(base_expr) == IVL_EX_NULL) {
	      /* Compile-progress fallback: null receiver property access
	         yields an empty string. */
	    fprintf(vvp_out, "    %%pushi/str \"\";\n");
	    if (fixed_idx_word) clr_word(fixed_idx_word);
	    if (fixed_idx_x_flag >= 0) clr_flag(fixed_idx_x_flag);
	    if (fixed_idx_in_range_flag >= 0)
		  clr_flag(fixed_idx_in_range_flag);
	    return;
      } else {
	    draw_eval_object(base_expr);
      }
      fprintf(vvp_out, "    %%test_nul/obj;\n");
      fprintf(vvp_out, "    %%jmp/1 T_%u.%u, 4;\n", thread_count, lab_null);
      if (fixed_idx_x_flag >= 0) {
	    fprintf(vvp_out,
		    "    %%jmp/1xz T_%u.%u, %d; invalid fixed property slot\n",
		    thread_count, lab_null, fixed_idx_x_flag);
	    fprintf(vvp_out,
		    "    %%jmp/0xz T_%u.%u, %d; fixed property slot out of range\n",
		    thread_count, lab_null, fixed_idx_in_range_flag);
      }
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
	      } else if (idx_expr) {
		    /* Element of a string-array property (`obj.arr[i]`). */
		  if (!fixed_idx_word)
			draw_eval_expr_into_integer(idx_expr, 3);
		  fprintf(vvp_out, "    %%prop/str/i %u, %d;\n", pidx,
			  fixed_idx_word ? fixed_idx_word : 3);
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
      if (fixed_idx_word) clr_word(fixed_idx_word);
      if (fixed_idx_x_flag >= 0) clr_flag(fixed_idx_x_flag);
      if (fixed_idx_in_range_flag >= 0)
	    clr_flag(fixed_idx_in_range_flag);
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
	/* An integral select can reach this evaluator through an explicit
	 * string cast, or through the narrow string-byte-select concatenation
	 * compatibility path. Evaluate the selected vector exactly once and
	 * convert its bytes; treating every non-container select as an
	 * unsupported string container silently produced the empty string. */
      if (ivl_expr_value(expr) == IVL_VT_BOOL
	  || ivl_expr_value(expr) == IVL_VT_LOGIC) {
	    draw_eval_vec4(expr);
	    fprintf(vvp_out, "    %%pushv/str; Cast selected BOOL/LOGIC to string\n");
	    return;
      }

	/* The sube references the expression to be selected from. */
      ivl_expr_t sube = ivl_expr_oper1(expr);
	/* This is the select expression */
      ivl_expr_t shift= ivl_expr_oper2(expr);

	/* sube may be a null/unresolved placeholder from compile-progress fallbacks. */
	/* Chained keyed read through a nested associative array
	   (aa[k1][k2] in string context): load the inner element
	   handle, then do a keyed string load through it (the non-sig
	   %aa/load forms peek their receiver from the object stack). */
      if (ivl_expr_type(sube) == IVL_EX_SELECT) {
	    ivl_type_t inner = receiver_container_type_(sube);
	    if (inner && ivl_type_base(inner) == IVL_VT_QUEUE
		&& ivl_type_queue_assoc_compat(inner)) {
		  const char*key_kind;
		  draw_eval_object(sube);
		  key_kind = draw_eval_assoc_key_(shift, 0);
		  fprintf(vvp_out, "    %%aa/load/str/%s;\n", key_kind);
		  fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
		  return;
	    }

	      /* POSITIONAL nested container in string context:
	         qq[i][j] where qq is a queue/darray whose elements are
	         string queues/darrays. This fell through to the
	         empty-string fallback below, so every element READ was a
	         compile-time "" -- sizes right, contents 'lost', no
	         diagnostic (recovery D5). Load the inner container
	         object, then do an indexed string load through it. */
	    if (inner && (ivl_type_base(inner) == IVL_VT_QUEUE
			  || ivl_type_base(inner) == IVL_VT_DARRAY)
		&& !ivl_type_queue_assoc_compat(inner)) {
		  draw_eval_object(sube);
		  draw_eval_expr_into_integer(shift, 3);
		  fprintf(vvp_out, "    %%load/qo/str;\n");
		  return;
	    }
      }

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

	      /* `maps[outer][key]' has a signal whose declared leaf type is
	       * associative, but SUBE already carries the fixed outer-word
	       * selection. Loading vSIG_0 as though the map were scalar drops
	       * that selection. Materialize the selected map object first, then
	       * perform the ordinary keyed read through the object-stack receiver. */
	    if (net_type && ivl_type_queue_assoc_compat(net_type)
		&& ivl_signal_dimensions(sig) > 0
		&& ivl_expr_type(sube) == IVL_EX_SIGNAL
		&& ivl_expr_oper1(sube)) {
		  const char*key_kind;
		  draw_eval_object(sube);
		  key_kind = draw_eval_assoc_key_(shift, 0);
		  fprintf(vvp_out, "    %%aa/load/str/%s;\n", key_kind);
		  fprintf(vvp_out, "    %%pop/obj 1, 0; fixed outer map receiver\n");
		  return;
	    }

	      /* Dynamic array / queue of strings. */
	    if (sig_type == IVL_VT_DARRAY || sig_type == IVL_VT_QUEUE) {
                  if (net_type && ivl_type_queue_assoc_compat(net_type)
                      && expr_is_object_assoc_key_(shift)) {
                        draw_eval_object(shift);
                        fprintf(vvp_out, "    %%aa/load/sig/str/obj v%p_0;\n", sig);
                        return;
                  }
                  /* M4-av: string-VALUED associative array with a string or
                     integral key. Previously only object keys were handled
                     here; string and integer keys fell through to the
                     POSITIONAL %load/dar/str below and read the empty
                     default (a silent value loss on a module-static
                     `string s[int]` / `string s[string]`; class-member
                     assoc read via %prop/obj was unaffected). Push the key,
                     push the assoc object, load, then pop the object. */
                  if (net_type && ivl_type_queue_assoc_compat(net_type)
                      && expr_is_string_assoc_key_(shift)) {
                        draw_eval_string(shift);
                        fprintf(vvp_out, "    %%load/obj v%p_0;\n", sig);
                        fprintf(vvp_out, "    %%aa/load/str/str;\n");
                        fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
                        return;
                  }
                  if (net_type && ivl_type_queue_assoc_compat(net_type)) {
                        draw_eval_vec4(shift);
                        fprintf(vvp_out, "    %%load/obj v%p_0;\n", sig);
                        fprintf(vvp_out, "    %%aa/load/str/v;\n");
                        fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
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
	    ivl_type_t prop_type = property_expr_type_(sube);
	    ivl_type_t value_type = ivl_expr_net_type(sube);
	    int positional_container = expr_is_dynarray_container_(sube);
	    /* An indexed associative property can itself yield a queue of
	         strings (`obj.map[key][pos]`).  Its declared property type is
	         still the OUTER associative array, but the expression net type
	         is the selected queue value.  Prefer that result type so the
	         second index remains positional instead of being mistaken for
	         another associative key. */
	    if (!value_type)
		  value_type = prop_type;
	    if (value_type
		&& ivl_type_base(value_type) == IVL_VT_QUEUE
		&& ivl_type_queue_assoc_compat(value_type)) {
		  const char*key_kind;
		  draw_eval_object(sube);
		  key_kind = draw_eval_assoc_key_(shift, 0);
		  fprintf(vvp_out, "    %%aa/load/str/%s;\n", key_kind);
		  fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
		  return;
	    }
	    if (value_type
		&& (ivl_type_base(value_type) == IVL_VT_DARRAY
		    || (ivl_type_base(value_type) == IVL_VT_QUEUE
			&& !ivl_type_queue_assoc_compat(value_type))))
		  positional_container = 1;
	    if (positional_container) {
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
	if (strncmp(ivl_expr_name(expr), "$ivl_vif_func$", 14) == 0) {
	      if (ivl_expr_value(expr) == IVL_VT_STRING) {
		    vvp_errors += draw_vif_function_call(expr);
		    return;
	      }
	      if (ivl_expr_value(expr) == IVL_VT_BOOL
		  || ivl_expr_value(expr) == IVL_VT_LOGIC) {
		    vvp_errors += draw_vif_function_call(expr);
		    fprintf(vvp_out, "    %%pushv/str; Cast VIF result to string\n");
		    return;
	      }
	}

	/* A system function used where a string is required, but whose
	   own value type is not a string. This used to be a bare
	   assert(), so `string s; s = $time();' -- or any typo'd
	   `$bogus()' -- ABORTED the compiler with a raw assertion
	   message and exit 134 instead of diagnosing the source. Report
	   it and emit an empty string so the rest of the run can still
	   produce diagnostics. */
	/* IEEE 1800-2017 6.24.3 permits an integral expression to be
	   explicitly converted to string (and string assignment uses the
	   same byte conversion). Preserve the system-function evaluation
	   and convert its packed bytes instead of diagnosing the function's
	   underlying integral return type. */
      if (ivl_expr_value(expr) == IVL_VT_BOOL
	  || ivl_expr_value(expr) == IVL_VT_LOGIC) {
	    draw_eval_vec4(expr);
	    fprintf(vvp_out, "    %%pushv/str;\n");
	    return;
      }
      if (ivl_expr_value(expr) != IVL_VT_STRING) {
	    fprintf(stderr, "%s:%u: vvp.tgt error: system function %s does "
		    "not return a string, but is used where a string is "
		    "required.\n",
		    ivl_expr_file(expr), ivl_expr_lineno(expr),
		    ivl_expr_name(expr));
	    vvp_errors += 1;
	    fprintf(vvp_out, "    %%pushi/str \"\";\n");
	    return;
      }

    /* Streaming concatenation in a string context (IEEE 1800-2017
       11.4.14, e.g. joining a queue of strings): build the stream and
       convert the bytes to a string. */
    if (strncmp(ivl_expr_name(expr), "$ivl_stream$", 12) == 0) {
	  draw_stream_pack_pieces(expr, 0);
	  fprintf(vvp_out, "    %%pushv/str;\n");
	  return;
    }

    draw_vpi_sfunc_call(expr);
}

/* Phase 63a/A2: string-typed ternary
 *
 *    s = cond ? tru_str : fal_str
 *
 * Evaluate cond; jump-on-true to push tru, otherwise push fal.  No
 * blending for x/z — pick the false branch (matches the SV-2017
 * "indeterminate => either value" relaxation).
 */
static void draw_ternary_string(ivl_expr_t expr)
{
      ivl_expr_t cond = ivl_expr_oper1(expr);
      ivl_expr_t true_ex = ivl_expr_oper2(expr);
      ivl_expr_t false_ex = ivl_expr_oper3(expr);

      unsigned lab_true = local_count++;
      unsigned lab_out = local_count++;
      int cond_flag = allocate_flag();

      draw_eval_vec4(cond);
      if (ivl_expr_width(cond) > 1)
            fprintf(vvp_out, "    %%or/r;\n");
      fprintf(vvp_out, "    %%flag_set/vec4 %d;\n", cond_flag);

      fprintf(vvp_out, "    %%jmp/1  T_%u.%u, %d;\n",
              thread_count, lab_true, cond_flag);

      /* False branch */
      draw_eval_string(false_ex);
      fprintf(vvp_out, "    %%jmp T_%u.%u;\n", thread_count, lab_out);

      /* True branch */
      fprintf(vvp_out, "T_%u.%u ;\n", thread_count, lab_true);
      draw_eval_string(true_ex);

      fprintf(vvp_out, "T_%u.%u ;\n", thread_count, lab_out);
      clr_flag(cond_flag);
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
	    else if (strcmp(ivl_expr_name(expr), "$ivl_queue$last") == 0) {
		  assert(ivl_expr_parms(expr) == 1);
		  draw_eval_object(ivl_expr_parm(expr, 0));
		  fprintf(vvp_out, "    %%dup/obj/ref; queue-last receiver alias\n");
		  fprintf(vvp_out, "    %%qsize/o;\n");
		  fprintf(vvp_out, "    %%pushi/vec4 1, 0, 32;\n");
		  fprintf(vvp_out, "    %%sub;\n");
		  fprintf(vvp_out, "    %%ix/vec4 3;\n");
		  fprintf(vvp_out, "    %%load/qo/str;\n");
	    }
	    else if (strcmp(ivl_expr_name(expr), "$ivl_queue_method$pop_back")==0)
		  string_ex_pop(expr);
	    else if (strcmp(ivl_expr_name(expr), "$ivl_queue_method$pop_front")==0)
		  string_ex_pop(expr);
	    else if (strcmp(ivl_expr_name(expr),
			    "$ivl_class_method$get_randstate") == 0) {
		    /* M3B-5 (IEEE 1800-2017 18.13.3): push the object, then
		       %get_randstate replaces it with the state string. */
		  draw_eval_object(ivl_expr_parm(expr, 0));
		  fprintf(vvp_out, "    %%get_randstate;\n");
	    }
	    else if (strcmp(ivl_expr_name(expr), "$ivl_string$repeat") == 0) {
		  /* Phase 63b/string-replicate: parm0=unit string,
		     parm1=count vec4. Build the unit string, preserve every
		     caller-owned index register while evaluating the count, and
		     retain the count's declared signedness in the repetition
		     opcode. */
		  int repeat_ix = allocate_word();
		  draw_eval_string(ivl_expr_parm(expr, 0));
		  draw_eval_vec4(ivl_expr_parm(expr, 1));
		  fprintf(vvp_out, ivl_expr_signed(ivl_expr_parm(expr, 1))
			? "    %%ix/vec4/s %d;\n" : "    %%ix/vec4 %d;\n",
			repeat_ix);
		  fprintf(vvp_out, ivl_expr_signed(ivl_expr_parm(expr, 1))
			? "    %%rep/str/s %d;\n" : "    %%rep/str/u %d;\n",
			repeat_ix);
		  clr_word(repeat_ix);
	    }
	    else
		  draw_sfunc_string(expr);
	    break;

	  case IVL_EX_UFUNC:
	    draw_ufunc_string(expr);
	    break;

	  case IVL_EX_TERNARY:
	    /* Phase 63a/A2: string-typed ternary */
	    draw_ternary_string(expr);
	    break;

	  default:
	    fallback_eval(expr);
	    break;
      }
}

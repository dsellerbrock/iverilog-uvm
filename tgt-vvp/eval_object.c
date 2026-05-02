/*
 * Copyright (c) 2012-2025 Stephen Williams (steve@icarus.com)
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

void darray_new(ivl_type_t element_type, unsigned size_reg)
{
      static int warned_unhandled_elem_type = 0;
      int wid;
      const char*signed_char;
      ivl_variable_type_t type = ivl_type_base(element_type);

      if ((type == IVL_VT_BOOL) || (type == IVL_VT_LOGIC)) {
	    wid = ivl_type_packed_width(element_type);
	    signed_char = ivl_type_signed(element_type) ? "s" : "";
      } else {
	    wid = 0;
	    signed_char = "";
      }

      switch (type) {
	  case IVL_VT_REAL:
	    fprintf(vvp_out, "    %%new/darray %u, \"r\";\n",
	                     size_reg);
	    break;

	  case IVL_VT_STRING:
	    fprintf(vvp_out, "    %%new/darray %u, \"S\";\n",
	                     size_reg);
	    break;

	  case IVL_VT_BOOL:
	    fprintf(vvp_out, "    %%new/darray %u, \"%sb%d\";\n",
	                     size_reg, signed_char, wid);
	    break;

	  case IVL_VT_LOGIC:
	    fprintf(vvp_out, "    %%new/darray %u, \"%sv%d\";\n",
	                     size_reg, signed_char, wid);
	    break;

	  case IVL_VT_CLASS:
	  case IVL_VT_DARRAY:
	  case IVL_VT_QUEUE:
	  case IVL_VT_NO_TYPE:
	    /* Expected compile-progress path: object-like and unresolved
	       element types use object-array storage. */
	    fprintf(vvp_out, "    %%new/darray %u, \"o\";\n", size_reg);
	    break;

	  default:
	    if (!warned_unhandled_elem_type) {
		  fprintf(stderr, "Warning: darray_new: unhandled element type %d;"
			  " using object array"
			  " (further similar warnings suppressed)\n", type);
		  warned_unhandled_elem_type = 1;
	    }
	    fprintf(vvp_out, "    %%new/darray %u, \"o\";\n", size_reg);
	    break;
      }

      clr_word(size_reg);
}

static int eval_darray_new(ivl_expr_t ex)
{
      unsigned size_reg = allocate_word();
      ivl_expr_t size_expr = ivl_expr_oper1(ex);
      ivl_expr_t init_expr = ivl_expr_oper2(ex);
      draw_eval_expr_into_integer(size_expr, size_reg);

	// The new function has a net_type that contains the details
	// of the type.
      ivl_type_t net_type = ivl_expr_net_type(ex);
      assert(net_type);

      ivl_type_t element_type = ivl_type_element(net_type);
      assert(element_type);

      darray_new(element_type, size_reg);

      if (init_expr && ivl_expr_type(init_expr)==IVL_EX_ARRAY_PATTERN) {
	    unsigned idx;
	    switch (ivl_type_base(element_type)) {
		case IVL_VT_BOOL:
		case IVL_VT_LOGIC:
		  for (idx = 0 ; idx < ivl_expr_parms(init_expr) ; idx += 1) {
			draw_eval_vec4(ivl_expr_parm(init_expr,idx));
			fprintf(vvp_out, "    %%ix/load 3, %u, 0;\n", idx);
			fprintf(vvp_out, "    %%set/dar/obj/vec4 3;\n");
			fprintf(vvp_out, "    %%pop/vec4 1;\n");
		  }
		  break;
		case IVL_VT_REAL:
		  for (idx = 0 ; idx < ivl_expr_parms(init_expr) ; idx += 1) {
			draw_eval_real(ivl_expr_parm(init_expr,idx));
			fprintf(vvp_out, "    %%ix/load 3, %u, 0;\n", idx);
			fprintf(vvp_out, "    %%set/dar/obj/real 3;\n");
			fprintf(vvp_out, "    %%pop/real 1;\n");
		  }
		  break;
		case IVL_VT_STRING:
		  for (idx = 0 ; idx < ivl_expr_parms(init_expr) ; idx += 1) {
			draw_eval_string(ivl_expr_parm(init_expr,idx));
			fprintf(vvp_out, "    %%ix/load 3, %u, 0;\n", idx);
			fprintf(vvp_out, "    %%set/dar/obj/str 3;\n");
			fprintf(vvp_out, "    %%pop/str 1;\n");
		  }
		  break;
			default:
			  fprintf(stderr, "Warning: darray new array-pattern init: unsupported element type %d; skipping init\n",
				  ivl_type_base(element_type));
			  break;
		    }
      } else if (init_expr && (ivl_expr_value(init_expr) == IVL_VT_DARRAY)) {
		  draw_eval_object(init_expr);
		  fprintf(vvp_out, "    %%scopy;\n");

      } else if (init_expr && number_is_immediate(size_expr,32,0)) {
	      /* In this case, there is an init expression, the
		 expression is NOT an array_pattern, and the size
		 expression used to calculate the size of the array is
		 a constant. Generate an unrolled set of assignments. */
	    long idx;
	    long cnt = get_number_immediate(size_expr);
	    unsigned wid;
	    switch (ivl_type_base(element_type)) {
		case IVL_VT_BOOL:
		case IVL_VT_LOGIC:
		  wid = ivl_type_packed_width(element_type);
		  for (idx = 0 ; idx < cnt ; idx += 1) {
			draw_eval_vec4(init_expr);
			fprintf(vvp_out, "    %%parti/%c %u, %ld, 6;\n",
                                ivl_expr_signed(init_expr) ? 's' : 'u', wid, idx * wid);
			fprintf(vvp_out, "    %%ix/load 3, %ld, 0;\n", cnt - idx - 1);
			fprintf(vvp_out, "    %%set/dar/obj/vec4 3;\n");
			fprintf(vvp_out, "    %%pop/vec4 1;\n");
		  }
		  break;
		case IVL_VT_REAL:
		  draw_eval_real(init_expr);
		  for (idx = 0 ; idx < cnt ; idx += 1) {
			fprintf(vvp_out, "    %%ix/load 3, %ld, 0;\n", idx);
			fprintf(vvp_out, "    %%set/dar/obj/real 3;\n");
		  }
		  fprintf(vvp_out, "    %%pop/real 1;\n");
		  break;
		case IVL_VT_STRING:
		  draw_eval_string(init_expr);
		  for (idx = 0 ; idx < cnt ; idx += 1) {
			fprintf(vvp_out, "    %%ix/load 3, %ld, 0;\n", idx);
			fprintf(vvp_out, "    %%set/dar/obj/str 3;\n");
		  }
		  fprintf(vvp_out, "    %%pop/str 1;\n");
		  break;
			default:
			  fprintf(stderr, "Warning: darray new scalar init: unsupported element type %d; skipping init\n",
				  ivl_type_base(element_type));
			  break;
		    }

	      } else if (init_expr) {
		    fprintf(stderr, "Warning: darray new: unsupported dynamic-size init expression; skipping init\n");
	      }

      return 0;
}

/* Track class types whose .class definitions have been emitted inline.
 * Parameterized class specializations may not be attached to any scope,
 * so we emit their definition the first time they appear in %new/cobj. */
#define MAX_EMITTED_CLASSES 256
static ivl_type_t emitted_classes[MAX_EMITTED_CLASSES];
static unsigned emitted_classes_count = 0;

static void ensure_class_type_emitted(ivl_type_t class_type)
{
      unsigned idx;
      int found = 0;

      if (!class_type)
	    return;

      for (idx = 0; idx < emitted_classes_count; idx++) {
	    if (emitted_classes[idx] == class_type) {
		  found = 1;
		  break;
	    }
      }
      if (found)
	    return;

      if (emitted_classes_count < MAX_EMITTED_CLASSES)
	    emitted_classes[emitted_classes_count++] = class_type;

      fprintf(vvp_out, "; Inline class definition for specialized/interface type\n");
      draw_class_in_scope(class_type);
}

static int eval_class_new(ivl_expr_t ex)
{
      ivl_type_t class_type = ivl_expr_net_type(ex);
      ensure_class_type_emitted(class_type);

      fprintf(vvp_out, "    %%new/cobj C%p;\n", class_type);
      return 0;
}

static int eval_object_null(ivl_expr_t ex)
{
      (void)ex; /* Parameter is not used. */
      fprintf(vvp_out, "    %%null;\n");
      return 0;
}

static int eval_object_scope(ivl_expr_t ex)
{
      ivl_scope_t scope = ivl_expr_scope(ex);
      ivl_type_t class_type = ivl_expr_net_type(ex);

      if (!scope || !class_type || ivl_type_base(class_type) != IVL_VT_CLASS) {
	    fprintf(vvp_out, "    %%null; ; invalid virtual-interface scope fallback\n");
	    return 0;
      }

      ensure_class_type_emitted(class_type);
      fprintf(vvp_out, "    %%new/vif S_%p, C%p;\n", scope, class_type);
      return 0;
}

static int eval_object_property(ivl_expr_t expr)
{
      ivl_signal_t sig = ivl_expr_signal(expr);
      unsigned pidx = ivl_expr_property_idx(expr);
      ivl_expr_t base_expr = ivl_expr_oper2(expr);
      unsigned lab_null = local_count++;
      unsigned lab_out = local_count++;

      int idx = 0;
      ivl_expr_t idx_expr = 0;
      int queue_indexed = property_is_indexed_queue_expr_(expr);
      int assoc_indexed = property_is_assoc_indexed_expr_(expr);

	/* If there is an array index expression, then this is an
	   array'ed property, and we need to calculate the index for
	   the expression. */
      if ( (idx_expr = ivl_expr_oper1(expr)) ) {
	    if (!queue_indexed && !assoc_indexed) {
		  idx = allocate_word();
		  draw_eval_expr_into_integer(idx_expr, idx);
	    }
      }

      if (sig) {
	    fprintf(vvp_out, "    %%load/obj v%p_0;\n", sig);
      } else if (base_expr && ivl_expr_type(base_expr) == IVL_EX_NULL) {
	      /* Compile-progress fallback: null receiver property access
	         yields a null object directly. */
	    fprintf(vvp_out, "    %%null;\n");
	    if (idx != 0) clr_word(idx);
	    return 0;
      } else {
	    draw_eval_object(base_expr);
      }
      fprintf(vvp_out, "    %%test_nul/obj;\n");
      fprintf(vvp_out, "    %%jmp/1 T_%u.%u, 4;\n", thread_count, lab_null);
      if (assoc_indexed) {
            const char*key_kind;
	    fprintf(vvp_out, "    %%prop/obj %u, 0; eval_assoc_property\n", pidx);
            key_kind = draw_eval_assoc_key_(idx_expr, 0);
            fprintf(vvp_out, "    %%aa/load/obj/%s;\n", key_kind);
            fprintf(vvp_out, "    %%pop/obj 2, 1;\n");
	      } else if (queue_indexed) {
		    if (!emit_property_queue_last_index_(expr, pidx, 3))
			  draw_eval_expr_into_integer(idx_expr, 3);
		    fprintf(vvp_out, "    %%prop/obj %u, 0; eval_queue_property\n", pidx);
		    fprintf(vvp_out, "    %%load/qo/obj;\n");
		    fprintf(vvp_out, "    %%pop/obj 1, 1;\n");
	      } else {
	    fprintf(vvp_out, "    %%prop/obj %u, %d; eval_object_property\n", pidx, idx);
	    fprintf(vvp_out, "    %%pop/obj 1, 1;\n");
      }
      fprintf(vvp_out, "    %%jmp T_%u.%u;\n", thread_count, lab_out);
      fprintf(vvp_out, "T_%u.%u;\n", thread_count, lab_null);
      fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
      fprintf(vvp_out, "    %%null;\n");
      fprintf(vvp_out, "T_%u.%u;\n", thread_count, lab_out);

      if (idx != 0) clr_word(idx);
      return 0;
}

static int eval_object_shallowcopy(ivl_expr_t ex)
{
      int errors = 0;
      ivl_expr_t dest = ivl_expr_oper1(ex);
      ivl_expr_t src  = ivl_expr_oper2(ex);

      errors += draw_eval_object(dest);
      errors += draw_eval_object(src);

	/* The %scopy opcode pops the top of the object stack as the
	   source object, and shallow-copies it to the new top, the
	   destination object. The destination is left on the top of
	   the stack. */
      fprintf(vvp_out, "    %%scopy;\n");

      return errors;
}

static int eval_object_signal(ivl_expr_t expr)
{
      ivl_signal_t sig = ivl_expr_signal(expr);

	/* Simple case: This is a simple variable. Generate a load
	   statement to load the string into the stack. */
      if (ivl_signal_dimensions(sig) == 0) {
	    fprintf(vvp_out, "    %%load/obj v%p_0;\n", sig);
	    return 0;
      }

	/* There is a word select expression, so load the index into a
	   register and load from the array. */
      ivl_expr_t word_ex = ivl_expr_oper1(expr);
      int word_ix = allocate_word();
      draw_eval_expr_into_integer(word_ex, word_ix);
      note_array_signal_use(sig);
      fprintf(vvp_out, "    %%load/obja v%p, %d;\n", sig, word_ix);
      clr_word(word_ix);

      return 0;
}

static int eval_object_ufunc(ivl_expr_t ex)
{
      draw_ufunc_object(ex);
      return 0;
}

/* Handle IVL_EX_ARRAY in object context without assuming oper1 API support. */
static int eval_object_array(ivl_expr_t expr)
{
      ivl_signal_t sig = ivl_expr_signal(expr);
      if (!sig) {
	    fprintf(vvp_out, "    %%null; ; array-no-signal fallback\n");
	    return 0;
      }

      if (ivl_signal_dimensions(sig) == 0) {
	    fprintf(vvp_out, "    %%load/obj v%p_0;\n", sig);
	    return 0;
      }

      /* ivl_expr_oper1() is not valid for IVL_EX_ARRAY in this backend API;
         use deterministic index-0 fallback for object array access here. */
      fprintf(vvp_out, "    %%ix/load 3, 0, 0;\n");
      note_array_signal_use(sig);
      fprintf(vvp_out, "    %%load/obja v%p, 3;\n", sig);
      return 0;
}

/* Handle IVL_EX_SELECT: element access on a darray/queue of objects.
 * Emits the index into word 3, then %load/dar/obj. */
static int eval_object_select(ivl_expr_t expr)
{
      ivl_expr_t sube  = ivl_expr_oper1(expr);
      ivl_expr_t index = ivl_expr_oper2(expr);
      unsigned lab_null;
      unsigned lab_out;
      int idx_word = 0;

      if (!index) {
	    /* Compile-progress fallback: missing index defaults to 0. */
	    fprintf(vvp_out, "    %%ix/load 3, 0, 0;\n");
	    index = 0;
      }

      if (expr_is_queue_container_(sube) &&
          ivl_expr_type(sube) != IVL_EX_SIGNAL &&
          ivl_expr_type(sube) != IVL_EX_ARRAY &&
          ivl_expr_type(sube) != IVL_EX_PROPERTY) {
	    draw_eval_object(sube);
	    if (index)
		  draw_eval_expr_into_integer(index, 3);
	    else
		  fprintf(vvp_out, "    %%ix/load 3, 0, 0;\n");
	    fprintf(vvp_out, "    %%load/qo/obj;\n");
	    return 0;
      }

      /* Select from object property arrays: obj.prop[idx]
       * arrives as SELECT(PROPERTY(obj.prop), idx). */
      if (ivl_expr_type(sube) == IVL_EX_PROPERTY) {
	    ivl_signal_t sig = ivl_expr_signal(sube);
	    unsigned pidx = ivl_expr_property_idx(sube);
	    ivl_expr_t base_expr = ivl_expr_oper2(sube);
	    ivl_expr_t prop_idx = ivl_expr_oper1(sube);
	    lab_null = local_count++;
	    lab_out = local_count++;

	    if (expr_is_assoc_queue_container_(sube)) {
		  if (prop_idx) {
			fprintf(vvp_out, "    %%null; ; nested assoc property select fallback\n");
			return 0;
		  }

		  if (sig) {
			fprintf(vvp_out, "    %%load/obj v%p_0;\n", sig);
		  } else if (base_expr && ivl_expr_type(base_expr) == IVL_EX_NULL) {
			fprintf(vvp_out, "    %%null;\n");
		  } else if (!base_expr) {
			fprintf(vvp_out, "    %%null;\n");
		  } else {
			draw_eval_object(base_expr);
		  }

		  fprintf(vvp_out, "    %%test_nul/obj;\n");
		  fprintf(vvp_out, "    %%jmp/1 T_%u.%u, 4;\n", thread_count, lab_null);
		  fprintf(vvp_out, "    %%prop/obj %u, 0; eval_assoc_select/property\n", pidx);
		  if (!index) {
			fprintf(vvp_out, "    %%pushi/vec4 0, 0, 32;\n");
			fprintf(vvp_out, "    %%aa/load/obj/v;\n");
		  } else {
			const char*key_kind = draw_eval_assoc_key_(index, 0);
			fprintf(vvp_out, "    %%aa/load/obj/%s;\n", key_kind);
		  }
		  fprintf(vvp_out, "    %%pop/obj 2, 1;\n");
		  fprintf(vvp_out, "    %%jmp T_%u.%u;\n", thread_count, lab_out);
		  fprintf(vvp_out, "T_%u.%u;\n", thread_count, lab_null);
		  fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
		  fprintf(vvp_out, "    %%null;\n");
		  fprintf(vvp_out, "T_%u.%u;\n", thread_count, lab_out);
		  return 0;
	    }

	    if (expr_is_queue_container_(sube)) {
		  draw_eval_object(sube);
		  if (index)
			draw_eval_expr_into_integer(index, 3);
		  else
			fprintf(vvp_out, "    %%ix/load 3, 0, 0;\n");
		  fprintf(vvp_out, "    %%load/qo/obj;\n");
		  return 0;
	    }

	    if (prop_idx) {
		  fprintf(vvp_out, "    %%null; ; nested property select fallback\n");
		  return 0;
	    }

	    idx_word = allocate_word();
	    if (index) {
		  draw_eval_expr_into_integer(index, idx_word);
	    } else {
		  fprintf(vvp_out, "    %%ix/load %d, 0, 0;\n", idx_word);
	    }
	    if (sig) {
		  fprintf(vvp_out, "    %%load/obj v%p_0;\n", sig);
	    } else if (base_expr && ivl_expr_type(base_expr) == IVL_EX_NULL) {
		  fprintf(vvp_out, "    %%null;\n");
	    } else if (!base_expr) {
		  fprintf(vvp_out, "    %%null;\n");
	    } else {
		  draw_eval_object(base_expr);
	    }

	    fprintf(vvp_out, "    %%test_nul/obj;\n");
	    fprintf(vvp_out, "    %%jmp/1 T_%u.%u, 4;\n", thread_count, lab_null);
	    fprintf(vvp_out, "    %%prop/obj %u, %d; eval_object_select/property\n", pidx, idx_word);
	    fprintf(vvp_out, "    %%pop/obj 1, 1;\n");
	    fprintf(vvp_out, "    %%jmp T_%u.%u;\n", thread_count, lab_out);
	    fprintf(vvp_out, "T_%u.%u;\n", thread_count, lab_null);
	    fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
	    fprintf(vvp_out, "    %%null;\n");
	    fprintf(vvp_out, "T_%u.%u;\n", thread_count, lab_out);
	    clr_word(idx_word);
	    return 0;
      }

      if (ivl_expr_type(sube) != IVL_EX_SIGNAL &&
          ivl_expr_type(sube) != IVL_EX_ARRAY) {
	    fprintf(stderr, "Warning: eval_object_select: base is not a signal"
		    " at %s:%u (expr_type=%d sube_type=%d sube@%s:%u);"
		    " emitting null fallback\n",
		    ivl_expr_file(expr), ivl_expr_lineno(expr),
		    ivl_expr_type(expr), ivl_expr_type(sube),
		    ivl_expr_file(sube), ivl_expr_lineno(sube));
	    fprintf(vvp_out, "    %%null; ; select base fallback\n");
	    return 0;
      }

      ivl_signal_t sig = ivl_expr_signal(sube);
      ivl_type_t net_type;
      if (!sig) {
	    fprintf(stderr, "Warning: eval_object_select: null signal; emitting null fallback\n");
	    fprintf(vvp_out, "    %%null; ; null sig fallback\n");
	    return 0;
      }

      net_type = ivl_signal_net_type(sig);
      if (net_type && ivl_type_base(net_type) == IVL_VT_QUEUE
          && ivl_type_queue_assoc_compat(net_type)) {
            const char*key_kind = draw_eval_assoc_key_(index, 0);
	    fprintf(vvp_out, "    %%aa/load/sig/obj/%s v%p_0;\n", key_kind, sig);
	    return 0;
      }

      ivl_variable_type_t dtype = ivl_signal_data_type(sig);
      if (dtype != IVL_VT_DARRAY && dtype != IVL_VT_QUEUE) {
	    /* Static array: use %load/obja */
	    int word_ix = allocate_word();
	    draw_eval_expr_into_integer(index, word_ix);
	    note_array_signal_use(sig);
	    fprintf(vvp_out, "    %%load/obja v%p, %d;\n", sig, word_ix);
	    clr_word(word_ix);
	    return 0;
      }

      /* Dynamic array or queue: use %load/dar/obj (index in word 3) */
      draw_eval_expr_into_integer(index, 3);
      fprintf(vvp_out, "    %%load/dar/obj v%p_0;\n", sig);
      return 0;
}

/* Handle IVL_EX_NUMBER in object context: 0 maps to null, others warn. */
static int eval_object_number(ivl_expr_t expr)
{
      if (ivl_expr_value(expr) == IVL_VT_LOGIC) {
	    /* Check if all bits are zero (null handle) */
	    const char*bits = ivl_expr_bits(expr);
	    unsigned wid = ivl_expr_width(expr);
	    unsigned idx;
	    int all_zero = 1;
	    for (idx = 0; idx < wid; idx++) {
		  if (bits[idx] != '0') { all_zero = 0; break; }
	    }
	    if (all_zero) {
		  fprintf(vvp_out, "    %%null; ; number(0) as null object\n");
		  return 0;
	    }
      }
      /* Compile-progress coercion: non-zero numbers in object context map
         to null-object fallback. */
      fprintf(vvp_out, "    %%null; ; number fallback\n");
      return 0;
}

/* Handle IVL_EX_TERNARY in object context. */
static int eval_object_ternary(ivl_expr_t expr)
{
      ivl_expr_t cond     = ivl_expr_oper1(expr);
      ivl_expr_t true_ex  = ivl_expr_oper2(expr);
      ivl_expr_t false_ex = ivl_expr_oper3(expr);

      unsigned lab_false = local_count++;
      unsigned lab_out   = local_count++;

      int use_flag = draw_eval_condition(cond);

      fprintf(vvp_out, "    %%jmp/0 T_%u.%u, %d;\n", thread_count, lab_false, use_flag);
      draw_eval_object(true_ex);
      fprintf(vvp_out, "    %%jmp T_%u.%u;\n", thread_count, lab_out);
      fprintf(vvp_out, "T_%u.%u;\n", thread_count, lab_false);
      draw_eval_object(false_ex);
      fprintf(vvp_out, "T_%u.%u;\n", thread_count, lab_out);

      clr_flag(use_flag);
      return 0;
}

/* Handle system-function expressions in object context. */
static int eval_object_sfunc(ivl_expr_t expr)
{
      const char*name = ivl_expr_name(expr);
      unsigned parm_count = ivl_expr_parms(expr);
      static int warned_non_queue = 0;
      static int warned_pop_back_non_signal = 0;
      static int warned_pop_front_non_signal = 0;

      if (strcmp(name, "$ivl_process$self") == 0) {
	    if (parm_count != 0) {
		  fprintf(stderr, "Warning: %s expects no arguments; ignoring extras\n", name);
	    }
	    fprintf(vvp_out, "    %%process/self;\n");
	    return 0;
      }

      /* Mailbox constructor: $ivl_mailbox$new([bound]) */
      if (strcmp(name, "$ivl_mailbox$new") == 0) {
	    long bound = 0;
	    if (parm_count > 0) {
		  ivl_expr_t bexpr = ivl_expr_parm(expr, 0);
		  if (bexpr && ivl_expr_type(bexpr) == IVL_EX_NUMBER)
			bound = (long)ivl_expr_uvalue(bexpr);
	    }
	    fprintf(vvp_out, "    %%mbx/new %ld;\n", bound);
	    return 0;
      }

      /* Semaphore constructor: $ivl_semaphore$new([initial_count]) */
      if (strcmp(name, "$ivl_semaphore$new") == 0) {
	    long cnt = 0;
	    if (parm_count > 0) {
		  ivl_expr_t cexpr = ivl_expr_parm(expr, 0);
		  if (cexpr && ivl_expr_type(cexpr) == IVL_EX_NUMBER)
			cnt = (long)ivl_expr_uvalue(cexpr);
	    }
	    fprintf(vvp_out, "    %%sem/new %ld;\n", cnt);
	    return 0;
      }

      /* Queue pop methods returning objects are lowered to object qpop opcodes. */
      if (strcmp(name, "$ivl_queue_method$pop_back")==0 ||
          strcmp(name, "$ivl_queue_method$pop_front")==0) {
	    const char*fb = (strcmp(name, "$ivl_queue_method$pop_back")==0) ? "b" : "f";
	    ivl_expr_t arg = (parm_count > 0) ? ivl_expr_parm(expr, 0) : 0;

	    if (arg && ivl_expr_type(arg) == IVL_EX_SIGNAL && ivl_expr_signal(arg)) {
		  fprintf(vvp_out, "    %%qpop/%s/obj v%p_0;\n", fb, ivl_expr_signal(arg));
		  return 0;
	    }
	    if (arg && expr_is_queue_container_(arg)) {
		  draw_eval_object(arg);
		  fprintf(vvp_out, "    %%qpop/o/%s/obj;\n", fb);
		  return 0;
	    }

	    int *warned = (fb[0] == 'b') ? &warned_pop_back_non_signal
					 : &warned_pop_front_non_signal;
	    if (!*warned) {
		  fprintf(stderr, "Warning: %s requires signal, got expr type %d;"
			  " emitting null fallback"
			  " (further similar warnings suppressed)\n",
			  name, arg ? ivl_expr_type(arg) : -1);
		  *warned = 1;
	    }
	    fprintf(vvp_out, "    %%null; ; object qpop fallback\n");
	    return 0;
      }

      /* Phase 63b/B1: queue locator with predicate
       *   $ivl_queue_method$find_with|<kind>(queue, iter_sig, result_sig, pred)
       * Emit an inline loop that walks the queue, sets iter_sig per
       * element, evaluates the predicate, and conditionally pushes
       * to result_sig.  Final value is result_sig loaded as an object.
       *
       * Currently handles BOOL/LOGIC element types (the most common
       * case in UVM); REAL/STRING/object-typed queues fall back to
       * an empty result with a one-time advisory warning. */
      if (strncmp(name, "$ivl_queue_method$find_with|", 28) == 0) {
	    const char*kind = name + 28;
	    int is_index = (strstr(kind, "index") != NULL);
	    int stop_first = (strcmp(kind, "find_first") == 0
			      || strcmp(kind, "find_first_index") == 0);

	    if (parm_count < 5) {
		  fprintf(vvp_out, "    %%null; ; find_with: bad parm count\n");
		  return 0;
	    }
	    ivl_expr_t q_arg = ivl_expr_parm(expr, 0);
	    ivl_expr_t iter_arg = ivl_expr_parm(expr, 1);
	    ivl_expr_t result_arg = ivl_expr_parm(expr, 2);
	    ivl_expr_t idx_arg = ivl_expr_parm(expr, 3);
	    ivl_expr_t pred = ivl_expr_parm(expr, 4);

	    if (!q_arg || ivl_expr_type(q_arg) != IVL_EX_SIGNAL
		|| !ivl_expr_signal(q_arg)
		|| !iter_arg || ivl_expr_type(iter_arg) != IVL_EX_SIGNAL
		|| !ivl_expr_signal(iter_arg)
		|| !result_arg || ivl_expr_type(result_arg) != IVL_EX_SIGNAL
		|| !ivl_expr_signal(result_arg)
		|| !idx_arg || ivl_expr_type(idx_arg) != IVL_EX_SIGNAL
		|| !ivl_expr_signal(idx_arg)
		|| !pred) {
		  fprintf(vvp_out, "    %%null; ; find_with: bad arg shape\n");
		  return 0;
	    }
	    ivl_signal_t q_sig = ivl_expr_signal(q_arg);
	    ivl_signal_t iter_sig = ivl_expr_signal(iter_arg);
	    ivl_signal_t result_sig = ivl_expr_signal(result_arg);
	    ivl_signal_t idx_sig = ivl_expr_signal(idx_arg);

	    ivl_type_t iter_type = ivl_signal_net_type(iter_sig);
	    unsigned iter_wid = ivl_type_packed_width(iter_type);
	    if (iter_wid == 0) iter_wid = 32;
	    ivl_variable_type_t bt = ivl_type_base(iter_type);

	    /* Per-element-type bytecode shape:
	     *   load_elem    — fetch q[idx] onto the appropriate stack
	     *   store_iter   — pop and store into iter_sig
	     *   reload_iter  — push iter_sig back (predicate may consume it)
	     *   store_result — pop value and append to result queue
	     * For find_index variants the result is always a queue of
	     * int32 indices, so the result encoding is "sb32" with v-form
	     * %store/qb/v regardless of the element type. */
	    const char*result_enc;
	    char elem_enc_buf[32];
	    if (is_index) {
		  result_enc = "sb32";
	    } else if (bt == IVL_VT_BOOL || bt == IVL_VT_LOGIC) {
		  const char*sgn = ivl_type_signed(iter_type) ? "s" : "";
		  const char*type_enc = (bt == IVL_VT_BOOL) ? "b" : "v";
		  snprintf(elem_enc_buf, sizeof elem_enc_buf, "%s%s%u",
			   sgn, type_enc, iter_wid);
		  result_enc = elem_enc_buf;
	    } else if (bt == IVL_VT_REAL) {
		  result_enc = "r";
	    } else if (bt == IVL_VT_STRING) {
		  result_enc = "S";
	    } else if (bt == IVL_VT_CLASS || bt == IVL_VT_DARRAY
		       || bt == IVL_VT_QUEUE || bt == IVL_VT_NO_TYPE) {
		  result_enc = "o";
	    } else {
		  static int warned_unsupp = 0;
		  if (!warned_unsupp) {
			fprintf(stderr, "Warning: %s on unrecognized queue element"
				" type %d (compile-progress: empty result;"
				" further similar warnings suppressed)\n",
				name, (int)bt);
			warned_unsupp = 1;
		  }
		  fprintf(vvp_out, "    %%null; ; find_with: unknown element type\n");
		  return 0;
	    }

	    unsigned lab_top = local_count++;
	    unsigned lab_end = local_count++;
	    unsigned lab_skip = local_count++;
	    int pred_flag = allocate_flag();

	    /* result_sig = empty queue of result element type.
	     * %new/queue takes a single string operand.  ix5 is also
	     * used as the max-size bound for %store/qb/* (0 = unbounded). */
	    fprintf(vvp_out, "    %%ix/load 5, 0, 0;\n");
	    fprintf(vvp_out, "    %%new/queue \"%s\";\n", result_enc);
	    fprintf(vvp_out, "    %%store/obj v%p_0;\n", result_sig);

	    /* idx_sig = 0 */
	    fprintf(vvp_out, "    %%pushi/vec4 0, 0, 32;\n");
	    fprintf(vvp_out, "    %%store/vec4 v%p_0, 0, 32;\n", idx_sig);

	    fprintf(vvp_out, "T_%u.%u ;\n", thread_count, lab_top);
	    /* if (!(idx < qsize)) goto end */
	    fprintf(vvp_out, "    %%load/vec4 v%p_0;\n", idx_sig);
	    fprintf(vvp_out, "    %%qsize v%p_0;\n", q_sig);
	    fprintf(vvp_out, "    %%cmp/s;\n");
	    /* %cmp/s sets flag 5 = lt; jump to end if NOT lt */
	    fprintf(vvp_out, "    %%jmp/0xz T_%u.%u, 5;\n",
		    thread_count, lab_end);

	    /* iter_sig = q[idx_sig] — type-specific load/store pair */
	    fprintf(vvp_out, "    %%ix/getv/s 3, v%p_0;\n", idx_sig);
	    if (bt == IVL_VT_BOOL || bt == IVL_VT_LOGIC) {
		  fprintf(vvp_out, "    %%load/dar/vec4 v%p_0;\n", q_sig);
		  fprintf(vvp_out, "    %%store/vec4 v%p_0, 0, %u;\n",
			  iter_sig, iter_wid);
	    } else if (bt == IVL_VT_REAL) {
		  fprintf(vvp_out, "    %%load/dar/r v%p_0;\n", q_sig);
		  fprintf(vvp_out, "    %%store/real v%p_0;\n", iter_sig);
	    } else if (bt == IVL_VT_STRING) {
		  fprintf(vvp_out, "    %%load/dar/str v%p_0;\n", q_sig);
		  fprintf(vvp_out, "    %%store/str v%p_0;\n", iter_sig);
	    } else { /* CLASS/DARRAY/QUEUE/NO_TYPE — handle via obj */
		  fprintf(vvp_out, "    %%load/dar/obj v%p_0;\n", q_sig);
		  fprintf(vvp_out, "    %%store/obj v%p_0;\n", iter_sig);
	    }

	    /* Evaluate predicate (always returns a vec4 boolean) */
	    draw_eval_vec4(pred);
	    if (ivl_expr_width(pred) > 1)
		  fprintf(vvp_out, "    %%or/r;\n");
	    fprintf(vvp_out, "    %%flag_set/vec4 %d;\n", pred_flag);
	    fprintf(vvp_out, "    %%jmp/0xz T_%u.%u, %d;\n",
		    thread_count, lab_skip, pred_flag);

	    /* Push q[idx] (or idx) into result_sig.  Index variants always
	     * push the int32 idx onto a vec4 queue. */
	    if (is_index) {
		  fprintf(vvp_out, "    %%load/vec4 v%p_0;\n", idx_sig);
		  fprintf(vvp_out, "    %%store/qb/v v%p_0, 5, 32;\n", result_sig);
	    } else if (bt == IVL_VT_BOOL || bt == IVL_VT_LOGIC) {
		  fprintf(vvp_out, "    %%ix/getv/s 3, v%p_0;\n", idx_sig);
		  fprintf(vvp_out, "    %%load/dar/vec4 v%p_0;\n", q_sig);
		  fprintf(vvp_out, "    %%store/qb/v v%p_0, 5, %u;\n",
			  result_sig, iter_wid);
	    } else if (bt == IVL_VT_REAL) {
		  fprintf(vvp_out, "    %%load/real v%p_0;\n", iter_sig);
		  fprintf(vvp_out, "    %%store/qb/r v%p_0, 5;\n", result_sig);
	    } else if (bt == IVL_VT_STRING) {
		  fprintf(vvp_out, "    %%load/str v%p_0;\n", iter_sig);
		  fprintf(vvp_out, "    %%store/qb/str v%p_0, 5;\n", result_sig);
	    } else { /* CLASS/DARRAY/QUEUE/NO_TYPE — store handle via obj */
		  fprintf(vvp_out, "    %%load/obj v%p_0;\n", iter_sig);
		  fprintf(vvp_out, "    %%store/qb/obj v%p_0, 5;\n", result_sig);
	    }

	    if (stop_first)
		  fprintf(vvp_out, "    %%jmp T_%u.%u;\n", thread_count, lab_end);

	    fprintf(vvp_out, "T_%u.%u ;\n", thread_count, lab_skip);
	    /* idx_sig += 1 */
	    fprintf(vvp_out, "    %%load/vec4 v%p_0;\n", idx_sig);
	    fprintf(vvp_out, "    %%pushi/vec4 1, 0, 32;\n");
	    fprintf(vvp_out, "    %%add;\n");
	    fprintf(vvp_out, "    %%store/vec4 v%p_0, 0, 32;\n", idx_sig);
	    fprintf(vvp_out, "    %%jmp T_%u.%u;\n", thread_count, lab_top);

	    fprintf(vvp_out, "T_%u.%u ;\n", thread_count, lab_end);
	    fprintf(vvp_out, "    %%load/obj v%p_0;\n", result_sig);
	    clr_flag(pred_flag);
	    return 0;
      }

      if (!warned_non_queue) {
	    fprintf(stderr, "Warning: eval_object_sfunc: unsupported sfunc '%s'"
		    " in object context; emitting null fallback"
		    " (further similar warnings suppressed)\n", name);
	    warned_non_queue = 1;
      }
      fprintf(vvp_out, "    %%null; ; unsupported object sfunc fallback\n");
      return 0;
}

static int object_expr_uses_aggregate_cobject_(ivl_expr_t expr)
{
      ivl_type_t net_type = expr ? ivl_expr_net_type(expr) : 0;
      if (!net_type)
            return 0;

      return ivl_type_base(net_type) == IVL_VT_NO_TYPE
          && ivl_type_properties(net_type) > 0;
}

static int emit_aggregate_property_store_(ivl_type_t prop_type,
                                          unsigned pidx,
                                          ivl_expr_t value_expr)
{
      int errors = 0;

      if (!prop_type) {
            errors += draw_eval_object(value_expr);
            fprintf(vvp_out, "    %%store/prop/obj %u, 0;\n", pidx);
            return errors;
      }

      switch (ivl_type_base(prop_type)) {
          case IVL_VT_BOOL:
          case IVL_VT_LOGIC: {
            unsigned wid = ivl_type_packed_width(prop_type);
            if (wid == 0)
                  wid = ivl_expr_width(value_expr);
            draw_eval_vec4(value_expr);
            if (ivl_type_base(prop_type) == IVL_VT_BOOL
                && ivl_expr_value(value_expr) != IVL_VT_BOOL)
                  fprintf(vvp_out, "    %%cast2;\n");
            fprintf(vvp_out, "    %%store/prop/v %u, %u;\n", pidx, wid);
            return errors;
          }

          case IVL_VT_REAL:
            draw_eval_real(value_expr);
            fprintf(vvp_out, "    %%store/prop/r %u;\n", pidx);
            return errors;

          case IVL_VT_STRING:
            draw_eval_string(value_expr);
            fprintf(vvp_out, "    %%store/prop/str %u;\n", pidx);
            return errors;

          case IVL_VT_CLASS:
          case IVL_VT_DARRAY:
          case IVL_VT_QUEUE:
          case IVL_VT_NO_TYPE:
          default:
            errors += draw_eval_object(value_expr);
            fprintf(vvp_out, "    %%store/prop/obj %u, 0;\n", pidx);
            return errors;
      }
}

static int eval_object_aggregate_literal_(ivl_expr_t expr)
{
      static int warned_truncated_parms = 0;
      static int warned_concat_repeat = 0;
      ivl_type_t agg_type = ivl_expr_net_type(expr);
      unsigned nprop;
      unsigned nparm;
      unsigned idx;
      int errors = 0;

      if (!object_expr_uses_aggregate_cobject_(expr))
            return -1;

      if (ivl_expr_type(expr) == IVL_EX_CONCAT && ivl_expr_repeat(expr) != 1) {
            if (!warned_concat_repeat) {
                  fprintf(stderr,
                          "Warning: draw_eval_object: unsupported aggregate concat repeat %u"
                          " at %s:%u; using null fallback"
                          " (further similar warnings suppressed)\n",
                          ivl_expr_repeat(expr),
                          ivl_expr_file(expr), ivl_expr_lineno(expr));
                  warned_concat_repeat = 1;
            }
            return -1;
      }

      nprop = ivl_type_properties(agg_type);
      nparm = ivl_expr_parms(expr);
      ensure_class_type_emitted(agg_type);
      fprintf(vvp_out, "    %%new/cobj C%p;\n", agg_type);

      if (nparm > nprop && !warned_truncated_parms) {
            fprintf(stderr,
                    "Warning: draw_eval_object: aggregate literal for %s has %u values for %u members;"
                    " truncating extras"
                    " (further similar warnings suppressed)\n",
                    ivl_type_name(agg_type), nparm, nprop);
            warned_truncated_parms = 1;
      }

      if (nparm > nprop)
            nparm = nprop;

      for (idx = 0; idx < nparm; idx += 1) {
            ivl_type_t prop_type = ivl_type_prop_type(agg_type, idx);
            errors += emit_aggregate_property_store_(prop_type, idx,
                                                     ivl_expr_parm(expr, idx));
      }

      return errors;
}

/* Handle IVL_EX_ARRAY_PATTERN in object context.
 * Compile-progress fallback: use the first element when present. */
static int eval_object_array_pattern(ivl_expr_t expr)
{
      unsigned nparm = ivl_expr_parms(expr);
      int errors;

      errors = eval_object_aggregate_literal_(expr);
      if (errors >= 0)
            return errors;

      if (nparm == 0) {
	    fprintf(vvp_out, "    %%null; ; empty object array-pattern fallback\n");
	    return 0;
      }

      return draw_eval_object(ivl_expr_parm(expr, 0));
}

static int eval_object_unary(ivl_expr_t ex)
{
      ivl_expr_t sub = ivl_expr_oper1(ex);
      ivl_variable_type_t ex_type = ivl_expr_value(ex);

      /* Object-typed unary nodes are typically cast wrappers around an
         object-like subexpression. Preserve the underlying handle instead
         of collapsing to null in object context. */
      if (sub && (ex_type == IVL_VT_CLASS
               || ex_type == IVL_VT_DARRAY
               || ex_type == IVL_VT_QUEUE)) {
	    switch (ivl_expr_opcode(ex)) {
		case '+':
		case '2':
		case 'v':
		case 'r':
		  return draw_eval_object(sub);
		default:
		  break;
	    }
      }

      fprintf(stderr,
	      "Warning: draw_eval_object: unsupported unary expr"
	      " op=%c value=%d sub_value=%d at %s:%u;"
	      " emitting null fallback\n",
	      ivl_expr_opcode(ex),
	      ivl_expr_value(ex),
	      sub ? (int)ivl_expr_value(sub) : -1,
	      ivl_expr_file(ex), ivl_expr_lineno(ex));
      fprintf(vvp_out, "    %%null; ; unsupported unary expr op=%c value=%d fallback\n",
	      ivl_expr_opcode(ex), ivl_expr_value(ex));
      return 0;
}

int draw_eval_object(ivl_expr_t ex)
{
      switch (ivl_expr_type(ex)) {

	  case IVL_EX_NEW:
	    switch (ivl_expr_value(ex)) {
		case IVL_VT_CLASS:
		  return eval_class_new(ex);
		case IVL_VT_DARRAY:
		  return eval_darray_new(ex);
		default:
		  fprintf(vvp_out, "; ERROR: draw_eval_object: Invalid type (%d) for <new>\n",
			  ivl_expr_value(ex));
		  return 0;
	    }

	  case IVL_EX_NULL:
	    return eval_object_null(ex);

	  case IVL_EX_PROPERTY:
	    return eval_object_property(ex);

	  case IVL_EX_SHALLOWCOPY:
	    return eval_object_shallowcopy(ex);

	  case IVL_EX_SIGNAL:
	    return eval_object_signal(ex);

	  case IVL_EX_SCOPE:
	    return eval_object_scope(ex);

	  case IVL_EX_ARRAY:
	    return eval_object_array(ex);

	  case IVL_EX_UFUNC:
	    return eval_object_ufunc(ex);

	  case IVL_EX_SELECT:
	    return eval_object_select(ex);

	  case IVL_EX_UNARY:
	    return eval_object_unary(ex);

	  case IVL_EX_NUMBER:
	    return eval_object_number(ex);

	  case IVL_EX_TERNARY:
	    return eval_object_ternary(ex);

	  case IVL_EX_ARRAY_PATTERN:
	    return eval_object_array_pattern(ex);

	  case IVL_EX_SFUNC:
	    return eval_object_sfunc(ex);

	  case IVL_EX_CONCAT: {
            int errors = eval_object_aggregate_literal_(ex);
            if (errors >= 0)
                  return errors;
            fprintf(stderr, "Warning: draw_eval_object: unknown expression type %d;"
                    " emitting null fallback\n", ivl_expr_type(ex));
            fprintf(vvp_out, "    %%null; ; unknown expr type %d fallback\n", ivl_expr_type(ex));
            return 0;
          }

	  case IVL_EX_BINARY:
	    fprintf(stderr,
		    "Warning: draw_eval_object: unhandled binary expr"
		    " opcode=%c value=%d oper1_type=%d oper1_value=%d"
		    " oper2_type=%d oper2_value=%d at %s:%u;"
		    " emitting null fallback\n",
		    ivl_expr_opcode(ex), ivl_expr_value(ex),
		    ivl_expr_oper1(ex) ? (int)ivl_expr_type(ivl_expr_oper1(ex)) : -1,
		    ivl_expr_oper1(ex) ? (int)ivl_expr_value(ivl_expr_oper1(ex)) : -1,
		    ivl_expr_oper2(ex) ? (int)ivl_expr_type(ivl_expr_oper2(ex)) : -1,
		    ivl_expr_oper2(ex) ? (int)ivl_expr_value(ivl_expr_oper2(ex)) : -1,
		    ivl_expr_file(ex), ivl_expr_lineno(ex));
	    fprintf(vvp_out, "    %%null; ; unhandled expr type %d fallback\n", ivl_expr_type(ex));
	    return 0;

	  default:
	    fprintf(stderr, "Warning: draw_eval_object: unknown expression type %d"
		    " value=%d at %s:%u; emitting null fallback\n",
		    ivl_expr_type(ex), ivl_expr_value(ex),
		    ivl_expr_file(ex), ivl_expr_lineno(ex));
	    fprintf(vvp_out, "    %%null; ; unknown expr type %d fallback\n", ivl_expr_type(ex));
	    return 0;

      }
}

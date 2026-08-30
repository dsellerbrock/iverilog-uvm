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
# include  <stdlib.h>
# include  <assert.h>
# include  <inttypes.h>

/*
 * Map a container element type to the vvp type string used by
 * %new/darray, %stream/to/queue and %stream/to/dar ("r", "S", "b8",
 * "sb32", "v1", ...).  Object-like and unresolved element types map
 * to "o".
 */
void stream_elem_type_text(ivl_type_t element_type, char*buf, size_t bufsz)
{
      ivl_variable_type_t type = ivl_type_base(element_type);
      int wid = 0;
      const char*signed_char = "";

      if ((type == IVL_VT_BOOL) || (type == IVL_VT_LOGIC)) {
	    wid = ivl_type_packed_width(element_type);
	    signed_char = ivl_type_signed(element_type) ? "s" : "";
      }

      switch (type) {
	  case IVL_VT_REAL:
	    snprintf(buf, bufsz, "r");
	    break;
	  case IVL_VT_STRING:
	    snprintf(buf, bufsz, "S");
	    break;
	  case IVL_VT_BOOL:
	    snprintf(buf, bufsz, "%sb%d", signed_char, wid);
	    break;
	  case IVL_VT_LOGIC:
	    snprintf(buf, bufsz, "%sv%d", signed_char, wid);
	    break;
	  default:
	    snprintf(buf, bufsz, "o");
	    break;
      }
}

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
	      /* An object-backed VALUE element (an unpacked struct) needs a
		 live instance in every slot a member write addresses, and
		 `new[]' leaves them nil. Attach a prototype so the runtime
		 can materialize a nil element on first access -- the same
		 service a signal-backed container gets from its functor's
		 declared_type(), which a container held in a class property
		 has no way to reach. Class HANDLE elements get no
		 prototype: their nil elements must stay null. */
	    if (type == IVL_VT_NO_TYPE && ivl_type_properties(element_type) > 0) {
		  ensure_class_type_emitted(element_type);
		  fprintf(vvp_out, "    %%new/cobj C%p; darray element prototype\n",
			  element_type);
		  fprintf(vvp_out, "    %%dar/elem/proto;\n");
	    }
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

/*
 * Emit the runtime evaluation of a "$ivl_stream$pack$<l|r>$<slice>"
 * internal function (streaming concatenation with dynamically sized
 * operands, IEEE 1800-2017 11.4.14).  Operands are evaluated left to
 * right; container and string operands are flattened to their bit
 * streams (11.4.14.1); the pieces are joined with %concat/vec4; and
 * %stream/end/{l,r} applies the block re-ordering (11.4.14.2) plus
 * the fixed-target alignment when tw is nonzero.  The stream is left
 * on the vec4 stack.
 */
int draw_stream_pack_pieces(ivl_expr_t expr, unsigned tw)
{
      const char*name = ivl_expr_name(expr);
      if (strncmp(name, "$ivl_stream$", 12) != 0)
	    return -1;

      const char*tail = name + 12;
      int unpack = 0;
      if (strncmp(tail, "pack$", 5) == 0) {
	    tail += 5;
      } else if (strncmp(tail, "cast$", 5) == 0) {
	    /* A 6.24.3 bit-stream cast has the same source flattening and
	       left-to-right order as a right-stream with slice size 1. The
	       caller emits a strict target conversion after this pack. */
	    tail += 5;
      } else if (strncmp(tail, "unpack$", 7) == 0) {
	    unpack = 1;
	    tail += 7;
      } else {
	    return -1;
      }

      char dir = tail[0];
      unsigned long slice = 1;
      if (tail[1] == '$')
	    slice = strtoul(tail + 2, 0, 10);
      if (slice == 0)
	    slice = 1;

      unsigned parms = ivl_expr_parms(expr);
      assert(parms > 0);

      for (unsigned idx = 0 ; idx < parms ; idx += 1) {
	    ivl_expr_t parm = ivl_expr_parm(expr, idx);
	    const char*parm_name = ivl_expr_type(parm) == IVL_EX_SFUNC
		  ? ivl_expr_name(parm) : 0;
	    if (parm_name
		&& (strncmp(parm_name, "$ivl_stream$with$", 17) == 0
		    || strncmp(parm_name, "$ivl_stream$withfixed$", 22) == 0)) {
		  unsigned range_parms = ivl_expr_parms(parm);
		  if (range_parms < 2 || range_parms > 3) {
			fprintf(stderr, "%s:%u: internal error: malformed "
				"streaming-with carrier.\n",
				ivl_expr_file(parm), ivl_expr_lineno(parm));
			return 1;
		  }
		  int fixed = strncmp(parm_name, "$ivl_stream$withfixed$", 22) == 0;
		  ivl_expr_t obj = ivl_expr_parm(parm, 0);
		  char kind[16] = "";
		  char elem_text[32] = "";
		  char state = 0;
		  long left = 0, right = 0, ewid = 0;
		  if (fixed) {
			int fields = sscanf(parm_name + 22,
			      "%15[^$]$%ld$%ld$%ld$%c",
			      kind, &left, &right, &ewid, &state);
			if (fields != 5 || ewid <= 0
			    || (state != 'b' && state != 'v')) {
			      fprintf(stderr, "%s:%u: internal error: malformed "
				      "fixed streaming-with carrier `%s'.\n",
				      ivl_expr_file(parm), ivl_expr_lineno(parm),
				      parm_name);
			      return 1;
			}
			/* Evaluate the array expression first.  The range follows
			   immediately before flattening it, so a side-effecting
			   receiver, first bound, and width each run once in source
			   order (IEEE 1800-2023 11.4.14.4). */
			draw_eval_vec4(obj);
		  } else {
			int fields = sscanf(parm_name + 17, "%15[^$]$%31s",
			                    kind, elem_text);
			const char*tp = elem_text;
			if (*tp == 's') tp += 1;
			if (fields != 2 || (*tp != 'b' && *tp != 'v')
			    || strtoul(tp + 1, 0, 10) == 0) {
			      fprintf(stderr, "%s:%u: internal error: malformed "
				      "dynamic streaming-with carrier `%s'.\n",
				      ivl_expr_file(parm), ivl_expr_lineno(parm),
				      parm_name);
			      return 1;
			}
			draw_eval_object(obj);
		  }

		  int first_reg = allocate_word();
		  int second_reg = allocate_word();
		  draw_eval_expr_into_integer(ivl_expr_parm(parm, 1), first_reg);
		  fprintf(vvp_out, "    %%stream/range/mark %d, 4;\n", first_reg);
		  if (range_parms == 3)
			draw_eval_expr_into_integer(ivl_expr_parm(parm, 2), second_reg);
		  else
			fprintf(vvp_out, "    %%ix/load %d, 0, 0;\n", second_reg);
		  if (range_parms == 3)
			fprintf(vvp_out, "    %%stream/range/mark %d, 4;\n",
				second_reg);

		  /* The range is now fully evaluated exactly once, immediately
		     before selecting and flattening the already-evaluated array. */
		  if (fixed) {
			fprintf(vvp_out,
			      "    %%stream/flatten/vec/with \"%s:%c%ld:%ld:%ld\", "
			      "%d, %d;\n", kind, state, ewid, left, right,
			      first_reg, second_reg);
		  } else {
			fprintf(vvp_out,
			      "    %%stream/flatten/obj/with \"%s:%s\", %d, %d;\n",
			      kind, elem_text, first_reg, second_reg);
		  }
		  clr_word(second_reg);
		  clr_word(first_reg);
	    } else {
	    switch (ivl_expr_value(parm)) {
		case IVL_VT_DARRAY:
		case IVL_VT_QUEUE:
		  draw_eval_object(parm);
		  fprintf(vvp_out, "    %%stream/flatten/obj;\n");
		  break;
		case IVL_VT_STRING:
		  draw_eval_string(parm);
		  fprintf(vvp_out, "    %%stream/flatten/str;\n");
		  break;
		default:
		  draw_eval_vec4(parm);
		  break;
	    }
	    }
	    if (idx > 0)
		  fprintf(vvp_out, "    %%concat/vec4;\n");
      }

      if (unpack) {
	    /* Unpack (11.4.14.3): consume tw bits from the left (error
	       when the source is narrower), then the /l form applies
	       the inverse block re-ordering. */
	    if (dir == 'l' || tw > 0)
		  fprintf(vvp_out, "    %%stream/unpack/%c %lu, %u;\n",
			  (dir == 'l') ? 'l' : 'r', slice, tw);
      } else {
	    if (dir == 'l' || tw > 0)
		  fprintf(vvp_out, "    %%stream/end/%c %lu, %u;\n",
			  (dir == 'l') ? 'l' : 'r', slice, tw);
      }

      return 0;
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

      if (init_expr && ivl_expr_type(init_expr) == IVL_EX_SFUNC
	  && ivl_expr_name(init_expr)
	  && strcmp(ivl_expr_name(init_expr),
		    "$ivl_darray_default_fill") == 0) {
	    if (ivl_expr_parms(init_expr) != 1) {
		  fprintf(stderr, "%s:%u: internal error: malformed dynamic-array "
			  "default-fill marker\n",
			  ivl_expr_file(init_expr), ivl_expr_lineno(init_expr));
		  return 1;
	    }

	    ivl_expr_t value = ivl_expr_parm(init_expr, 0);
	    switch (ivl_type_base(element_type)) {
		case IVL_VT_BOOL:
		case IVL_VT_LOGIC: {
		      unsigned wid = ivl_type_packed_width(element_type);
		      draw_eval_vec4(value);
		      resize_vec4_wid(value, wid);
		      if (ivl_type_base(element_type) == IVL_VT_BOOL
			  && ivl_expr_value(value) != IVL_VT_BOOL)
			    fprintf(vvp_out, "    %%cast2;\n");
		      fprintf(vvp_out, "    %%fill/dar/obj/vec4;\n");
		      fprintf(vvp_out, "    %%pop/vec4 1;\n");
		      break;
		}
		case IVL_VT_REAL:
		      draw_eval_real(value);
		      fprintf(vvp_out, "    %%fill/dar/obj/real;\n");
		      fprintf(vvp_out, "    %%pop/real 1;\n");
		      break;
		case IVL_VT_STRING:
		      draw_eval_string(value);
		      fprintf(vvp_out, "    %%fill/dar/obj/str;\n");
		      fprintf(vvp_out, "    %%pop/str 1;\n");
		      break;
		case IVL_VT_CLASS:
		case IVL_VT_DARRAY:
		case IVL_VT_QUEUE:
		case IVL_VT_NO_TYPE: {
		      int errors = draw_eval_object(value);
		      fprintf(vvp_out, "    %%fill/dar/obj/obj;\n");
		      return errors;
		}
		default:
		      fprintf(stderr, "%s:%u: internal error: unsupported "
			      "dynamic-array default-fill element type %d\n",
			      ivl_expr_file(init_expr),
			      ivl_expr_lineno(init_expr),
			      (int)ivl_type_base(element_type));
		      return 1;
	    }

      } else if (init_expr && ivl_expr_type(init_expr)==IVL_EX_ARRAY_PATTERN) {
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

void ensure_class_type_emitted(ivl_type_t class_type)
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

	/* A class-new initializer array is used by synthesized covergroup
	 * constructors. Its heterogeneous elements map positionally to the
	 * leading constructor-formal properties. The new object remains on
	 * the object stack while each typed property store consumes only its
	 * value stack. */
      ivl_expr_t init = ivl_expr_oper2(ex);
      if (init && ivl_expr_type(init) == IVL_EX_ARRAY_PATTERN) {
	    unsigned ninit = ivl_expr_parms(init);
	    unsigned nprops = (unsigned)ivl_type_properties(class_type);
	    if (ninit > nprops) ninit = nprops;
	    for (unsigned idx = 0; idx < ninit; idx += 1) {
		  ivl_expr_t value = ivl_expr_parm(init, idx);
		  ivl_type_t ptype = ivl_type_prop_type(class_type, idx);
		  switch (ivl_type_base(ptype)) {
		      case IVL_VT_BOOL:
		      case IVL_VT_LOGIC:
			draw_eval_vec4(value);
			fprintf(vvp_out, "    %%store/prop/v %u, %u; covergroup ctor\n",
				idx, ivl_expr_width(value));
			break;
		      case IVL_VT_REAL:
			draw_eval_real(value);
			fprintf(vvp_out, "    %%store/prop/r %u; covergroup ctor\n",
				idx);
			break;
		      case IVL_VT_STRING:
			draw_eval_string(value);
			fprintf(vvp_out, "    %%store/prop/str %u; covergroup ctor\n",
				idx);
			break;
		      default:
			fprintf(stderr, "Warning: unsupported covergroup constructor "
				"property type %d at index %u; leaving default value\n",
				(int)ivl_type_base(ptype), idx);
			break;
		  }
	    }
      }
	/* The object remains on the object stack after the constructor-formal
	 * stores. Initialize constant/default at_least and weight slots now; a
	 * constructor-dependent weight expression then sees the final formals. */
	if (ivl_type_covgrp_items(class_type) > 0)
	      fprintf(vvp_out, "    %%covgrp/options/init;\n");
      return 0;
}

/* Build the runtime type-encoding string for a queue/darray element
 * type, as consumed by %new/queue and %new/darray. */
static void container_element_enc_(ivl_type_t etype, char*enc, size_t enc_len)
{
      if (!etype) {
	    snprintf(enc, enc_len, "v32");
	    return;
      }
      switch (ivl_type_base(etype)) {
	  case IVL_VT_REAL:
	    snprintf(enc, enc_len, "r");
	    break;
	  case IVL_VT_STRING:
	    snprintf(enc, enc_len, "S");
	    break;
	  case IVL_VT_CLASS:
	  case IVL_VT_DARRAY:
	  case IVL_VT_QUEUE:
	    /* An unpacked STRUCT element (IVL_VT_NO_TYPE) is a cobject
	       at runtime. It used to fall into the packed-width default,
	       encoding a garbage width ("v4294967295") -- the container
	       was created with a mismatched element class and every
	       stored element was silently dropped. */
	  case IVL_VT_NO_TYPE:
	    snprintf(enc, enc_len, "o");
	    break;
	  default: {
	    unsigned w = ivl_type_packed_width(etype);
	    if (w == 0) w = 32;
	    snprintf(enc, enc_len, "%s%s%u",
		     ivl_type_signed(etype) ? "s" : "",
		     (ivl_type_base(etype) == IVL_VT_BOOL) ? "b" : "v",
		     w);
	    break;
	  }
      }
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

int vvp_expr_is_whole_fixed_array_property(ivl_expr_t expr)
{
      ivl_type_t type;
      if (!expr || ivl_expr_type(expr) != IVL_EX_PROPERTY
	  || ivl_expr_oper1(expr))
	    return 0;

      type = property_expr_type_(expr);
      if (!type)
	    type = ivl_expr_net_type(expr);
      return type_is_fixed_uarray_property_(type);
}

/* True when EXPR denotes a complete fixed unpacked-array value that is
 * materialized as passive dynamic-array storage in object context. A DPI
 * open-array formal must activate that value's declared ranges regardless of
 * whether the source spelling is a signal, a class property, or a function
 * call returning a fixed-array typedef. */
int vvp_expr_is_fixed_uarray_value(ivl_expr_t expr)
{
      ivl_scope_t def;
      ivl_signal_t result;

      if (!expr)
	    return 0;

      if (ivl_expr_type(expr) == IVL_EX_ARRAY)
	    return 1;

      if (ivl_expr_type(expr) == IVL_EX_ARRAY_SLICE)
	    return 1;

      if (vvp_expr_is_whole_fixed_array_property(expr))
	    return 1;

      if (ivl_expr_type(expr) != IVL_EX_UFUNC)
	    return 0;

      def = ivl_expr_def(expr);
      result = def && ivl_scope_ports(def) > 0
	    ? ivl_scope_port(def, 0) : 0;
      return result && ivl_signal_dimensions(result) > 0;
}

static uint64_t fixed_uarray_property_size_(ivl_type_t type)
{
      uint64_t size = 1;
      unsigned dim;

      if (!type_is_fixed_uarray_property_(type))
	    return 0;

      for (dim = 0; dim < ivl_type_packed_dimensions(type); dim += 1) {
	    int64_t msb = ivl_type_packed_msb(type, dim);
	    int64_t lsb = ivl_type_packed_lsb(type, dim);
	    uint64_t count = msb >= lsb
		  ? (uint64_t)(msb - lsb) + 1
		  : (uint64_t)(lsb - msb) + 1;

	    if (count == 0 || size > UINT64_MAX / count)
		  return 0;
	    size *= count;
      }

      return size;
}

static unsigned unsigned_width64_(uint64_t value)
{
      unsigned width = 1;

      while (value >>= 1)
	    width += 1;
      return width;
}

void draw_fixed_uarray_slot_index_(ivl_expr_t expr, ivl_type_t type,
                                    int word, int*x_flag,
                                    int*in_range_flag)
{
      uint64_t count = fixed_uarray_property_size_(type);
      unsigned wid = ivl_expr_width(expr);
      unsigned count_wid = unsigned_width64_(count);

      if (wid < count_wid)
            wid = count_wid;
      if (wid == 0)
            wid = 1;

      draw_eval_vec4(expr);
      resize_vec4_wid(expr, wid);
      fprintf(vvp_out, "    %%dup/vec4; fixed property slot index\n");
      fprintf(vvp_out, "    %%ix/vec4%s %d; fixed property slot word\n",
              ivl_expr_signed(expr) ? "/s" : "", word);
      *x_flag = allocate_flag();
      fprintf(vvp_out, "    %%flag_mov %d, 4; fixed property slot X/Z\n",
              *x_flag);
      fprintf(vvp_out,
              "    %%cmpi/u %u, %u, %u; fixed property slot in range\n",
              (unsigned)count, (unsigned)(count >> 32), wid);
      *in_range_flag = allocate_flag();
      fprintf(vvp_out, "    %%flag_mov %d, 5; fixed property slot in range\n",
              *in_range_flag);
}

static int fixed_uarray_has_container_leaf_(ivl_type_t type)
{
      ivl_type_t leaf = type_is_fixed_uarray_property_(type)
	    ? ivl_type_element(type) : 0;

      return leaf && (ivl_type_base(leaf) == IVL_VT_QUEUE
		      || ivl_type_base(leaf) == IVL_VT_DARRAY);
}

static int eval_object_property(ivl_expr_t expr)
{
      ivl_signal_t sig = ivl_expr_signal(expr);
      unsigned pidx = ivl_expr_property_idx(expr);
      ivl_expr_t base_expr = ivl_expr_oper2(expr);
      unsigned lab_null = local_count++;
      unsigned lab_out = local_count++;

      int idx = 0;
      int idx_x_flag = -1;
      int idx_in_range_flag = -1;
      ivl_expr_t idx_expr = 0;
	ivl_type_t declared_prop_type = property_expr_type_(expr);
	/* An index on a queue OR plain-darray property selects an
	 * element WITHIN the container value (the property itself is
	 * scalar), not a word of an arrayed property. %load/qo/obj
	 * accepts either container kind. */
      int queue_indexed = property_is_indexed_queue_expr_(expr)
	    || property_is_indexed_darray_expr_(expr);
      int assoc_indexed = property_is_assoc_indexed_expr_(expr);

	/* If there is an array index expression, then this is an
	   array'ed property, and we need to calculate the index for
	   the expression. */
      if ( (idx_expr = ivl_expr_oper1(expr)) ) {
	    if (!queue_indexed && !assoc_indexed) {
		  idx = allocate_word();
		  if (property_selects_fixed_uarray_slot_(expr)) {
			draw_fixed_uarray_slot_index_(idx_expr, declared_prop_type,
						     idx, &idx_x_flag,
						     &idx_in_range_flag);
		  } else {
			draw_eval_expr_into_integer(idx_expr, idx);
		  }
	    }
      }

      if (sig) {
	    fprintf(vvp_out, "    %%load/obj v%p_0;\n", sig);
      } else if (base_expr && ivl_expr_type(base_expr) == IVL_EX_NULL) {
	      /* Compile-progress fallback: null receiver property access
	         yields a null object directly. */
	    fprintf(vvp_out, "    %%null;\n");
	    if (idx != 0) clr_word(idx);
	    if (idx_x_flag >= 0) clr_flag(idx_x_flag);
	    if (idx_in_range_flag >= 0) clr_flag(idx_in_range_flag);
	    return 0;
      } else {
	    draw_eval_object(base_expr);
      }
      fprintf(vvp_out, "    %%test_nul/obj;\n");
      fprintf(vvp_out, "    %%jmp/1 T_%u.%u, 4;\n", thread_count, lab_null);
      if (idx_x_flag >= 0) {
	    fprintf(vvp_out, "    %%jmp/1xz T_%u.%u, %d; invalid fixed property slot\n",
		    thread_count, lab_null, idx_x_flag);
	    fprintf(vvp_out,
		    "    %%jmp/0xz T_%u.%u, %d; fixed property slot out of range\n",
		    thread_count, lab_null, idx_in_range_flag);
      }
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
	    if (vvp_expr_is_whole_fixed_array_property(expr)) {
		  if (fixed_uarray_has_container_leaf_(declared_prop_type)) {
			fprintf(stderr, "%s:%u: sorry: whole fixed unpacked array "
				"property %u with queue or dynamic-array elements "
				"cannot be read as one aggregate object.\n",
				ivl_expr_file(expr), ivl_expr_lineno(expr), pidx);
			vvp_errors += 1;
			fprintf(vvp_out,
				"    %%null; unsupported whole fixed array of containers\n");
		  } else {
			fprintf(vvp_out,
				"    %%prop/arr/dar %u; eval_fixed_property_array\n",
				pidx);
		  }
	    } else {
		  fprintf(vvp_out,
			  "    %%prop/obj %u, %d; eval_object_property\n",
			  pidx, idx);
	    }
	    fprintf(vvp_out, "    %%pop/obj 1, 1;\n");
      }
      fprintf(vvp_out, "    %%jmp T_%u.%u;\n", thread_count, lab_out);
      fprintf(vvp_out, "T_%u.%u;\n", thread_count, lab_null);
      fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
      fprintf(vvp_out, "    %%null;\n");
      fprintf(vvp_out, "T_%u.%u;\n", thread_count, lab_out);

      if (idx != 0) clr_word(idx);
      if (idx_x_flag >= 0) clr_flag(idx_x_flag);
      if (idx_in_range_flag >= 0) clr_flag(idx_in_range_flag);
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
      ivl_scope_t def = ivl_expr_def(ex);
      ivl_signal_t retval = def ? ivl_scope_port(def, 0) : 0;
      if (retval && ivl_signal_dimensions(retval) > 0) {
	    draw_ufunc_uarray_object(ex, 0, 0);
	    return 0;
      }
      draw_ufunc_object(ex);
      return 0;
}

/*
 * IVL_EX_ARRAY in an OBJECT context (draw_eval_object leaves exactly one
 * object on the stack) -- the whole unpacked array used as an object.
 *
 * Per the ivl_target API, IVL_EX_ARRAY is the whole array with NO index
 * expression. Indexed element reads are IVL_EX_SIGNAL and go through
 * eval_object_signal, which evaluates the word index properly; the
 * array-method paths that legitimately take a whole-array receiver
 * recognise IVL_EX_ARRAY themselves and never route it through here.
 *
 * What DOES arrive here is a whole fixed-size unpacked array standing in
 * for an object, which happens in three shapes:
 *
 *     int  a[3:10]; int d[];   d = a;      // 7.6, legal: fixed -> dynamic
 *     import "DPI-C" function void f(input int x[]);  f(a);   // 35.5.6.1
 *     C arr[4]; C h;           h = arr;    // NOT legal: type mismatch
 *
 * The legal forms are materialized element-wise into typed dynamic-array
 * storage below. The illegal single-handle forms are rejected during
 * elaboration, where both source and destination types are visible.
 */
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

	/* M10-1: marshal the whole fixed-size array into a dynamic array.
	   The element kind is a packed number rather than a string because
	   vvp_code_s keeps `array' and `text' in one union -- a string
	   operand would clobber the array pointer. See %load/arr/dar. */
      {
	    ivl_variable_type_t dt = ivl_signal_data_type(sig);
	    unsigned wid = ivl_signal_width(sig);
	    unsigned kind;

	    switch (dt) {
		case IVL_VT_REAL:
		  kind = 0;                     /* ARRDAR_REAL */
		  break;
		case IVL_VT_STRING:
		  kind = VVP_ARRDAR_STRING;
		  break;
		case IVL_VT_BOOL:
		case IVL_VT_LOGIC:
		  if (wid == 0) wid = 1;
		  if (wid > VVP_ARRDAR_WIDTH_MAX) {
			fprintf(stderr, "%s:%u: sorry: the whole unpacked "
				"array `%s' has %u-bit elements; the VVP array "
				"descriptor supports integral widths through %u "
				"bits.\n",
				ivl_expr_file(expr), ivl_expr_lineno(expr),
				ivl_signal_basename(sig), wid,
				VVP_ARRDAR_WIDTH_MAX);
			vvp_errors += 1;
			fprintf(vvp_out, "    %%null;\n");
			return 0;
		  }
		  kind = VVP_ARRDAR_WIDTH_KIND(wid)
		       | (ivl_signal_signed(sig) ? VVP_ARRDAR_SIGNED : 0u)
		       | ((dt == IVL_VT_LOGIC) ? VVP_ARRDAR_FOUR : 0u);
		  break;
		case IVL_VT_CLASS:
		    /* Handle elements: copied by reference, exactly as an
		       element-wise assignment would. `h = arr' -- the type
		       error that made this unsafe to marshal before -- is
		       now rejected at elaboration, where the target type is
		       visible (M10-1c), so only the legal `q = arr' shape
		       reaches here. */
		  kind = VVP_ARRDAR_OBJ;
		  break;
		default:
		  fprintf(stderr, "%s:%u: sorry: the whole unpacked array "
			  "`%s' cannot be used as an object: only arrays of "
			  "integral, real, string or class-handle elements can be "
			  "marshaled into dynamic-array storage.\n",
			  ivl_expr_file(expr), ivl_expr_lineno(expr),
			  ivl_signal_basename(sig));
		  vvp_errors += 1;
		  fprintf(vvp_out, "    %%null;\n");
		  return 0;
	    }

	      /* Carry the DECLARED range so the open-array accessors report
		 it rather than the 0..N-1 of the dynamic array this becomes
		 (H.10.2). array_base is the source address of the canonical
		 zero word; a swapped array descends from the high end. */
	    unsigned count = ivl_signal_array_count(sig);
	    int base = ivl_signal_array_base(sig);
	    int left;
	    if (ivl_signal_array_addr_swapped(sig)) {
		  left = base + (int)count - 1;
		  kind |= VVP_ARRDAR_DESC;
	    } else {
		  left = base;
	    }

	    note_array_signal_use(sig);

	      /* A MULTI-dimensional array is stored as one flat word
		 array just like a one-dimensional one, but the formal
		 built from it is nested -- one level per declared
		 dimension, each reporting its own bounds (H.10.2). The
		 shape is not recoverable from the flat storage, so hand
		 it over explicitly and use the nesting marshaler. */
	    if (ivl_signal_dimensions(sig) > 1) {
		  unsigned dim;
		  for (dim = 0 ; dim < ivl_signal_dimensions(sig) ; dim += 1)
			fprintf(vvp_out, "    %%dim/push %u, %u;\n",
				(unsigned)ivl_signal_array_dim_msb(sig, dim),
				(unsigned)ivl_signal_array_dim_lsb(sig, dim));
		  fprintf(vvp_out, "    %%load/arr/dar/md v%p, %u;\n",
			  sig, kind);
		  return 0;
	    }

	    fprintf(vvp_out, "    %%load/arr/dar v%p, %u, %u;\n",
		    sig, kind, (unsigned)left);
      }
      return 0;
}

/* Materialize a constant one-dimensional fixed-array slice in its selected
 * left-to-right order. The runtime object carries the slice's own declared
 * range as passive metadata; %store/obj/open activates it only for a DPI
 * open-array formal. */
static int eval_object_array_slice(ivl_expr_t expr)
{
      ivl_signal_t sig = ivl_expr_signal(expr);
      long base = ivl_expr_array_slice_base(expr);
      unsigned long count = ivl_expr_array_slice_count(expr);
      long left = ivl_expr_array_slice_left(expr);
      long right = ivl_expr_array_slice_right(expr);
      unsigned kind;

      if (!sig || base < 0 || count == 0
	  || (unsigned long)(unsigned)base != (unsigned long)base
	  || (unsigned long)(unsigned)count != count
	  || left < INT32_MIN || left > INT32_MAX
	  || right < INT32_MIN || right > INT32_MAX) {
	    fprintf(stderr, "%s:%u: internal error: fixed unpacked-array "
		    "slice metadata is not representable by the VVP runtime.\n",
		    ivl_expr_file(expr), ivl_expr_lineno(expr));
	    vvp_errors += 1;
	    fprintf(vvp_out, "    %%null; ; malformed fixed array slice\n");
	    return 1;
      }

      if (!uarray_container_kind_(sig, &kind, ivl_expr_file(expr),
				   ivl_expr_lineno(expr))) {
	    fprintf(vvp_out, "    %%null; ; unsupported fixed array slice\n");
	    return 1;
      }

      emit_load_arr_dar_slice_(sig, kind, (unsigned)base, (unsigned)count,
				left, right);
      return 0;
}

/* Handle IVL_EX_SELECT for object-valued container elements. Associative
 * receivers keep their native key stack; positional receivers use word 3. */
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

      if (ivl_expr_type(sube) != IVL_EX_SIGNAL
	  && ivl_expr_type(sube) != IVL_EX_ARRAY
	  && ivl_expr_type(sube) != IVL_EX_PROPERTY) {
	    ivl_type_t sube_type = receiver_container_type_(sube);

	    if (type_is_runtime_container_(sube_type)
		|| expr_is_dynarray_container_(sube)) {
		  draw_eval_object(sube);
		  if (sube_type
		      && ivl_type_base(sube_type) == IVL_VT_QUEUE
		      && ivl_type_queue_assoc_compat(sube_type)) {
			const char*key_kind;
			if (index)
			      key_kind = draw_eval_assoc_key_(index, 0);
			else {
			      fprintf(vvp_out, "    %%pushi/vec4 0, 0, 32;\n");
			      key_kind = "v";
			}
			fprintf(vvp_out, "    %%aa/load/obj/%s;\n", key_kind);
			fprintf(vvp_out, "    %%pop/obj 1, 1;\n");
		  } else {
			if (index)
			      draw_eval_expr_into_integer(index, 3);
			else
			      fprintf(vvp_out, "    %%ix/load 3, 0, 0;\n");
			fprintf(vvp_out, "    %%load/qo/obj;\n");
		  }
		  return 0;
	    }
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

	      /* The PROPERTY's own index is the fixed outer-array slot here;
	       * INDEX is the trailing associative key.  Loading the PROPERTY
	       * first cleanly consumes the class receiver and preserves the
	       * selected map as the receiver for the keyed lookup. */
	    if (property_selects_fixed_uarray_slot_(sube)
		&& expr_is_assoc_queue_container_(sube)) {
		  draw_eval_object(sube);
		  if (!index) {
			fprintf(vvp_out, "    %%pushi/vec4 0, 0, 32;\n");
			fprintf(vvp_out, "    %%aa/load/obj/v;\n");
		  } else {
			const char*key_kind = draw_eval_assoc_key_(index, 0);
			fprintf(vvp_out, "    %%aa/load/obj/%s;\n", key_kind);
		  }
		  fprintf(vvp_out, "    %%pop/obj 1, 1;\n");
		  return 0;
	    }

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

	      /* Queue OR plain darray property: load the container
	       * object and index within it. Without the darray arm this
	       * fell through to the arrayed-property path below, which
	       * consumed the element index as a property-ARRAY index
	       * (assertion idx < array_size_ at runtime). */
	    if (expr_is_dynarray_container_(sube)) {
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
	/* `maps[outer][key]' carries the fixed word selection on SUBE. Load
	 * that map object first; the scalar associative fast path below addresses
	 * vSIG_0 and is valid only when the signal itself has no fixed prefix. */
      if (net_type && ivl_type_base(net_type) == IVL_VT_QUEUE
	  && ivl_type_queue_assoc_compat(net_type)
	  && ivl_signal_dimensions(sig) > 0
	  && ivl_expr_type(sube) == IVL_EX_SIGNAL
	  && ivl_expr_oper1(sube)) {
	    const char*key_kind;
	    draw_eval_object(sube);
	    key_kind = draw_eval_assoc_key_(index, 0);
	    fprintf(vvp_out, "    %%aa/load/obj/%s;\n", key_kind);
	    fprintf(vvp_out, "    %%pop/obj 1, 1; fixed outer map receiver\n");
	    return 0;
      }
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
/* IEEE 1800-2017 7.12: the array method loops below run over queues
 * and dynamic arrays (both held in object variables) as well as
 * fixed-size unpacked arrays (vvp .array labels with a compile-time
 * word count).  These helpers hide the receiver difference: push the
 * element count as a 32-bit vec4, and load element [ix3] as a vec4. */
static int array_receiver_is_dynamic_(ivl_signal_t sig)
{
      ivl_variable_type_t dt = ivl_signal_data_type(sig);
      return dt == IVL_VT_DARRAY || dt == IVL_VT_QUEUE;
}

static void draw_array_size_push_(ivl_signal_t sig)
{
      if (array_receiver_is_dynamic_(sig))
	    fprintf(vvp_out, "    %%qsize v%p_0;\n", sig);
      else
	    fprintf(vvp_out, "    %%pushi/vec4 %u, 0, 32;\n",
		    ivl_signal_array_count(sig));
}

static void draw_array_elem_load_vec4_(ivl_signal_t sig)
{
	/* Index register 3 holds the canonical element address. */
      if (array_receiver_is_dynamic_(sig))
	    fprintf(vvp_out, "    %%load/dar/vec4 v%p_0;\n", sig);
      else
	    fprintf(vvp_out, "    %%load/vec4a v%p, 3;\n", sig);
}

/* Resolve the signal the array-method loop indexes through.  A plain
 * signal (or whole-array) receiver is used directly.  Any other
 * object-valued receiver (class property, nested property chain, call
 * result) is evaluated once onto the object stack and its handle
 * stored into the hidden net that elaboration passed as the sfunc's
 * trailing parameter (recv_parm).  Returns nil if the shapes are
 * unusable. */
static ivl_signal_t draw_array_method_recv_(ivl_expr_t a_arg,
					    ivl_expr_t recv_parm)
{
	    /* A supplied hidden receiver is an explicit request to evaluate and
	     * materialize the source once. Fixed arrays always use this path;
	     * consulting the IVL_EX_ARRAY fast path first would return the static
	     * signal and bypass fixed-to-darray marshaling. */
	  if (a_arg && recv_parm
	      && ivl_expr_type(recv_parm) == IVL_EX_SIGNAL
	      && ivl_expr_signal(recv_parm)) {
		ivl_signal_t recv_sig = ivl_expr_signal(recv_parm);
		draw_eval_object(a_arg);
		fprintf(vvp_out, "    %%store/obj v%p_0;\n", recv_sig);
		return recv_sig;
	  }

      if (a_arg && (ivl_expr_type(a_arg) == IVL_EX_SIGNAL
		    || ivl_expr_type(a_arg) == IVL_EX_ARRAY)
	  && ivl_expr_signal(a_arg))
	    return ivl_expr_signal(a_arg);

      if (!a_arg || !recv_parm
	  || ivl_expr_type(recv_parm) != IVL_EX_SIGNAL
	  || !ivl_expr_signal(recv_parm))
	    return 0;

	  return 0;
}

static int unique_runtime_type_supported_(ivl_type_t type)
{
      if (!type)
	    return 0;

      switch (ivl_type_base(type)) {
	  case IVL_VT_BOOL:
	  case IVL_VT_LOGIC:
	  case IVL_VT_REAL:
	  case IVL_VT_STRING:
	  case IVL_VT_CLASS:
	    return 1;
	  default:
	    return 0;
      }
}

/* Evaluate one unique() value and store it in a hidden iterator signal. */
static int draw_unique_store_signal_(ivl_expr_t value, ivl_signal_t sig,
				     ivl_type_t type)
{
      unsigned wid;

      switch (ivl_type_base(type)) {
	  case IVL_VT_BOOL:
	  case IVL_VT_LOGIC:
	    wid = ivl_type_packed_width(type);
	    if (wid == 0) wid = 1;
	    draw_eval_vec4(value);
	    fprintf(vvp_out, "    %%store/vec4 v%p_0, 0, %u;\n", sig, wid);
	    return 0;
	  case IVL_VT_REAL:
	    draw_eval_real(value);
	    fprintf(vvp_out, "    %%store/real v%p_0;\n", sig);
	    return 0;
	  case IVL_VT_STRING:
	    draw_eval_string(value);
	    fprintf(vvp_out, "    %%store/str v%p_0;\n", sig);
	    return 0;
	  case IVL_VT_CLASS: {
	    int errors = draw_eval_object(value);
	    fprintf(vvp_out, "    %%store/obj v%p_0;\n", sig);
	    return errors;
	  }
	  default:
	    return 1;
      }
}

/* Evaluate one unique() value and append it to a hidden unbounded queue. */
static int draw_unique_append_queue_(ivl_expr_t value, ivl_signal_t queue_sig,
				     ivl_type_t type)
{
      unsigned wid;

      switch (ivl_type_base(type)) {
	  case IVL_VT_BOOL:
	  case IVL_VT_LOGIC:
	    wid = ivl_type_packed_width(type);
	    if (wid == 0) wid = 1;
	    draw_eval_vec4(value);
	    fprintf(vvp_out, "    %%store/qb/v v%p_0, 5, %u;\n",
		    queue_sig, wid);
	    return 0;
	  case IVL_VT_REAL:
	    draw_eval_real(value);
	    fprintf(vvp_out, "    %%store/qb/r v%p_0, 5;\n", queue_sig);
	    return 0;
	  case IVL_VT_STRING:
	    draw_eval_string(value);
	    fprintf(vvp_out, "    %%store/qb/str v%p_0, 5;\n", queue_sig);
	    return 0;
	  case IVL_VT_CLASS: {
	    int errors = draw_eval_object(value);
	    fprintf(vvp_out, "    %%store/qb/obj v%p_0, 5;\n", queue_sig);
	    return errors;
	  }
	  default:
	    return 1;
      }
}

/* Lower the rich associative payload created by
 * make_assoc_array_unique_expr_. The receiver has already been materialized
 * into q_sig. Existing %aa/first/sig and %aa/next/sig operations write the
 * exact typed key signal; the passed element-select expression then reuses
 * the ordinary associative load lowering for every value/key combination. */
static int draw_assoc_unique_expr_(ivl_expr_t expr, ivl_signal_t q_sig,
				   int is_index)
{
      unsigned parm_count = ivl_expr_parms(expr);
      if (parm_count != 7 && parm_count != 8) {
	    fprintf(stderr, "%s:%u: internal error: malformed associative "
		    "unique payload\n",
		    ivl_expr_file(expr), ivl_expr_lineno(expr));
	    fprintf(vvp_out, "    %%null; ; assoc unique payload failure\n");
	    return 1;
      }

      ivl_expr_t iter_arg = ivl_expr_parm(expr, 1);
      ivl_expr_t result_arg = ivl_expr_parm(expr, 2);
      ivl_expr_t comparisons_arg = ivl_expr_parm(expr, 3);
      ivl_expr_t index_arg = ivl_expr_parm(expr, 4);
      ivl_expr_t comparison_expr = ivl_expr_parm(expr, 5);
      ivl_expr_t element_expr = ivl_expr_parm(expr, 6);
      if (!iter_arg || ivl_expr_type(iter_arg) != IVL_EX_SIGNAL
	  || !ivl_expr_signal(iter_arg)
	  || !result_arg || ivl_expr_type(result_arg) != IVL_EX_SIGNAL
	  || !ivl_expr_signal(result_arg)
	  || !comparisons_arg
	  || ivl_expr_type(comparisons_arg) != IVL_EX_SIGNAL
	  || !ivl_expr_signal(comparisons_arg)
	  || !index_arg || ivl_expr_type(index_arg) != IVL_EX_SIGNAL
	  || !ivl_expr_signal(index_arg)
	  || !comparison_expr || !element_expr) {
	    fprintf(stderr, "%s:%u: internal error: malformed associative "
		    "unique expression fields\n",
		    ivl_expr_file(expr), ivl_expr_lineno(expr));
	    fprintf(vvp_out, "    %%null; ; assoc unique field failure\n");
	    return 1;
      }

      ivl_signal_t iter_sig = ivl_expr_signal(iter_arg);
      ivl_signal_t result_sig = ivl_expr_signal(result_arg);
      ivl_signal_t comparisons_sig = ivl_expr_signal(comparisons_arg);
      ivl_signal_t index_sig = ivl_expr_signal(index_arg);
      ivl_type_t iter_type = ivl_signal_net_type(iter_sig);
      ivl_type_t result_queue_type = ivl_signal_net_type(result_sig);
      ivl_type_t comparisons_queue_type =
	    ivl_signal_net_type(comparisons_sig);
      ivl_type_t index_type = ivl_signal_net_type(index_sig);
      ivl_type_t result_type = result_queue_type
	    ? ivl_type_element(result_queue_type) : 0;
      ivl_type_t comparison_type = comparisons_queue_type
	    ? ivl_type_element(comparisons_queue_type) : 0;
      if (!unique_runtime_type_supported_(iter_type)
	  || !unique_runtime_type_supported_(index_type)
	  || !unique_runtime_type_supported_(result_type)
	  || !unique_runtime_type_supported_(comparison_type)) {
	    fprintf(stderr, "%s:%u: internal error: unsupported associative "
		    "unique runtime type\n",
		    ivl_expr_file(expr), ivl_expr_lineno(expr));
	    fprintf(vvp_out, "    %%null; ; assoc unique type failure\n");
	    return 1;
      }

      const char*key_kind;
      if (expr_is_string_assoc_key_(index_arg))
            key_kind = "str";
      else if (expr_is_object_assoc_key_(index_arg))
            key_kind = "obj";
      else
            key_kind = ivl_type_signed(index_type) ? "sv" : "v";

      char result_enc[64];
      char comparison_enc[64];
      container_element_enc_(result_type, result_enc, sizeof result_enc);
      container_element_enc_(comparison_type, comparison_enc,
			     sizeof comparison_enc);

      unsigned lab_top = local_count++;
      unsigned lab_end = local_count++;
      int traversal_flag = allocate_flag();
      int errors = 0;

	/* Each evaluation produces a distinct, correctly typed result, even
	 * when the associative receiver is empty. ix5=0 is the unbounded queue
	 * limit consumed by every %store/qb operation below. */
      fprintf(vvp_out, "    %%ix/load 5, 0, 0;\n");
      fprintf(vvp_out, "    %%new/queue \"%s\";\n", result_enc);
      fprintf(vvp_out, "    %%store/obj v%p_0;\n", result_sig);
      fprintf(vvp_out, "    %%new/queue \"%s\";\n", comparison_enc);
      fprintf(vvp_out, "    %%store/obj v%p_0;\n", comparisons_sig);

      fprintf(vvp_out, "    %%aa/first/sig/%s v%p_0, v%p_0;\n",
	      key_kind, q_sig, index_sig);
      fprintf(vvp_out, "    %%flag_set/vec4 %d;\n", traversal_flag);
      fprintf(vvp_out, "    %%jmp/0xz T_%u.%u, %d;\n",
	      thread_count, lab_end, traversal_flag);

      fprintf(vvp_out, "T_%u.%u ;\n", thread_count, lab_top);
      errors += draw_unique_store_signal_(element_expr, iter_sig, iter_type);
      errors += draw_unique_append_queue_(comparison_expr, comparisons_sig,
					  comparison_type);
      errors += draw_unique_append_queue_(is_index ? index_arg : iter_arg,
					  result_sig, result_type);

      fprintf(vvp_out, "    %%aa/next/sig/%s v%p_0, v%p_0;\n",
	      key_kind, q_sig, index_sig);
      fprintf(vvp_out, "    %%flag_set/vec4 %d;\n", traversal_flag);
      fprintf(vvp_out, "    %%jmp/1 T_%u.%u, %d;\n",
	      thread_count, lab_top, traversal_flag);

      fprintf(vvp_out, "T_%u.%u ;\n", thread_count, lab_end);
      fprintf(vvp_out, "    %%qunique/keys v%p_0, v%p_0;\n",
	      result_sig, comparisons_sig);
      fprintf(vvp_out, "    %%load/obj v%p_0;\n", result_sig);
      clr_flag(traversal_flag);
      return errors;
}

/* IEEE 1800-2017 7.12.3 array reduction methods:
 *   $ivl_darray_method$reduce|<kind>(array, iter, idx, acc, val)
 * kind is one of sum/product/and/or/xor.  Emit an inline loop that
 * walks the array, stores each element into the hidden iter signal,
 * evaluates the value expression (the with expression, or the iter
 * signal itself), and folds it into the hidden accumulator with the
 * corresponding operator.  The result is left on the vec4 stack.
 * Called from draw_sfunc_vec4 (the result is a vector, not an
 * object). */
int draw_array_reduce_vec4(ivl_expr_t expr)
{
      const char*name = ivl_expr_name(expr);
      const char*kind = name + 26;
      unsigned parm_count = ivl_expr_parms(expr);
      unsigned wid = ivl_expr_width(expr);
      static int warned_reduce_shape = 0;
	/* A fixed receiver adds a materialized dynamic-array signal plus the
	 * declared-index signal/expression used by iterator.index(). */
      int is_fixed = parm_count == 7 || parm_count == 8;
	/* The 8-parameter fixed shape materializes an arbitrary/property
	 * receiver; a direct fixed signal uses the 7-parameter shape. */
      int fixed_has_recv = parm_count == 8;

      ivl_expr_t a_arg = (parm_count > 4) ? ivl_expr_parm(expr, 0) : 0;
      ivl_expr_t iter_arg = (parm_count > 4) ? ivl_expr_parm(expr, 1) : 0;
      ivl_expr_t idx_arg = (parm_count > 4) ? ivl_expr_parm(expr, 2) : 0;
      ivl_expr_t acc_arg = (parm_count > 4) ? ivl_expr_parm(expr, 3) : 0;
      ivl_expr_t val = (parm_count > 4) ? ivl_expr_parm(expr, 4) : 0;
      ivl_expr_t recv_parm = fixed_has_recv
	    ? ivl_expr_parm(expr, 5)
	    : (!is_fixed && parm_count > 5) ? ivl_expr_parm(expr, 5) : 0;
      ivl_expr_t declared_idx_arg = is_fixed
	    ? ivl_expr_parm(expr, fixed_has_recv ? 6 : 5) : 0;
      ivl_expr_t declared_idx_expr = is_fixed
	    ? ivl_expr_parm(expr, fixed_has_recv ? 7 : 6) : 0;

	/* A whole-array receiver is IVL_EX_SIGNAL for queue/darray
	 * object variables, IVL_EX_ARRAY for fixed-size arrays; other
	 * object-valued receivers go through the hidden recv_parm
	 * net. */
      ivl_signal_t a_sig = draw_array_method_recv_(a_arg, recv_parm);
      if ((parm_count != 5 && parm_count != 6 && !is_fixed)
	  || !a_sig
	  || !iter_arg || ivl_expr_type(iter_arg) != IVL_EX_SIGNAL
	  || !ivl_expr_signal(iter_arg)
	  || !idx_arg || ivl_expr_type(idx_arg) != IVL_EX_SIGNAL
	  || !ivl_expr_signal(idx_arg)
	  || !acc_arg || ivl_expr_type(acc_arg) != IVL_EX_SIGNAL
	  || !ivl_expr_signal(acc_arg)
	  || !val
	  || (is_fixed
	      && (!declared_idx_arg
		  || ivl_expr_type(declared_idx_arg) != IVL_EX_SIGNAL
		  || !ivl_expr_signal(declared_idx_arg)
		  || !declared_idx_expr))) {
	    if (!warned_reduce_shape) {
		  fprintf(stderr, "Warning: %s requires a simple array"
			  " variable receiver; emitting 0 fallback"
			  " (further similar warnings suppressed)\n", name);
		  warned_reduce_shape = 1;
	    }
	    fprintf(vvp_out, "    %%pushi/vec4 0, 0, %u; ; reduce fallback\n",
			  wid);
	    return 0;
      }

      ivl_signal_t iter_sig = ivl_expr_signal(iter_arg);
      ivl_signal_t idx_sig = ivl_expr_signal(idx_arg);
      ivl_signal_t acc_sig = ivl_expr_signal(acc_arg);
      ivl_signal_t declared_idx_sig = is_fixed
	    ? ivl_expr_signal(declared_idx_arg) : 0;

      unsigned iter_wid = ivl_type_packed_width(ivl_signal_net_type(iter_sig));
      if (iter_wid == 0) iter_wid = 32;

      const char*op;
      int acc_ones = 0;
      if (strcmp(kind, "sum") == 0)          op = "%add";
      else if (strcmp(kind, "product") == 0) op = "%mul";
      else if (strcmp(kind, "and") == 0)     { op = "%and"; acc_ones = 1; }
      else if (strcmp(kind, "or") == 0)      op = "%or";
      else                                   op = "%xor";

      unsigned lab_top = local_count++;
      unsigned lab_end = local_count++;

	/* acc = identity element (0; 1 for product; ~0 for and) */
      fprintf(vvp_out, "    %%pushi/vec4 %d, 0, %u;\n",
	      (strcmp(kind, "product") == 0) ? 1 : 0, wid);
      if (acc_ones)
	    fprintf(vvp_out, "    %%inv;\n");
      fprintf(vvp_out, "    %%store/vec4 v%p_0, 0, %u;\n", acc_sig, wid);

	/* idx = 0 */
      fprintf(vvp_out, "    %%pushi/vec4 0, 0, 32;\n");
      fprintf(vvp_out, "    %%store/vec4 v%p_0, 0, 32;\n", idx_sig);

      fprintf(vvp_out, "T_%u.%u ;\n", thread_count, lab_top);
	/* if (!(idx < count)) goto end */
      fprintf(vvp_out, "    %%load/vec4 v%p_0;\n", idx_sig);
      draw_array_size_push_(a_sig);
      fprintf(vvp_out, "    %%cmp/s;\n");
      fprintf(vvp_out, "    %%jmp/0xz T_%u.%u, 5;\n", thread_count, lab_end);

	/* iter = a[idx] */
      fprintf(vvp_out, "    %%ix/getv/s 3, v%p_0;\n", idx_sig);
      draw_array_elem_load_vec4_(a_sig);
      fprintf(vvp_out, "    %%store/vec4 v%p_0, 0, %u;\n", iter_sig, iter_wid);

	/* The loop counter traverses the receiver's runtime storage order. The
	 * frontend supplies a matching declared-index expression: numeric-low for
	 * a direct fixed signal, left-to-right for a materialized fixed value. */
      if (is_fixed) {
	    draw_eval_vec4(declared_idx_expr);
	    fprintf(vvp_out, "    %%store/vec4 v%p_0, 0, 32;\n",
		    declared_idx_sig);
      }

	/* acc = acc OP value(iter) */
      draw_eval_vec4(val);
      if (ivl_expr_width(val) != wid)
	    fprintf(vvp_out, "    %%pad/%c %u;\n",
		    ivl_expr_signed(val) ? 's' : 'u', wid);
      fprintf(vvp_out, "    %%load/vec4 v%p_0;\n", acc_sig);
      fprintf(vvp_out, "    %s;\n", op);
      fprintf(vvp_out, "    %%store/vec4 v%p_0, 0, %u;\n", acc_sig, wid);

	/* idx += 1 */
      fprintf(vvp_out, "    %%load/vec4 v%p_0;\n", idx_sig);
      fprintf(vvp_out, "    %%pushi/vec4 1, 0, 32;\n");
      fprintf(vvp_out, "    %%add;\n");
      fprintf(vvp_out, "    %%store/vec4 v%p_0, 0, 32;\n", idx_sig);
      fprintf(vvp_out, "    %%jmp T_%u.%u;\n", thread_count, lab_top);

      fprintf(vvp_out, "T_%u.%u ;\n", thread_count, lab_end);
      fprintf(vvp_out, "    %%load/vec4 v%p_0;\n", acc_sig);
      return 0;
}

static int eval_object_sfunc(ivl_expr_t expr)
{
      const char*name = ivl_expr_name(expr);
      unsigned parm_count = ivl_expr_parms(expr);

      /* A keyed associative-array assignment pattern is carried through the
         netlist as a typed, source-ordered list of (kind,key,value) triplets.
         Materialize its fresh map in one place so declaration initializers,
         assignments, arguments, returns, casts and conditional arms all use
         identical construction and replacement semantics. */
      if (strcmp(name, "$ivl_assoc_pattern") == 0) {
	    ivl_type_t assoc_type = ivl_expr_net_type(expr);
	    ivl_type_t element_type = assoc_type
		  ? ivl_type_element(assoc_type) : 0;

	    if (!assoc_type || !element_type
		|| ivl_type_base(assoc_type) != IVL_VT_QUEUE
		|| !ivl_type_queue_assoc_compat(assoc_type)) {
		  fprintf(stderr, "%s:%u: internal error: malformed typed "
			  "associative-array pattern marker\n",
			  ivl_expr_file(expr), ivl_expr_lineno(expr));
		  fprintf(vvp_out,
			  "    %%null; ; malformed associative pattern marker\n");
		  return 1;
	    }

	    return draw_eval_assoc_pattern(expr, element_type);
      }

      /* A lone associative-array default pattern is a first-class value in
         assignment-like contexts, including function arguments, casts and
         conditional arms. Direct signal/property assignments consume this
         marker in stmt_assign.c; all nested and call-argument paths arrive
         through the generic object evaluator instead. Materialize the same
         fresh typed map here rather than allowing the internal sfunc name to
         fall through to the null-object recovery path. */
      if (strcmp(name, "$ivl_assoc_default") == 0) {
	    ivl_type_t assoc_type = ivl_expr_net_type(expr);
	    ivl_type_t element_type = assoc_type
		  ? ivl_type_element(assoc_type) : 0;

	    if (parm_count != 1 || !assoc_type || !element_type
		|| ivl_type_base(assoc_type) != IVL_VT_QUEUE
		|| !ivl_type_queue_assoc_compat(assoc_type)) {
		  fprintf(stderr, "%s:%u: internal error: malformed typed "
			  "associative-array default marker\n",
			  ivl_expr_file(expr), ivl_expr_lineno(expr));
		  fprintf(vvp_out,
			  "    %%null; ; malformed associative default marker\n");
		  return 1;
	    }

	    return draw_eval_assoc_default(expr, element_type);
      }

      /* IEEE 1800-2017/2023 6.24.1 defines a type cast as assignment to a
         temporary of the cast type. The frontend retains that target type on
         this internal marker so a queue/dynamic-array cast cannot inherit the
         source object's runtime kind or identity before an outer assignment,
         method call, or conditional context consumes it. */
      if (strcmp(name, "$ivl_container_cast") == 0)
	    return draw_eval_explicit_container_cast(expr);

      /* The frontend lowers a queue `$' object-element read to this
       * one-argument marker. Evaluate the receiver once, retain an alias for
       * the eventual element load while %qsize/o consumes its duplicate, then
       * load element size-1 through the ordinary object-container opcode. */
      if (strcmp(name, "$ivl_queue$last") == 0) {
	    assert(parm_count == 1);
	    draw_eval_object(ivl_expr_parm(expr, 0));
	    fprintf(vvp_out, "    %%dup/obj/ref; queue-last receiver alias\n");
	    fprintf(vvp_out, "    %%qsize/o;\n");
	    fprintf(vvp_out, "    %%pushi/vec4 1, 0, 32;\n");
	    fprintf(vvp_out, "    %%sub;\n");
	    fprintf(vvp_out, "    %%ix/vec4 3;\n");
	    fprintf(vvp_out, "    %%load/qo/obj;\n");
	    return 0;
      }

      /* Streaming concatenation materialized into a dynamic container
         (IEEE 1800-2017 11.4.14): build the stream, then convert it to
         a queue or dynamic array of the result's element type. */
      if (strncmp(name, "$ivl_stream$", 12) == 0) {
	    ivl_type_t net_type = ivl_expr_net_type(expr);
	    char elem_text[32];
	    int strict_cast = strncmp(name, "$ivl_stream$cast$", 17) == 0;
	    assert(net_type);
	    stream_elem_type_text(ivl_type_element(net_type),
				  elem_text, sizeof elem_text);
	    draw_stream_pack_pieces(expr, 0);
	    if (ivl_type_base(net_type) == IVL_VT_QUEUE) {
		  uint64_t max_size = ivl_type_queue_max_size(net_type);
		  fprintf(vvp_out, "    %%stream/to/queue \"%s%s:%" PRIu64
			  "\";\n", elem_text, strict_cast ? "!" : "",
			  max_size);
	    } else {
		  fprintf(vvp_out, "    %%stream/to/dar \"%s%s\";\n",
			  elem_text, strict_cast ? "!" : "");
	    }
	    return 0;
      }
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
      /* Phase 63b/Q-methods (gap close): expression-form q.unique()
       * and q.unique_index().  Emit runtime opcodes that read the
       * queue/darray and return a fresh result queue on the object stack.
       * %qunique_copy also carries the declared element category so a
       * never-allocated source still produces the correctly typed empty
       * queue. */
      if (strncmp(name, "$ivl_queue_method$unique_with|", 30) == 0) {
	    const char*kind = name + 30;
	    int is_index = (strstr(kind, "index") != NULL);
	    int is_plain = parm_count == 1 || parm_count == 2;
	    int is_fixed = parm_count == 9;

	    if (!is_plain && parm_count != 6 && parm_count != 7
		&& parm_count != 8 && !is_fixed) {
		  fprintf(stderr, "%s:%u: internal error: malformed unique "
			  "expression parameter count\n",
			  ivl_expr_file(expr), ivl_expr_lineno(expr));
		  fprintf(vvp_out, "    %%null; ; unique invariant failure\n");
		  return 1;
	    }
	    ivl_expr_t q_arg = ivl_expr_parm(expr, 0);
	    ivl_expr_t recv_parm = is_fixed
		  ? ivl_expr_parm(expr, 6)
		  : is_plain
		  ? ((parm_count == 2) ? ivl_expr_parm(expr, 1) : 0)
		  : ((parm_count == 8) ? ivl_expr_parm(expr, 7)
		     : ((parm_count == 7) ? ivl_expr_parm(expr, 6) : 0));
	    ivl_signal_t q_sig = draw_array_method_recv_(q_arg, recv_parm);
	    if (!q_sig) {
		  fprintf(stderr, "%s:%u: internal error: unique expression "
			  "receiver cannot be materialized\n",
			  ivl_expr_file(expr), ivl_expr_lineno(expr));
		  fprintf(vvp_out, "    %%null; ; unique receiver failure\n");
		  return 1;
	    }
	    ivl_type_t q_type = ivl_signal_net_type(q_sig);
	    if (q_type && ivl_type_queue_assoc_compat(q_type))
		  return draw_assoc_unique_expr_(expr, q_sig, is_index);

	      /* Plain unique/unique_index supports integral (2- or 4-state),
	       * real, string, and class-handle element containers. The result of
	       * unique_index is always an int queue; unique needs the element
	       * category in its opcode for a null/empty dynamic-array receiver. */
	    if (is_plain) {
		  ivl_type_t elem_type = q_type ? ivl_type_element(q_type) : 0;
		  unsigned elem_kind;
		  switch (elem_type ? ivl_type_base(elem_type) : IVL_VT_NO_TYPE) {
		      case IVL_VT_BOOL:
		      case IVL_VT_LOGIC:
			elem_kind = 0;
			break;
		      case IVL_VT_REAL:
			elem_kind = 1;
			break;
		      case IVL_VT_STRING:
			elem_kind = 2;
			break;
		      case IVL_VT_CLASS:
			elem_kind = 3;
			break;
		      default:
			fprintf(stderr, "%s:%u: internal error: unsupported plain "
				"unique element type %d\n",
				ivl_expr_file(expr), ivl_expr_lineno(expr),
				elem_type ? (int)ivl_type_base(elem_type) : -1);
			fprintf(vvp_out,
				"    %%null; ; unique element type failure\n");
			return 1;
		  }
		  if (is_index)
			fprintf(vvp_out, "    %%qunique_idx v%p_0;\n", q_sig);
		  else
			fprintf(vvp_out, "    %%qunique_copy v%p_0, %u;\n",
				q_sig, elem_kind);
		  return 0;
	    }

	      /* Keyed expression shape:
	       *   array.unique[(iter)] with (key)
	       *   array.unique_index[(iter)] with (key)
	       * parms are source, iterator, fresh result, key queue, index, key.
	       * Populate both fresh queues in one traversal, evaluating the key
	       * exactly once for every source element, then deduplicate the result
	       * against the parallel keys. Scalar element/key types retain their
	       * native vec4 width/X/Z, real, string, or class-handle
	       * representation. A fixed receiver adds a distinct declared-index
	       * signal/expression after the hidden materialized receiver. */
	    ivl_expr_t iter_arg = ivl_expr_parm(expr, 1);
	    ivl_expr_t result_arg = ivl_expr_parm(expr, 2);
	    ivl_expr_t keys_arg = ivl_expr_parm(expr, 3);
	    ivl_expr_t idx_arg = ivl_expr_parm(expr, 4);
	    ivl_expr_t key_expr = ivl_expr_parm(expr, 5);
	    ivl_expr_t declared_idx_arg = is_fixed
		  ? ivl_expr_parm(expr, 7) : 0;
	    ivl_expr_t declared_idx_expr = is_fixed
		  ? ivl_expr_parm(expr, 8) : 0;
	    if (!iter_arg || ivl_expr_type(iter_arg) != IVL_EX_SIGNAL
		|| !ivl_expr_signal(iter_arg)
		|| !result_arg || ivl_expr_type(result_arg) != IVL_EX_SIGNAL
		|| !ivl_expr_signal(result_arg)
		|| !keys_arg || ivl_expr_type(keys_arg) != IVL_EX_SIGNAL
		|| !ivl_expr_signal(keys_arg)
		|| !idx_arg || ivl_expr_type(idx_arg) != IVL_EX_SIGNAL
		|| !ivl_expr_signal(idx_arg)
		|| !key_expr
		|| (is_fixed
		    && (!declared_idx_arg
			|| ivl_expr_type(declared_idx_arg) != IVL_EX_SIGNAL
			|| !ivl_expr_signal(declared_idx_arg)
			|| !declared_idx_expr))) {
		  fprintf(stderr, "%s:%u: internal error: malformed keyed "
			  "unique payload\n",
			  ivl_expr_file(expr), ivl_expr_lineno(expr));
		  fprintf(vvp_out, "    %%null; ; keyed unique payload failure\n");
		  return 1;
	    }
	    ivl_signal_t iter_sig = ivl_expr_signal(iter_arg);
	    ivl_signal_t result_sig = ivl_expr_signal(result_arg);
	    ivl_signal_t keys_sig = ivl_expr_signal(keys_arg);
	    ivl_signal_t idx_sig = ivl_expr_signal(idx_arg);
	    ivl_signal_t declared_idx_sig = is_fixed
		  ? ivl_expr_signal(declared_idx_arg) : 0;
	    ivl_type_t iter_type = ivl_signal_net_type(iter_sig);
	    ivl_type_t elem_type = q_type ? ivl_type_element(q_type) : 0;
	    ivl_type_t keys_type = ivl_signal_net_type(keys_sig);
	    ivl_type_t key_type = keys_type ? ivl_type_element(keys_type) : 0;
	    ivl_variable_type_t elem_vt =
		  iter_type ? ivl_type_base(iter_type) : IVL_VT_NO_TYPE;
	    ivl_variable_type_t key_vt = ivl_expr_value(key_expr);
	    unsigned key_wid = ivl_expr_width(key_expr);
	    int scalar_element = elem_vt == IVL_VT_BOOL
		  || elem_vt == IVL_VT_LOGIC || elem_vt == IVL_VT_REAL
		  || elem_vt == IVL_VT_STRING || elem_vt == IVL_VT_CLASS;
	    int scalar_key = key_vt == IVL_VT_BOOL
		  || key_vt == IVL_VT_LOGIC || key_vt == IVL_VT_REAL
		  || key_vt == IVL_VT_STRING || key_vt == IVL_VT_CLASS;
	    if (!iter_type || !elem_type
		|| !scalar_element
		|| !scalar_key
		|| !key_type
		|| ((key_vt == IVL_VT_BOOL || key_vt == IVL_VT_LOGIC)
		    && key_wid == 0)) {
		  fprintf(stderr, "%s:%u: internal error: unsupported keyed "
			  "unique iterator/key shape\n",
			  ivl_expr_file(expr), ivl_expr_lineno(expr));
		  fprintf(vvp_out, "    %%null; ; keyed unique type failure\n");
		  return 1;
	    }

	    unsigned elem_wid = ivl_type_packed_width(iter_type);
	    if (elem_wid == 0) elem_wid = 32;
	    const char*load_elem = 0;
	    const char*store_iter = 0;
	    const char*load_result = 0;
	    const char*store_result = 0;
	    char store_iter_buf[64];
	    char load_result_buf[64];
	    char store_result_buf[64];
	    switch (elem_vt) {
		case IVL_VT_BOOL:
		case IVL_VT_LOGIC:
		  load_elem = "load/dar/vec4";
		  snprintf(store_iter_buf, sizeof store_iter_buf,
			   "store/vec4 v%p_0, 0, %u", iter_sig, elem_wid);
		  store_iter = store_iter_buf;
		  snprintf(load_result_buf, sizeof load_result_buf,
			   "load/vec4 v%p_0", iter_sig);
		  load_result = load_result_buf;
		  snprintf(store_result_buf, sizeof store_result_buf,
			   "store/qb/v v%p_0, 5, %u", result_sig, elem_wid);
		  store_result = store_result_buf;
		  break;
		case IVL_VT_REAL:
		  load_elem = "load/dar/r";
		  snprintf(store_iter_buf, sizeof store_iter_buf,
			   "store/real v%p_0", iter_sig);
		  store_iter = store_iter_buf;
		  snprintf(load_result_buf, sizeof load_result_buf,
			   "load/real v%p_0", iter_sig);
		  load_result = load_result_buf;
		  snprintf(store_result_buf, sizeof store_result_buf,
			   "store/qb/r v%p_0, 5", result_sig);
		  store_result = store_result_buf;
		  break;
		case IVL_VT_STRING:
		  load_elem = "load/dar/str";
		  snprintf(store_iter_buf, sizeof store_iter_buf,
			   "store/str v%p_0", iter_sig);
		  store_iter = store_iter_buf;
		  snprintf(load_result_buf, sizeof load_result_buf,
			   "load/str v%p_0", iter_sig);
		  load_result = load_result_buf;
		  snprintf(store_result_buf, sizeof store_result_buf,
			   "store/qb/str v%p_0, 5", result_sig);
		  store_result = store_result_buf;
		  break;
		case IVL_VT_CLASS:
		  load_elem = "load/dar/obj";
		  snprintf(store_iter_buf, sizeof store_iter_buf,
			   "store/obj v%p_0", iter_sig);
		  store_iter = store_iter_buf;
		  snprintf(load_result_buf, sizeof load_result_buf,
			   "load/obj v%p_0", iter_sig);
		  load_result = load_result_buf;
		  snprintf(store_result_buf, sizeof store_result_buf,
			   "store/qb/obj v%p_0, 5", result_sig);
		  store_result = store_result_buf;
		  break;
		default:
		  break;
	    }
	    if (!load_elem || !store_iter || !load_result || !store_result) {
		  fprintf(stderr, "%s:%u: internal error: keyed unique element "
			  "lowering is unavailable\n",
			  ivl_expr_file(expr), ivl_expr_lineno(expr));
		  fprintf(vvp_out, "    %%null; ; keyed unique lowering failure\n");
		  return 1;
	    }

	    char result_enc[64];
	    char key_enc[64];
	    if (is_index)
		  snprintf(result_enc, sizeof result_enc, "sb32");
	    else
		  container_element_enc_(elem_type, result_enc,
					 sizeof result_enc);
	    container_element_enc_(key_type, key_enc, sizeof key_enc);

	    unsigned lab_top = local_count++;
	    unsigned lab_end = local_count++;

	      /* Every evaluation creates new result/key containers. This keeps
	       * separate calls independent and makes an empty result non-null. */
	    fprintf(vvp_out, "    %%ix/load 5, 0, 0;\n");
	    fprintf(vvp_out, "    %%new/queue \"%s\";\n", result_enc);
	    fprintf(vvp_out, "    %%store/obj v%p_0;\n", result_sig);
	    fprintf(vvp_out, "    %%new/queue \"%s\";\n", key_enc);
	    fprintf(vvp_out, "    %%store/obj v%p_0;\n", keys_sig);

	    fprintf(vvp_out, "    %%pushi/vec4 0, 0, 32;\n");
	    fprintf(vvp_out, "    %%store/vec4 v%p_0, 0, 32;\n", idx_sig);

	    fprintf(vvp_out, "T_%u.%u ;\n", thread_count, lab_top);
	    fprintf(vvp_out, "    %%load/vec4 v%p_0;\n", idx_sig);
	    draw_array_size_push_(q_sig);
	    fprintf(vvp_out, "    %%cmp/s;\n");
	    fprintf(vvp_out, "    %%jmp/0xz T_%u.%u, 5;\n",
		    thread_count, lab_end);

	      /* iter = source[idx], preserving its native scalar representation
	       * (or the original class handle for the UVM subset). */
	    fprintf(vvp_out, "    %%ix/getv/s 3, v%p_0;\n", idx_sig);
	    fprintf(vvp_out, "    %%%s v%p_0;\n", load_elem, q_sig);
	    fprintf(vvp_out, "    %%%s;\n", store_iter);

	      /* A fixed receiver is materialized in declared left-to-right order.
	       * Evaluate the frontend's explicit declared-index expression before
	       * the user's key expression. */
	    if (is_fixed) {
		  draw_eval_vec4(declared_idx_expr);
		  fprintf(vvp_out, "    %%store/vec4 v%p_0, 0, 32;\n",
			  declared_idx_sig);
	    }

	      /* Evaluate and append the key exactly once per source element. */
	    if (key_vt == IVL_VT_STRING) {
		  draw_eval_string(key_expr);
		  fprintf(vvp_out, "    %%store/qb/str v%p_0, 5;\n", keys_sig);
	    } else if (key_vt == IVL_VT_REAL) {
		  draw_eval_real(key_expr);
		  fprintf(vvp_out, "    %%store/qb/r v%p_0, 5;\n", keys_sig);
	    } else if (key_vt == IVL_VT_CLASS) {
		  draw_eval_object(key_expr);
		  fprintf(vvp_out, "    %%store/qb/obj v%p_0, 5;\n", keys_sig);
	    } else {
		  draw_eval_vec4(key_expr);
		  fprintf(vvp_out, "    %%store/qb/v v%p_0, 5, %u;\n",
			  keys_sig, key_wid);
	    }

	      /* unique returns original element values; unique_index returns the
	       * corresponding source index (the declared index for a fixed
	       * receiver). Representative choice and result order are not
	       * externally promised properties. */
	    if (is_index) {
		  fprintf(vvp_out, "    %%load/vec4 v%p_0;\n",
			  is_fixed ? declared_idx_sig : idx_sig);
		  fprintf(vvp_out, "    %%store/qb/v v%p_0, 5, 32;\n", result_sig);
	    } else {
		  fprintf(vvp_out, "    %%%s;\n", load_result);
		  fprintf(vvp_out, "    %%%s;\n", store_result);
	    }

	    fprintf(vvp_out, "    %%load/vec4 v%p_0;\n", idx_sig);
	    fprintf(vvp_out, "    %%pushi/vec4 1, 0, 32;\n");
	    fprintf(vvp_out, "    %%add;\n");
	    fprintf(vvp_out, "    %%store/vec4 v%p_0, 0, 32;\n", idx_sig);
	    fprintf(vvp_out, "    %%jmp T_%u.%u;\n", thread_count, lab_top);

	    fprintf(vvp_out, "T_%u.%u ;\n", thread_count, lab_end);
	    fprintf(vvp_out, "    %%qunique/keys v%p_0, v%p_0;\n",
		    result_sig, keys_sig);
	    fprintf(vvp_out, "    %%load/obj v%p_0;\n", result_sig);
	    return 0;
      }

      /* Queue slice q[a:b] (7.10.1): push the source container, the
       * two bounds, and let %qslice build the element-range copy. */
      if (strcmp(name, "$ivl_queue$slice") == 0) {
	    if (parm_count != 3) {
		  fprintf(vvp_out, "    %%null; ; qslice: bad parm count\n");
		  return 0;
	    }
	    int errors = draw_eval_object(ivl_expr_parm(expr, 0));
	    draw_eval_vec4(ivl_expr_parm(expr, 1));
	    draw_eval_vec4(ivl_expr_parm(expr, 2));
	    fprintf(vvp_out, "    %%qslice/f %u, %u;\n",
		    ivl_expr_signed(ivl_expr_parm(expr, 1)) ? 1U : 0U,
		    ivl_expr_signed(ivl_expr_parm(expr, 2)) ? 1U : 0U);
	    return errors;
      }

      /* q[a:$] and q[a:$-offset] evaluate the source container exactly
       * once. The runtime derives the upper bound from that same object;
       * synthesizing source.size() in the expression tree would duplicate
       * side effects in an indexed or function-call receiver. */
      if (strcmp(name, "$ivl_queue$slice_last") == 0) {
	    if (parm_count != 2) {
		  fprintf(vvp_out, "    %%null; ; qslice/last: bad parm count\n");
		  return 0;
	    }
	    int errors = draw_eval_object(ivl_expr_parm(expr, 0));
	    draw_eval_vec4(ivl_expr_parm(expr, 1));
	    fprintf(vvp_out, "    %%qslice/last/f %u;\n",
		    ivl_expr_signed(ivl_expr_parm(expr, 1)) ? 1U : 0U);
	    return errors;
      }

      if (strcmp(name, "$ivl_queue$slice_offset") == 0) {
	    if (parm_count != 3) {
		  fprintf(vvp_out, "    %%null; ; qslice/off: bad parm count\n");
		  return 0;
	    }
	    int errors = draw_eval_object(ivl_expr_parm(expr, 0));
	    draw_eval_vec4(ivl_expr_parm(expr, 1));
	    draw_eval_vec4(ivl_expr_parm(expr, 2));
	    fprintf(vvp_out, "    %%qslice/off/f %u, %u;\n",
		    ivl_expr_signed(ivl_expr_parm(expr, 1)) ? 1U : 0U,
		    ivl_expr_signed(ivl_expr_parm(expr, 2)) ? 1U : 0U);
	    return errors;
      }

      /* q[$:hi] derives its lower bound from the same already-evaluated
       * source object. This preserves one evaluation for side-effecting
       * class, virtual-interface, method, and indexed receivers. */
      if (strcmp(name, "$ivl_queue$slice_left_last") == 0) {
	    if (parm_count != 2) {
		  fprintf(vvp_out, "    %%null; ; qslice/left: bad parm count\n");
		  return 0;
	    }
	    int errors = draw_eval_object(ivl_expr_parm(expr, 0));
	    draw_eval_vec4(ivl_expr_parm(expr, 1));
	    fprintf(vvp_out, "    %%qslice/left/f %u;\n",
		    ivl_expr_signed(ivl_expr_parm(expr, 1)) ? 1U : 0U);
	    return errors;
      }

      /* Indexed queue slice Q[base +: width] / Q[base -: width]. Keep width
       * as a vec4 operand instead of truncating it to a C integer here: the
       * runtime can reject or clamp an arbitrary-width value without
       * accidentally allocating a wrapped result. Receiver, base, and width
       * are evaluated once, in that order. Dynamic-array slices have fixed-
       * size unpacked-array result types (7.4.5) and are rejected in
       * elaboration until that non-object result IR exists. */
      if (strcmp(name, "$ivl_array$slice_indexed_up") == 0
	  || strcmp(name, "$ivl_array$slice_indexed_down") == 0) {
	    if (parm_count != 3) {
		  fprintf(vvp_out,
			  "    %%null; ; indexed array slice: bad parm count\n");
		  return 0;
	    }

	    ivl_type_t container_type = ivl_expr_net_type(expr);
	    if (!container_type
		|| ivl_type_base(container_type) != IVL_VT_QUEUE) {
		  fprintf(stderr, "%s:%u: internal error: indexed slice object "
			  "code generation requires a queue result.\n",
			  ivl_expr_file(expr), ivl_expr_lineno(expr));
		  fprintf(vvp_out,
			  "    %%null; ; indexed slice non-queue result\n");
		  return 1;
	    }
	    ivl_type_t elem_type = ivl_type_element(container_type);
	    char enc[32];
	    container_element_enc_(elem_type, enc, sizeof enc);
	    const char*direction =
		  strcmp(name, "$ivl_array$slice_indexed_up") == 0
		  ? "up" : "down";

	    int errors = draw_eval_object(ivl_expr_parm(expr, 0));
	    draw_eval_vec4(ivl_expr_parm(expr, 1));
	    draw_eval_vec4(ivl_expr_parm(expr, 2));
	    fprintf(vvp_out, "    %%qslice/idx/q/%s \"%s\", %u, %u;\n",
		    direction, enc,
		    ivl_expr_signed(ivl_expr_parm(expr, 1)) ? 1U : 0U,
		    ivl_expr_signed(ivl_expr_parm(expr, 2)) ? 1U : 0U);
	    return errors;
      }

      /* The empty queue literal `{}` (IEEE 1800-2017 7.10.4): push a
       * fresh EMPTY container of the context type. A null handle here
       * made q_of_q.push_back({}) store nil (G73). */
      if (strcmp(name, "$ivl_queue$new_empty") == 0) {
	    ivl_type_t qtype = ivl_expr_net_type(expr);
	    ivl_type_t etype = qtype ? ivl_type_element(qtype) : 0;
	    char enc[32];
	    container_element_enc_(etype, enc, sizeof enc);
	    if (qtype && ivl_type_base(qtype) == IVL_VT_DARRAY) {
		  fprintf(vvp_out, "    %%ix/load 3, 0, 0;\n");
		  fprintf(vvp_out, "    %%new/darray 3, \"%s\";\n", enc);
	    } else {
		  fprintf(vvp_out, "    %%new/queue \"%s\";\n", enc);
	    }
	    return 0;
      }

      /* Legacy fixed-array locator lowering. Current elaboration
       * materializes fixed receivers and uses the generic keyed path above;
       * keep this decoder for already-produced IVL without promising a
       * representative choice or result order. */
      if (strncmp(name, "$ivl_uarray_method$unique|", 26) == 0) {
	    const char*kind = name + 26;
	    int is_index = (strstr(kind, "index") != NULL);
	    ivl_expr_t a_arg = (parm_count > 0) ? ivl_expr_parm(expr, 0) : 0;
	    ivl_signal_t a_sig = 0;
	    if (a_arg && (ivl_expr_type(a_arg) == IVL_EX_SIGNAL
			  || ivl_expr_type(a_arg) == IVL_EX_ARRAY))
		  a_sig = ivl_expr_signal(a_arg);
	    if (!a_sig) {
		  fprintf(vvp_out, "    %%null; ; uarr unique: bad arg shape\n");
		  return 0;
	    }
	    note_array_signal_use(a_sig);
	    fprintf(vvp_out, "    %%uarr/unique v%p, %d;\n",
		    a_sig, is_index ? 1 : 0);
	    return 0;
      }

      /* IEEE 1800-2017 7.12.1 min()/max():
       *   $ivl_darray_method$minmax|<kind>(array, iter, result, idx,
       *                                    best, bestitem, val)
       * Walk the array tracking the best per-element value (the with
       * expression, or the element itself) and return a queue holding
       * the single best element — or an empty queue for an empty
       * array.  Ties keep the earliest element.  Comparisons whose
       * flags evaluate to x (x/z bits in the values) keep the current
       * best. */
      if (strncmp(name, "$ivl_darray_method$minmax|", 26) == 0) {
	    const char*kind = name + 26;
	    int is_min = (strcmp(kind, "min") == 0);

	    if (parm_count < 7) {
		  fprintf(vvp_out, "    %%null; ; minmax: bad parm count\n");
		  return 0;
	    }
	    ivl_expr_t a_arg = ivl_expr_parm(expr, 0);
	    ivl_expr_t iter_arg = ivl_expr_parm(expr, 1);
	    ivl_expr_t result_arg = ivl_expr_parm(expr, 2);
	    ivl_expr_t idx_arg = ivl_expr_parm(expr, 3);
	    ivl_expr_t best_arg = ivl_expr_parm(expr, 4);
	    ivl_expr_t bitem_arg = ivl_expr_parm(expr, 5);
	    ivl_expr_t val = ivl_expr_parm(expr, 6);
	    ivl_expr_t recv_parm = (parm_count > 7)
		  ? ivl_expr_parm(expr, 7) : 0;

	    ivl_signal_t a_sig = draw_array_method_recv_(a_arg, recv_parm);
	    if (!a_sig
		|| !iter_arg || ivl_expr_type(iter_arg) != IVL_EX_SIGNAL
		|| !ivl_expr_signal(iter_arg)
		|| !result_arg || ivl_expr_type(result_arg) != IVL_EX_SIGNAL
		|| !ivl_expr_signal(result_arg)
		|| !idx_arg || ivl_expr_type(idx_arg) != IVL_EX_SIGNAL
		|| !ivl_expr_signal(idx_arg)
		|| !best_arg || ivl_expr_type(best_arg) != IVL_EX_SIGNAL
		|| !ivl_expr_signal(best_arg)
		|| !bitem_arg || ivl_expr_type(bitem_arg) != IVL_EX_SIGNAL
		|| !ivl_expr_signal(bitem_arg)
		|| !val) {
		  fprintf(vvp_out, "    %%null; ; minmax: bad arg shape\n");
		  return 0;
	    }
	    ivl_signal_t iter_sig = ivl_expr_signal(iter_arg);
	    ivl_signal_t result_sig = ivl_expr_signal(result_arg);
	    ivl_signal_t idx_sig = ivl_expr_signal(idx_arg);
	    ivl_signal_t best_sig = ivl_expr_signal(best_arg);
	    ivl_signal_t bitem_sig = ivl_expr_signal(bitem_arg);

	    ivl_type_t iter_type = ivl_signal_net_type(iter_sig);
	    unsigned iter_wid = ivl_type_packed_width(iter_type);
	    if (iter_wid == 0) iter_wid = 32;
	    unsigned val_wid = ivl_expr_width(val);
	    if (val_wid == 0) val_wid = 32;
	    const char*cmp_op = ivl_expr_signed(val) ? "%cmp/s" : "%cmp/u";

	    char elem_enc[32];
	    snprintf(elem_enc, sizeof elem_enc, "%s%s%u",
		     ivl_type_signed(iter_type) ? "s" : "",
		     (ivl_type_base(iter_type) == IVL_VT_BOOL) ? "b" : "v",
		     iter_wid);

	    unsigned lab_top = local_count++;
	    unsigned lab_end = local_count++;
	    unsigned lab_take = local_count++;
	    unsigned lab_skip = local_count++;
	    unsigned lab_next = local_count++;
	    unsigned lab_done = local_count++;

	      /* result = empty queue of the element type; ix5 = 0 is
	       * the (unbounded) max-size operand for %store/qb/v. */
	    fprintf(vvp_out, "    %%ix/load 5, 0, 0;\n");
	    fprintf(vvp_out, "    %%new/queue \"%s\";\n", elem_enc);
	    fprintf(vvp_out, "    %%store/obj v%p_0;\n", result_sig);

	      /* idx = 0 */
	    fprintf(vvp_out, "    %%pushi/vec4 0, 0, 32;\n");
	    fprintf(vvp_out, "    %%store/vec4 v%p_0, 0, 32;\n", idx_sig);

	    fprintf(vvp_out, "T_%u.%u ;\n", thread_count, lab_top);
	      /* if (!(idx < count)) goto end */
	    fprintf(vvp_out, "    %%load/vec4 v%p_0;\n", idx_sig);
	    draw_array_size_push_(a_sig);
	    fprintf(vvp_out, "    %%cmp/s;\n");
	    fprintf(vvp_out, "    %%jmp/0xz T_%u.%u, 5;\n",
		    thread_count, lab_end);

	      /* iter = a[idx] */
	    fprintf(vvp_out, "    %%ix/getv/s 3, v%p_0;\n", idx_sig);
	    draw_array_elem_load_vec4_(a_sig);
	    fprintf(vvp_out, "    %%store/vec4 v%p_0, 0, %u;\n",
		    iter_sig, iter_wid);

	      /* value on the stack; the first element is always taken */
	    draw_eval_vec4(val);
	    fprintf(vvp_out, "    %%load/vec4 v%p_0;\n", idx_sig);
	    fprintf(vvp_out, "    %%pushi/vec4 0, 0, 32;\n");
	    fprintf(vvp_out, "    %%cmp/u;\n");
	    fprintf(vvp_out, "    %%jmp/1 T_%u.%u, 4;\n",
		    thread_count, lab_take);

	      /* compare val (deeper) vs best: flag5 = val < best */
	    fprintf(vvp_out, "    %%dup/vec4;\n");
	    fprintf(vvp_out, "    %%load/vec4 v%p_0;\n", best_sig);
	    fprintf(vvp_out, "    %s;\n", cmp_op);
	    if (is_min) {
		    /* take if val < best */
		  fprintf(vvp_out, "    %%jmp/1 T_%u.%u, 5;\n",
			  thread_count, lab_take);
		  fprintf(vvp_out, "    %%jmp T_%u.%u;\n",
			  thread_count, lab_skip);
	    } else {
		    /* take if best < val, i.e. !(val < best) && !(val == best) */
		  fprintf(vvp_out, "    %%jmp/1 T_%u.%u, 5;\n",
			  thread_count, lab_skip);
		  fprintf(vvp_out, "    %%jmp/1 T_%u.%u, 4;\n",
			  thread_count, lab_skip);
		  fprintf(vvp_out, "    %%jmp/0 T_%u.%u, 5;\n",
			  thread_count, lab_take);
		  fprintf(vvp_out, "    %%jmp T_%u.%u;\n",
			  thread_count, lab_skip);
	    }

	    fprintf(vvp_out, "T_%u.%u ;\n", thread_count, lab_take);
	      /* stack: val — becomes the new best; remember the element */
	    fprintf(vvp_out, "    %%store/vec4 v%p_0, 0, %u;\n",
		    best_sig, val_wid);
	    fprintf(vvp_out, "    %%load/vec4 v%p_0;\n", iter_sig);
	    fprintf(vvp_out, "    %%store/vec4 v%p_0, 0, %u;\n",
		    bitem_sig, iter_wid);
	    fprintf(vvp_out, "    %%jmp T_%u.%u;\n", thread_count, lab_next);

	    fprintf(vvp_out, "T_%u.%u ;\n", thread_count, lab_skip);
	      /* stack: val — discard */
	    fprintf(vvp_out, "    %%pop/vec4 1;\n");

	    fprintf(vvp_out, "T_%u.%u ;\n", thread_count, lab_next);
	      /* idx += 1 */
	    fprintf(vvp_out, "    %%load/vec4 v%p_0;\n", idx_sig);
	    fprintf(vvp_out, "    %%pushi/vec4 1, 0, 32;\n");
	    fprintf(vvp_out, "    %%add;\n");
	    fprintf(vvp_out, "    %%store/vec4 v%p_0, 0, 32;\n", idx_sig);
	    fprintf(vvp_out, "    %%jmp T_%u.%u;\n", thread_count, lab_top);

	    fprintf(vvp_out, "T_%u.%u ;\n", thread_count, lab_end);
	      /* if (0 < count) result.push_back(bestitem) */
	    fprintf(vvp_out, "    %%pushi/vec4 0, 0, 32;\n");
	    draw_array_size_push_(a_sig);
	    fprintf(vvp_out, "    %%cmp/u;\n");
	    fprintf(vvp_out, "    %%jmp/0xz T_%u.%u, 5;\n",
		    thread_count, lab_done);
	    fprintf(vvp_out, "    %%load/vec4 v%p_0;\n", bitem_sig);
	    fprintf(vvp_out, "    %%store/qb/v v%p_0, 5, %u;\n",
		    result_sig, iter_wid);

	    fprintf(vvp_out, "T_%u.%u ;\n", thread_count, lab_done);
	    fprintf(vvp_out, "    %%load/obj v%p_0;\n", result_sig);
	    return 0;
      }

      if (strncmp(name, "$ivl_queue_method$find_with|", 28) == 0) {
	    const char*kind = name + 28;
	    int is_fixed_property = parm_count == 9;
	    int is_index = (strstr(kind, "index") != NULL);
	    int is_first = (strcmp(kind, "find_first") == 0
			    || strcmp(kind, "find_first_index") == 0);
	    int is_last = (strcmp(kind, "find_last") == 0
			   || strcmp(kind, "find_last_index") == 0);

	    if (parm_count != 5 && parm_count != 6 && !is_fixed_property) {
		  fprintf(vvp_out, "    %%null; ; find_with: bad parm count\n");
		  return 0;
	    }
	    ivl_expr_t q_arg = ivl_expr_parm(expr, 0);
	    ivl_expr_t iter_arg = ivl_expr_parm(expr, 1);
	    ivl_expr_t result_arg = ivl_expr_parm(expr, 2);
	    ivl_expr_t idx_arg = ivl_expr_parm(expr, 3);
	    ivl_expr_t pred = ivl_expr_parm(expr, 4);
	    ivl_expr_t recv_parm = (parm_count > 5)
		  ? ivl_expr_parm(expr, 5) : 0;
	    ivl_expr_t declared_idx_arg = is_fixed_property
		  ? ivl_expr_parm(expr, 6) : 0;
	    ivl_expr_t declared_idx_expr = is_fixed_property
		  ? ivl_expr_parm(expr, 7) : 0;
	    ivl_expr_t fixed_desc_expr = is_fixed_property
		  ? ivl_expr_parm(expr, 8) : 0;

	    ivl_signal_t q_sig = draw_array_method_recv_(q_arg, recv_parm);
	    if (!q_sig
		|| !iter_arg || ivl_expr_type(iter_arg) != IVL_EX_SIGNAL
		|| !ivl_expr_signal(iter_arg)
		|| !result_arg || ivl_expr_type(result_arg) != IVL_EX_SIGNAL
		|| !ivl_expr_signal(result_arg)
		|| !idx_arg || ivl_expr_type(idx_arg) != IVL_EX_SIGNAL
		|| !ivl_expr_signal(idx_arg)
		|| !pred
		|| (is_fixed_property
		    && (!declared_idx_arg
			|| ivl_expr_type(declared_idx_arg) != IVL_EX_SIGNAL
			|| !ivl_expr_signal(declared_idx_arg)
			|| !declared_idx_expr || !fixed_desc_expr
			|| ivl_expr_type(fixed_desc_expr) != IVL_EX_NUMBER))) {
		  fprintf(vvp_out, "    %%null; ; find_with: bad arg shape\n");
		  return 0;
	    }
	    ivl_signal_t iter_sig = ivl_expr_signal(iter_arg);
	    ivl_signal_t result_sig = ivl_expr_signal(result_arg);
	    ivl_signal_t idx_sig = ivl_expr_signal(idx_arg);
	    ivl_signal_t declared_idx_sig = is_fixed_property
		  ? ivl_expr_signal(declared_idx_arg) : 0;
	    int fixed_desc = is_fixed_property
		  ? (ivl_expr_uvalue(fixed_desc_expr) != 0)
		  : (!array_receiver_is_dynamic_(q_sig)
		     && ivl_signal_array_addr_swapped(q_sig));
	    int stop_on_match = (is_first && !fixed_desc)
		  || (is_last && fixed_desc);
	    int replace_on_match = (is_first && fixed_desc)
		  || (is_last && !fixed_desc);

	    ivl_type_t iter_type = ivl_signal_net_type(iter_sig);
	    unsigned iter_wid = ivl_type_packed_width(iter_type);
	    if (iter_wid == 0) iter_wid = 32;
	    ivl_variable_type_t bt = ivl_type_base(iter_type);

	      /* Fixed-size unpacked array receivers (7.12.1 locators
	       * apply to any unpacked array) only support vector
	       * element loads via %load/vec4a. */
	    if (!array_receiver_is_dynamic_(q_sig)
		&& bt != IVL_VT_BOOL && bt != IVL_VT_LOGIC) {
		  static int warned_fixed_elem = 0;
		  if (!warned_fixed_elem) {
			fprintf(stderr, "Warning: %s on a fixed-size array"
				" of non-vector elements (compile-progress:"
				" empty result; further similar warnings"
				" suppressed)\n", name);
			warned_fixed_elem = 1;
		  }
		  fprintf(vvp_out, "    %%null; ; find_with: fixed non-vec\n");
		  return 0;
	    }

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
	    /* if (!(idx < size)) goto end */
	    fprintf(vvp_out, "    %%load/vec4 v%p_0;\n", idx_sig);
	    draw_array_size_push_(q_sig);
	    fprintf(vvp_out, "    %%cmp/s;\n");
	    /* %cmp/s sets flag 5 = lt; jump to end if NOT lt */
	    fprintf(vvp_out, "    %%jmp/0xz T_%u.%u, 5;\n",
		    thread_count, lab_end);

	    /* iter_sig = q[idx_sig] — type-specific load/store pair */
	    fprintf(vvp_out, "    %%ix/getv/s 3, v%p_0;\n", idx_sig);
	    if (bt == IVL_VT_BOOL || bt == IVL_VT_LOGIC) {
		  draw_array_elem_load_vec4_(q_sig);
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

	      /* A materialized fixed property is traversed in declared
	       * left-to-right order. Publish its declared index before the
	       * predicate so item.index() and every *_index result observe the
	       * original declared range. */
	    if (is_fixed_property) {
		  draw_eval_vec4(declared_idx_expr);
		  fprintf(vvp_out, "    %%store/vec4 v%p_0, 0, 32;\n",
			  declared_idx_sig);
	    }

	    /* Evaluate predicate (always returns a vec4 boolean) */
	    draw_eval_vec4(pred);
	    if (ivl_expr_width(pred) > 1)
		  fprintf(vvp_out, "    %%or/r;\n");
	    fprintf(vvp_out, "    %%flag_set/vec4 %d;\n", pred_flag);
	    fprintf(vvp_out, "    %%jmp/0xz T_%u.%u, %d;\n",
		    thread_count, lab_skip, pred_flag);

	      /* Canonical fixed-array storage can run opposite the declared
	       * direction. When the requested edge is reached last in this
	       * traversal, replace the hidden result on every match. */
	    if (replace_on_match) {
		  fprintf(vvp_out, "    %%new/queue \"%s\";\n", result_enc);
		  fprintf(vvp_out, "    %%store/obj v%p_0;\n", result_sig);
	    }

	    /* Push q[idx] (or idx) into result_sig.  Index variants always
	     * push the int32 idx onto a vec4 queue. */
	    if (is_index) {
		  fprintf(vvp_out, "    %%load/vec4 v%p_0;\n",
			  is_fixed_property ? declared_idx_sig : idx_sig);
		  fprintf(vvp_out, "    %%store/qb/v v%p_0, 5, 32;\n", result_sig);
	    } else if (bt == IVL_VT_BOOL || bt == IVL_VT_LOGIC) {
		  fprintf(vvp_out, "    %%ix/getv/s 3, v%p_0;\n", idx_sig);
		  draw_array_elem_load_vec4_(q_sig);
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

	    if (stop_on_match)
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
	    fprintf(stderr, "%s:%u: warning: eval_object_sfunc: unsupported sfunc '%s'"
		    " in object context; emitting null fallback"
		    " (further similar warnings suppressed)\n",
		    ivl_expr_file(expr), ivl_expr_lineno(expr), name);
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

/* Store one fixed-unpacked-array property value from an assignment pattern.
 *
 * Unpacked structs are represented by cobjects, and their fixed unpacked
 * members are stored as indexed properties on that cobject.  A nested
 * assignment pattern therefore cannot be evaluated as one object: doing so
 * reaches eval_object_array_pattern(), which has no standalone object for a
 * fixed array and historically degraded to the first element.  Walk only
 * array-typed pattern nodes (a struct-valued element is itself an
 * IVL_EX_ARRAY_PATTERN, but has properties rather than an element type), and
 * write the leaves in canonical flat order using the indexed property
 * opcodes.  The surrounding aggregate object remains on the object stack for
 * every store.
 */
static int emit_fixed_array_property_pattern_(ivl_type_t leaf_type,
                                               unsigned pidx,
                                               ivl_expr_t value_expr,
                                               int word_reg,
                                               unsigned*flat_index)
{
      int errors = 0;
      ivl_type_t value_type = ivl_expr_net_type(value_expr);

      if (ivl_expr_type(value_expr) == IVL_EX_ARRAY_PATTERN
          && value_type && ivl_type_element(value_type)) {
            unsigned idx;
            for (idx = 0; idx < ivl_expr_parms(value_expr); idx += 1)
                  errors += emit_fixed_array_property_pattern_(
                        leaf_type, pidx, ivl_expr_parm(value_expr, idx),
                        word_reg, flat_index);
            return errors;
      }

      switch (leaf_type ? ivl_type_base(leaf_type) : IVL_VT_LOGIC) {
          case IVL_VT_BOOL:
          case IVL_VT_LOGIC: {
            unsigned wid = leaf_type ? ivl_type_packed_width(leaf_type) : 0;
            if (wid == 0)
                  wid = ivl_expr_width(value_expr);
            draw_eval_vec4(value_expr);
            if (leaf_type && ivl_type_base(leaf_type) == IVL_VT_BOOL
                && ivl_expr_value(value_expr) != IVL_VT_BOOL)
                  fprintf(vvp_out, "    %%cast2;\n");
            if (ivl_expr_width(value_expr) != wid)
                  fprintf(vvp_out, "    %%pad/%c %u;\n",
                          (leaf_type && ivl_type_signed(leaf_type)
                           && ivl_expr_signed(value_expr)) ? 's' : 'u', wid);
            fprintf(vvp_out, "    %%ix/load %d, %u, 0;\n",
                    word_reg, *flat_index);
            fprintf(vvp_out, "    %%store/prop/v/i %u, %d, %u;"
                    " fixed-array aggregate member\n",
                    pidx, word_reg, wid);
            break;
          }

          case IVL_VT_REAL:
            draw_eval_real(value_expr);
            fprintf(vvp_out, "    %%ix/load %d, %u, 0;\n",
                    word_reg, *flat_index);
            fprintf(vvp_out, "    %%store/prop/r/i %u, %d;"
                    " fixed-array aggregate member\n", pidx, word_reg);
            break;

          case IVL_VT_STRING:
            draw_eval_string(value_expr);
            fprintf(vvp_out, "    %%ix/load %d, %u, 0;\n",
                    word_reg, *flat_index);
            fprintf(vvp_out, "    %%store/prop/str/i %u, %d;"
                    " fixed-array aggregate member\n", pidx, word_reg);
            break;

          case IVL_VT_CLASS:
          case IVL_VT_DARRAY:
          case IVL_VT_QUEUE:
          case IVL_VT_NO_TYPE:
          default:
            errors += draw_eval_object_value_copy(value_expr, leaf_type);
            fprintf(vvp_out, "    %%ix/load %d, %u, 0;\n",
                    word_reg, *flat_index);
            fprintf(vvp_out, "    %%store/prop/obj %u, %d;"
                    " fixed-array aggregate member\n", pidx, word_reg);
            break;
      }

      *flat_index += 1;
      return errors;
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

      if (ivl_type_element(prop_type)
          && ivl_type_base(prop_type) != IVL_VT_DARRAY
          && ivl_type_base(prop_type) != IVL_VT_QUEUE
          && !ivl_type_is_packed_vector(prop_type)
          && ivl_expr_type(value_expr) == IVL_EX_ARRAY_PATTERN) {
            ivl_type_t leaf_type = ivl_type_element(prop_type);
            int word_reg = allocate_word();
            unsigned flat_index = 0;
            errors += emit_fixed_array_property_pattern_(
                  leaf_type, pidx, value_expr, word_reg, &flat_index);
            clr_word(word_reg);
            return errors;
      }

      switch (ivl_type_base(prop_type)) {
          case IVL_VT_VOID:
            /* A tagged-union void member still needs one store so the
             * runtime records it as the active alternative. */
            fprintf(vvp_out, "    %%pushi/vec4 0, 0, 1;\n");
            fprintf(vvp_out, "    %%store/prop/v %u, 1;\n", pidx);
            return errors;

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

          case IVL_VT_DARRAY:
          case IVL_VT_QUEUE: {
            int converted = draw_eval_container_value_for_target(value_expr,
                                                                  prop_type);
            errors += converted >= 0
                  ? converted
                  : draw_eval_object_value_copy(value_expr, prop_type);
            fprintf(vvp_out, "    %%store/prop/obj %u, 0;\n", pidx);
            return errors;
          }

          case IVL_VT_CLASS:
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
      int union_active_member;
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

      union_active_member = ivl_expr_union_active_member(expr);
      for (idx = 0; idx < nparm; idx += 1) {
            if (union_active_member >= 0
                && idx != (unsigned)union_active_member)
                  continue;
            ivl_type_t prop_type = ivl_type_prop_type(agg_type, idx);
            errors += emit_aggregate_property_store_(prop_type, idx,
                                                     ivl_expr_parm(expr, idx));
      }

      return errors;
}

/* Queue/darray-typed array pattern (e.g. the literal {1,2} pushed into
 * a queue-of-queues): build the container value element by element on
 * the object stack. Queues append with %store/qo/b/<k>; darrays are
 * sized up front and store by index with %store/qo/i/<k>. Both store
 * forms POP the receiver, so each element store works on a
 * %dup/obj/ref ALIAS of the container handle (%dup/obj would deep-copy
 * and the stores would mutate a discarded clone). */
static int container_pattern_operand_is_collection_(ivl_expr_t expr,
                                                     ivl_type_t element_type)
{
      ivl_type_t source_type;
      ivl_type_t source_element;

      if (!expr || !type_is_object_like_(element_type))
            return queue_pattern_operand_is_collection_(expr, element_type);

      /* Context typing can give a container item the OUTER pattern type.
       * Recover the value's declared type instead: a darray<T> used where one
       * queue<T> element is expected is one assignment-compatible element,
       * not a collection splice. This also covers properties and selections,
       * whose t-dll net_type can be absent or contextual. */
      source_type = receiver_container_type_(expr);
      if (!type_is_runtime_container_(source_type)
          || !type_is_runtime_container_(element_type)
          || (ivl_type_base(source_type) == IVL_VT_QUEUE
              && ivl_type_queue_assoc_compat(source_type))
          || (ivl_type_base(element_type) == IVL_VT_QUEUE
              && ivl_type_queue_assoc_compat(element_type)))
            return queue_pattern_operand_is_collection_(expr, element_type);

      source_element = ivl_type_element(source_type);
      if (container_type_shape_eq_(source_type, element_type)
          || container_type_shape_eq_(source_element,
                                      ivl_type_element(element_type)))
            return 0;

      if (container_type_shape_eq_(source_element, element_type))
            return 1;

      return type_is_object_like_(source_element);
}

static int eval_object_container_pattern_(ivl_expr_t expr, ivl_type_t agg_type)
{
      unsigned nparm = ivl_expr_parms(expr);
      ivl_type_t etype = ivl_type_element(agg_type);
      int is_darray = ivl_type_base(agg_type) == IVL_VT_DARRAY;
      char enc[32];
      int errors = 0;
      unsigned idx;

      container_element_enc_(etype, enc, sizeof enc);
      if (is_darray) {
	    fprintf(vvp_out, "    %%ix/load 3, %u, 0;\n", nparm);
	    fprintf(vvp_out, "    %%new/darray 3, \"%s\";\n", enc);
	      /* A pattern element that reads outside a dynamic array is the
	       * element type's default value. Object-backed value structs are
	       * represented by a nil slot until first member access, so retain
	       * their class as a prototype on this temporary. This is essential
	       * when the completed value is copied into a class property, where
	       * there is no signal declared_type() from which to recover it.
	       * Class-handle elements deliberately retain null defaults. */
	    if (etype && ivl_type_base(etype) == IVL_VT_NO_TYPE
		&& ivl_type_properties(etype) > 0) {
		  ensure_class_type_emitted(etype);
		  fprintf(vvp_out,
			  "    %%new/cobj C%p; darray pattern element prototype\n",
			  etype);
		  fprintf(vvp_out, "    %%dar/elem/proto;\n");
	    }
      } else {
	      /* Materialize the complete RHS before a bounded destination
	       * truncates it. Besides preserving evaluation of excess operands,
	       * the final whole-queue assignment then emits the established
	       * source-size warning instead of a per-element push warning. */
	    fprintf(vvp_out, "    %%new/queue \"%s\";\n", enc);
      }

      for (idx = 0; idx < nparm; idx += 1) {
	    ivl_expr_t parm = ivl_expr_parm(expr, idx);
	    if (!parm)
		  continue;
	      /* A same-shape collection operand splices element-wise
	       * (10.10): {q1, 5} with q1 a queue concatenates. Only
	       * queue-built literals support this; a darray literal
	       * with a runtime-sized operand cannot be pre-sized. */
	    if (!is_darray
		&& container_pattern_operand_is_collection_(parm, etype)) {
		  fprintf(vvp_out, "    %%dup/obj/ref;\n");
		  errors += draw_eval_object(parm);
		  switch (etype ? ivl_type_base(etype) : IVL_VT_LOGIC) {
		      case IVL_VT_REAL:
			fprintf(vvp_out, "    %%append/qo/r;\n");
			break;
		      case IVL_VT_STRING:
			fprintf(vvp_out, "    %%append/qo/str;\n");
			break;
		      case IVL_VT_CLASS:
		      case IVL_VT_DARRAY:
		      case IVL_VT_QUEUE:
		      case IVL_VT_NO_TYPE:
			emit_append_object_collection(etype);
			break;
		      default: {
			unsigned wid = etype ? ivl_type_packed_width(etype) : 32;
			if (wid == 0) wid = 32;
			fprintf(vvp_out, "    %%append/qo/v %u;\n", wid);
			break;
		      }
		  }
		  continue;
	    }
	    if (is_darray
		&& container_pattern_operand_is_collection_(parm, etype)) {
		  static int warned_darray_splice = 0;
		  if (!warned_darray_splice) {
			fprintf(stderr, "Warning: draw_eval_object: a"
				" runtime-sized collection operand in a"
				" dynamic-array literal at %s:%u is not"
				" supported; the operand contributes one"
				" default element (further similar warnings"
				" suppressed)\n",
				ivl_expr_file(parm), ivl_expr_lineno(parm));
			warned_darray_splice = 1;
		  }
	    }
	    fprintf(vvp_out, "    %%dup/obj/ref;\n");
	    switch (etype ? ivl_type_base(etype) : IVL_VT_LOGIC) {
		case IVL_VT_REAL:
		  draw_eval_real(parm);
		  if (is_darray) {
			fprintf(vvp_out, "    %%ix/load 3, %u, 0;\n", idx);
			fprintf(vvp_out, "    %%flag_set/imm 4, 0;\n");
		  }
		  emit_object_queue_store_(is_darray ? 'i' : 'b', "r",
		                           0, 0);
		  break;
		case IVL_VT_STRING:
		  draw_eval_string(parm);
		  if (is_darray) {
			fprintf(vvp_out, "    %%ix/load 3, %u, 0;\n", idx);
			fprintf(vvp_out, "    %%flag_set/imm 4, 0;\n");
		  }
		  emit_object_queue_store_(is_darray ? 'i' : 'b', "str",
		                           0, 0);
		  break;
		case IVL_VT_DARRAY:
		case IVL_VT_QUEUE: {
		  int converted = draw_eval_container_value_for_target(parm,
		                                                        etype);
		  errors += converted >= 0 ? converted : draw_eval_object(parm);
		  if (is_darray) {
			fprintf(vvp_out, "    %%ix/load 3, %u, 0;\n", idx);
			fprintf(vvp_out, "    %%flag_set/imm 4, 0;\n");
		  }
		  emit_object_queue_store_(is_darray ? 'i' : 'b', "obj",
		                           0, 0);
		  break;
		}
		case IVL_VT_CLASS:
		case IVL_VT_NO_TYPE:
		  errors += draw_eval_object(parm);
		  if (is_darray) {
			fprintf(vvp_out, "    %%ix/load 3, %u, 0;\n", idx);
			fprintf(vvp_out, "    %%flag_set/imm 4, 0;\n");
		  }
		  emit_object_queue_store_(is_darray ? 'i' : 'b', "obj",
		                           0, 0);
		  break;
		default: {
		  unsigned wid = etype ? ivl_type_packed_width(etype) : 0;
		  if (wid == 0)
			wid = ivl_expr_width(parm);
		  draw_eval_vec4(parm);
		  if (ivl_expr_width(parm) != wid)
			fprintf(vvp_out, "    %%pad/%c %u;\n",
				(etype && ivl_type_signed(etype)
				 && ivl_expr_signed(parm)) ? 's' : 'u',
				wid);
		  if (is_darray) {
			fprintf(vvp_out, "    %%ix/load 3, %u, 0;\n", idx);
			fprintf(vvp_out, "    %%flag_set/imm 4, 0;\n");
		  }
		  emit_object_queue_store_(is_darray ? 'i' : 'b', "v",
		                           0, wid);
		  break;
		}
	    }
      }

      return errors;
}

/* Handle IVL_EX_ARRAY_PATTERN in object context. */
static int eval_object_array_pattern(ivl_expr_t expr)
{
      static int warned_pattern_fallback = 0;
      unsigned nparm = ivl_expr_parms(expr);
      int errors;
      ivl_type_t agg_type;

      errors = eval_object_aggregate_literal_(expr);
      if (errors >= 0)
            return errors;

      agg_type = ivl_expr_net_type(expr);
      if (agg_type && (ivl_type_base(agg_type) == IVL_VT_QUEUE
		       || ivl_type_base(agg_type) == IVL_VT_DARRAY))
	    return eval_object_container_pattern_(expr, agg_type);

      if (nparm == 0) {
	    fprintf(vvp_out, "    %%null; ; empty object array-pattern fallback\n");
	    return 0;
      }

      /* Compile-progress fallback: use the first element — and say so. */
      if (!warned_pattern_fallback) {
	    fprintf(stderr, "Warning: draw_eval_object: array pattern of"
		    " unsupported aggregate type at %s:%u degrades to its"
		    " first element (further similar warnings"
		    " suppressed)\n",
		    ivl_expr_file(expr), ivl_expr_lineno(expr));
	    warned_pattern_fallback = 1;
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

	  case IVL_EX_ARRAY_SLICE:
	    return eval_object_array_slice(ex);

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

/*
 * Evaluate an object r-value that is about to be COPIED into a variable,
 * container element, or container-insert method (`=`, `push_back`/`push_front`/
 * `insert`, queue pattern). An object-backed unpacked struct is a value type
 * (IEEE 1800-2017 7.2): copying it must produce an independent object, not
 * share the source's handle. So when `element_type` is a value struct
 * (IVL_VT_NO_TYPE with properties) and the r-value reads existing struct
 * storage (a signal, a member, or an element select), build a fresh object and
 * shallow-copy the source into it (`%new/cobj` + `%scopy`). A class handle
 * (IVL_VT_CLASS) keeps reference semantics; a freshly built aggregate r-value
 * (array pattern, `new`, concat) is already independent — both fall through to
 * a plain draw_eval_object. Leaves exactly one object on the object stack.
 */
int draw_eval_object_value_copy(ivl_expr_t ex, ivl_type_t element_type)
{
      ivl_expr_type_t rvt = ivl_expr_type(ex);
      int rval_aliases = (rvt == IVL_EX_SIGNAL || rvt == IVL_EX_PROPERTY
			  || rvt == IVL_EX_SELECT);
      int is_value_struct = element_type
			    && ivl_type_base(element_type) == IVL_VT_NO_TYPE
			    && ivl_type_properties(element_type) > 0;
      int is_value_container = element_type
			     && (ivl_type_base(element_type) == IVL_VT_DARRAY
				 || ivl_type_base(element_type) == IVL_VT_QUEUE);

      /* The synthetic queue-last expression returns a live element alias,
       * just like an ordinary IVL_EX_SELECT. Copy an unpacked-struct value
       * selected through q[$], while leaving class-handle elements shared. */
      if (rvt == IVL_EX_SFUNC) {
	    const char*name = ivl_expr_name(ex);
	    if (name && strcmp(name, "$ivl_queue$last") == 0)
		  rval_aliases = 1;
      }

        /* An unpacked-array value can reach the target as an array pattern
         * whose own net type describes the fixed source rather than the
         * dynamic/queue destination. The assignment context supplies the
         * required container type (7.6), so construct and populate that
         * container instead of letting the object evaluator degrade the
         * pattern to its first element. */
      if (rvt == IVL_EX_ARRAY_PATTERN && element_type
	  && (ivl_type_base(element_type) == IVL_VT_DARRAY
	      || ivl_type_base(element_type) == IVL_VT_QUEUE))
	    return eval_object_container_pattern_(ex, element_type);

      if (is_value_container && rval_aliases) {
	    int errors = draw_eval_object(ex);
	    fprintf(vvp_out, "    %%dup/obj; container value copy\n");
	    fprintf(vvp_out, "    %%pop/obj 1, 1; discard source container alias\n");
	    return errors;
      }

      if (is_value_struct && rval_aliases) {
	    ensure_class_type_emitted(element_type);
	    fprintf(vvp_out, "    %%new/cobj C%p; struct value copy\n", element_type);
	    int errors = draw_eval_object(ex);
	    fprintf(vvp_out, "    %%scopy;\n");
	    return errors;
      }

      return draw_eval_object(ex);
}

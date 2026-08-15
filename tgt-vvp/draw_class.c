/*
 * Copyright (c) 2012 Stephen Williams (steve@icarus.com)
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
# include  <stdlib.h>
# include  <string.h>
# include  <assert.h>
# include  <inttypes.h>

static void show_prop_type(ivl_type_t ptype, const char*rand_prefix);

struct emitted_struct_cobject_s {
      ivl_type_t type;
      struct emitted_struct_cobject_s*next;
};

static struct emitted_struct_cobject_s*emitted_struct_cobjects_ = 0;

enum emitted_class_state_e {
      CLASS_EMITTING,
      CLASS_EMITTED
};

struct emitted_class_s {
      ivl_type_t type;
      enum emitted_class_state_e state;
      struct emitted_class_s*next;
};

static struct emitted_class_s*emitted_classes_ = 0;

static struct emitted_class_s*find_emitted_class_(ivl_type_t type)
{
      struct emitted_class_s*cur;
      for (cur = emitted_classes_ ; cur ; cur = cur->next) {
	    if (cur->type == type)
		  return cur;
      }
      return 0;
}

static struct emitted_class_s*mark_class_emitting_(ivl_type_t type)
{
      struct emitted_class_s*node = calloc(1, sizeof(*node));
      node->type = type;
      node->state = CLASS_EMITTING;
      node->next = emitted_classes_;
      emitted_classes_ = node;
      return node;
}

static int emitted_struct_cobject_(ivl_type_t type)
{
      struct emitted_struct_cobject_s*cur;
      for (cur = emitted_struct_cobjects_ ; cur ; cur = cur->next) {
	    if (cur->type == type)
		  return 1;
      }
      return 0;
}

static void mark_struct_cobject_emitted_(ivl_type_t type)
{
      struct emitted_struct_cobject_s*node;
      if (!type || emitted_struct_cobject_(type))
	    return;

      node = calloc(1, sizeof(*node));
      node->type = type;
      node->next = emitted_struct_cobjects_;
      emitted_struct_cobjects_ = node;
}

static int is_unpacked_array_property_type(ivl_type_t ptype)
{
      ivl_type_t element_type = ivl_type_element(ptype);
      if (!element_type)
	    return 0;

      return ivl_type_packed_dimensions(ptype) > 0
          && ivl_type_packed_width(ptype) == 1;
}

static void emit_struct_cobject_dependencies_(ivl_type_t ptype);

static void emit_struct_cobject_definition_(ivl_type_t struct_type)
{
      int idx;
      const char*name;
      const char*directive;

      if (!struct_type || emitted_struct_cobject_(struct_type))
	    return;

      mark_struct_cobject_emitted_(struct_type);

      for (idx = 0 ; idx < ivl_type_properties(struct_type) ; idx += 1) {
	    emit_struct_cobject_dependencies_(ivl_type_prop_type(struct_type, idx));
      }

      name = ivl_type_name(struct_type);
      if (!name)
	    name = "";

      directive = ivl_type_is_tagged_union(struct_type)
	    ? ".class/union/tagged"
	    : ivl_type_is_union(struct_type)
	    ? ".class/union" : ".class/struct";
      fprintf(vvp_out, "C%p  %s \"%s\" [%d]\n",
	      struct_type, directive,
	      name, ivl_type_properties(struct_type));
      for (idx = 0 ; idx < ivl_type_properties(struct_type) ; idx += 1) {
	    ivl_type_t ptype = ivl_type_prop_type(struct_type, idx);
	    int qual = ivl_type_prop_qual(struct_type, idx);
	    const char*rand_prefix = (qual & 16) ? "rc" : (qual & 8) ? "r" : "";
	    char qualifier_prefix[32];
	    snprintf(qualifier_prefix, sizeof qualifier_prefix, "q%x:%s",
		     (unsigned)qual, rand_prefix);
	    fprintf(vvp_out, " %3d: \"%s\", ", idx, ivl_type_prop_name(struct_type, idx));
	    show_prop_type(ptype, qualifier_prefix);
	    if (is_unpacked_array_property_type(ptype)) {
		  unsigned dim;
		  for (dim = 0 ; dim < ivl_type_packed_dimensions(ptype) ; dim += 1) {
			fprintf(vvp_out, " [%d:%d]",
				ivl_type_packed_msb(ptype,dim),
				ivl_type_packed_lsb(ptype,dim));
		  }
	    }
	    fprintf(vvp_out, "\n");
      }
      fprintf(vvp_out, " ;\n");
}

static void emit_struct_cobject_dependencies_(ivl_type_t ptype)
{
      ivl_type_t base_ptype = ptype;
      if (is_unpacked_array_property_type(ptype))
	    base_ptype = ivl_type_element(ptype);

      if (!base_ptype)
	    return;

      if (ivl_type_base(base_ptype) == IVL_VT_NO_TYPE
	  && ivl_type_properties(base_ptype) > 0) {
	    emit_struct_cobject_definition_(base_ptype);
      }
}

static void emit_class_dependencies_(ivl_type_t classtype)
{
      int idx;

      for (idx = 0 ; idx < (int)ivl_type_interface_count(classtype) ; idx += 1)
	    ensure_class_type_emitted(ivl_type_interface(classtype, idx));

      for (idx = 0 ; idx < ivl_type_properties(classtype) ; idx += 1) {
	    ivl_type_t ptype = ivl_type_prop_type(classtype, idx);
	    if (is_unpacked_array_property_type(ptype))
		  ptype = ivl_type_element(ptype);
	    if (ptype && ivl_type_base(ptype) == IVL_VT_CLASS)
		  ensure_class_type_emitted(ptype);
      }
}

static void show_prop_type_vector(ivl_type_t ptype, const char*rand_prefix)
{
      ivl_variable_type_t data_type = ivl_type_base(ptype);
      unsigned packed_width = ivl_type_packed_width(ptype);
      if (packed_width == 0)
	    packed_width = 1;

      const char*signed_flag = ivl_type_signed(ptype)? "s" : "";
      char code = data_type==IVL_VT_BOOL? 'b' : 'L';

      if (packed_width == 1) {
	    fprintf(vvp_out, "\"%s%s%c1\"", rand_prefix, signed_flag, code);

      } else {
	    fprintf(vvp_out, "\"%s%s%c%d\"", rand_prefix, signed_flag, code,
		    packed_width);
      }
}

/* Keep an enum property's finite declaration domain alongside its ordinary
 * packed-vector storage code. The vvp reader strips e{...}: before selecting
 * the storage implementation, while randomize() uses the retained values so
 * a sparse enum never receives an unnamed encoding. ivl_enum_bits is LSB
 * first, matching vvp_vector4_t bit indexes directly. */
static void show_prop_type_enum(ivl_enumtype_t enumtype,
				const char*rand_prefix)
{
      unsigned idx;
      unsigned emitted = 0;
      const char*rp = rand_prefix ? rand_prefix : "";
      const char*signed_flag = ivl_enum_signed(enumtype) ? "s" : "";
      char code = ivl_enum_type(enumtype) == IVL_VT_BOOL ? 'b' : 'L';

      fprintf(vvp_out, "\"%se{", rp);
      for (idx = 0 ; idx < ivl_enum_names(enumtype) ; idx += 1) {
	    const char*bits = ivl_enum_bits(enumtype, idx);
	    if (!bits)
		  continue;
	    if (emitted)
		  fputc(',', vvp_out);
	    fputs(bits, vvp_out);
	    emitted += 1;
      }
      fprintf(vvp_out, "}:%s%c%u\"", signed_flag, code,
	      ivl_enum_width(enumtype));
}

static void show_prop_type_queue(ivl_type_t ptype, const char*rand_prefix)
{
      ivl_type_t element_type = ivl_type_element(ptype);
      int assoc_compat = ivl_type_queue_assoc_compat(ptype);
      const char*rp = rand_prefix ? rand_prefix : "";

      if (!element_type) {
	    fprintf(vvp_out, assoc_compat ? "\"%sMo\"" : "\"%sQo\"", rp);
	    return;
      }

      switch (ivl_type_base(element_type)) {
	  case IVL_VT_REAL:
	    fprintf(vvp_out, assoc_compat ? "\"%sMr\"" : "\"%sQr\"", rp);
	    break;
	  case IVL_VT_STRING:
	    fprintf(vvp_out, assoc_compat ? "\"%sMS\"" : "\"%sQS\"", rp);
	    break;
	  case IVL_VT_BOOL:
	  case IVL_VT_LOGIC:
	    if (assoc_compat)
		  fprintf(vvp_out, "\"%sMv%u\"", rp, ivl_type_packed_width(element_type));
	    else
		  fprintf(vvp_out, "\"%sQv\"", rp);
	    break;
	  case IVL_VT_CLASS:
	  case IVL_VT_DARRAY:
	  case IVL_VT_QUEUE:
	  case IVL_VT_NO_TYPE:
	  case IVL_VT_VOID:
	    fprintf(vvp_out, assoc_compat ? "\"%sMo\"" : "\"%sQo\"", rp);
	    break;
	  default:
	    fprintf(vvp_out, assoc_compat ? "\"%sMo\"" : "\"%sQo\"", rp);
	    break;
      }
}

/*
 * Keep dynamic-array declarations distinct from generic object handles in
 * the .class metadata. Both use object storage at runtime, but VPI needs the
 * declaration kind even while the dynamic array is null or empty.
 *
 * D{r,S,o,v<width>,sv<width>} mirrors the queue/associative-array element
 * tags while retaining integral width and signedness.
 */
static void show_prop_type_darray(ivl_type_t ptype, const char*rand_prefix)
{
      ivl_type_t element_type = ivl_type_element(ptype);
      const char*rp = rand_prefix ? rand_prefix : "";

      if (!element_type) {
	    fprintf(vvp_out, "\"%sDo\"", rp);
	    return;
      }

      switch (ivl_type_base(element_type)) {
	  case IVL_VT_REAL:
	    fprintf(vvp_out, "\"%sDr\"", rp);
	    break;
	  case IVL_VT_STRING:
	    fprintf(vvp_out, "\"%sDS\"", rp);
	    break;
	  case IVL_VT_BOOL:
	  case IVL_VT_LOGIC:
	    fprintf(vvp_out, "\"%sD%sv%u\"", rp,
		    ivl_type_signed(element_type) ? "s" : "",
		    ivl_type_packed_width(element_type));
	    break;
	  default:
	    fprintf(vvp_out, "\"%sDo\"", rp);
	    break;
      }
}

static void show_prop_type(ivl_type_t ptype, const char*rand_prefix)
{
      ivl_type_t base_ptype = ptype;
      if (is_unpacked_array_property_type(ptype)) {
	    base_ptype = ivl_type_element(ptype);
      }

      ivl_enumtype_t enumtype = ivl_type_enum(base_ptype);
      if (enumtype) {
	    show_prop_type_enum(enumtype, rand_prefix);
	    return;
      }

      ivl_variable_type_t data_type = ivl_type_base(base_ptype);
      unsigned packed_dimensions = ivl_type_packed_dimensions(base_ptype);

      switch (data_type) {
	  case IVL_VT_VOID:
	    fprintf(vvp_out, "\"%sV\"", rand_prefix ? rand_prefix : "");
	    break;
	  case IVL_VT_NO_TYPE:
	      /* An unpacked-struct property must retain its rand/randc
	       * qualifier in the runtime metadata just like every other
	       * property kind below -- omitting it here silently dropped
	       * `rand`/`randc` on unpacked-struct properties entirely
	       * (class_type::property_is_rand() would always read false),
	       * which is why %randomize never touched them (IEEE 1800-2017
	       * 18.4). */
	    if (base_ptype && ivl_type_properties(base_ptype) > 0)
		  fprintf(vvp_out, "\"%soc:C%p\"", rand_prefix ? rand_prefix : "", base_ptype);
	    else
		  fprintf(vvp_out, "\"%so\"", rand_prefix ? rand_prefix : "");
	    break;
	  case IVL_VT_REAL:
	    fprintf(vvp_out, "\"%sr\"", rand_prefix ? rand_prefix : "");
	    break;
	  case IVL_VT_STRING:
	    fprintf(vvp_out, "\"%sS\"", rand_prefix ? rand_prefix : "");
	    break;
	  case IVL_VT_QUEUE:
	    show_prop_type_queue(base_ptype, rand_prefix);
	    break;
	  case IVL_VT_BOOL:
	  case IVL_VT_LOGIC:
	    show_prop_type_vector(base_ptype, rand_prefix);
	    break;
	  case IVL_VT_DARRAY:
	    show_prop_type_darray(base_ptype, rand_prefix);
	    break;
	  case IVL_VT_CLASS:
	      /* A rand class-handle property must retain its qualifier in
	       * the runtime metadata, just like containers and vectors. Keep
	       * its declared class too, so a base-typed VPI view does not
	       * expose a derived hidden member from the live object. */
	    fprintf(vvp_out, "\"%soh:C%p\"", rand_prefix ? rand_prefix : "",
		    base_ptype);
	    if (packed_dimensions > 0) {
		  unsigned idx;
		  fprintf(vvp_out, " ");
		  for (idx = 0 ; idx < packed_dimensions ; idx += 1) {
			fprintf(vvp_out, "[%d:%d]",
				ivl_type_packed_msb(ptype,idx),
				ivl_type_packed_lsb(ptype,idx));
		  }
	    }
	    break;
	  default:
	    fprintf(stderr, "ERROR: Unknown property type: %d\n", data_type);
	    fprintf(stderr, "  Type name: %s\n",
		    base_ptype ? ivl_type_name(base_ptype) : "<null>");
	    fprintf(vvp_out, "\"<ERROR-no-type>\"");
	    assert(0);
	    break;
      }
}

void draw_class_in_scope(ivl_type_t classtype)
{
      int idx;
      struct emitted_class_s*emitted_class = 0;
      const char*dispatch_prefix = ivl_type_method_prefix(classtype);
      ivl_type_t super_type = ivl_type_super(classtype);
      const char*super_dispatch_prefix = ivl_type_method_prefix(super_type);

      if (classtype && ivl_type_base(classtype) == IVL_VT_NO_TYPE) {
	    if (emitted_struct_cobject_(classtype))
		  return;
	    mark_struct_cobject_emitted_(classtype);
      }

      if (classtype && ivl_type_base(classtype) == IVL_VT_CLASS) {
	    emitted_class = find_emitted_class_(classtype);
	    if (emitted_class)
		  return;
	    emitted_class = mark_class_emitting_(classtype);
	    emit_class_dependencies_(classtype);
      }

      for (idx = 0 ; idx < ivl_type_properties(classtype) ; idx += 1) {
	    emit_struct_cobject_dependencies_(ivl_type_prop_type(classtype, idx));
      }

      if (classtype && ivl_type_base(classtype) == IVL_VT_NO_TYPE) {
	      /* A synthetic struct cobject: the /struct marker drives the
	         runtime element-copy policy (structs copy by value inside
	         containers; real class handles stay shared). Struct types
	         reached as property dependencies get the marker from
	         emit_struct_cobject_definition_; this is the same form for
	         struct types emitted by the scope walk. */
	    const char*name = ivl_type_name(classtype);
	    const char*directive = ivl_type_is_tagged_union(classtype)
		  ? ".class/union/tagged"
		  : ivl_type_is_union(classtype)
		  ? ".class/union" : ".class/struct";
	    fprintf(vvp_out, "C%p  %s \"%s\" [%d]\n",
		    classtype, directive, name ? name : "",
		    ivl_type_properties(classtype));
      } else if (dispatch_prefix && *dispatch_prefix
          && super_dispatch_prefix && *super_dispatch_prefix) {
	    fprintf(vvp_out, "C%p  .class \"%s\" \"%s\" \"%s\" [%d]\n",
		    classtype, ivl_type_name(classtype), dispatch_prefix,
		    super_dispatch_prefix, ivl_type_properties(classtype));
      } else if (dispatch_prefix && *dispatch_prefix) {
	    fprintf(vvp_out, "C%p  .class \"%s\" \"%s\" [%d]\n",
		    classtype, ivl_type_name(classtype), dispatch_prefix,
		    ivl_type_properties(classtype));
      } else {
	    fprintf(vvp_out, "C%p  .class \"%s\" [%d]\n",
		    classtype, ivl_type_name(classtype), ivl_type_properties(classtype));
      }

      for (idx = 0 ; idx < ivl_type_properties(classtype) ; idx += 1) {
	    ivl_type_t ptype = ivl_type_prop_type(classtype,idx);
	    int qual = ivl_type_prop_qual(classtype, idx);
	    const char*rand_prefix = (qual & 16) ? "rc" : (qual & 8) ? "r" : "";
	    char qualifier_prefix[32];
	    snprintf(qualifier_prefix, sizeof qualifier_prefix, "q%x:%s",
		     (unsigned)qual, rand_prefix);
	    fprintf(vvp_out, " %3d: \"%s\", ", idx, ivl_type_prop_name(classtype,idx));
	    show_prop_type(ptype, qualifier_prefix);
	    /* Keep the complete source qualifier in the runtime class
	       definition. The q<hex>: prefix wraps the historical type string,
	       whose rand/randc prefix remains for backwards compatibility. This
	       avoids changing the .class grammar while carrying static, access,
	       and const bits to the runtime. */
	    if (is_unpacked_array_property_type(ptype)) {
		  unsigned dim;
		  for (dim = 0 ; dim < ivl_type_packed_dimensions(ptype) ; dim += 1) {
			fprintf(vvp_out, " [%d:%d]",
				ivl_type_packed_msb(ptype,dim),
				ivl_type_packed_lsb(ptype,dim));
		  }
	    }
	    fprintf(vvp_out, "\n");

	      /* A static property is backed by the signal in its declaring
	         class scope. Export that exact absolute-pid binding; inherited
	         and hidden properties must never be recovered by name in the
	         derived class. Scalar variables use their word label, while a
	         fixed unpacked array is addressed by its .array label. */
	    if (qual & 1) {
		  ivl_signal_t storage = ivl_type_prop_signal(classtype, idx);
		  assert(storage);
		  fprintf(vvp_out, " .static_prop %d v%p%s\n", idx, storage,
			  ivl_signal_dimensions(storage) ? "" : "_0");
	    }
      }

      for (idx = 0 ; idx < (int)ivl_type_interface_count(classtype) ; idx += 1) {
	    ivl_type_t interface_type = ivl_type_interface(classtype, idx);
	    const char*interface_prefix = ivl_type_method_prefix(interface_type);
	    assert(interface_prefix && *interface_prefix);
	    fprintf(vvp_out, " .implements \"%s\"\n", interface_prefix);
      }

      {
	    int nc = ivl_type_constraints(classtype);
	    for (idx = 0 ; idx < nc ; idx += 1) {
		  fprintf(vvp_out, " .constraint \"%s\" \"%s\"\n",
			  ivl_type_constraint_name(classtype, idx),
			  ivl_type_constraint_ir(classtype, idx));
	    }
      }

      {
	      /* M11: full record form — cp prop lo hi kind tuple item.
		 (vvp also still parses the older 4/5-operand forms.) */
	    int nb = ivl_type_covgrp_bins(classtype);
	    for (idx = 0 ; idx < nb ; idx += 1) {
		  fprintf(vvp_out, " .covgrp_bin %u %u %" PRIu64 " %" PRIu64 " %u %u %u\n",
			  ivl_type_covgrp_bin_cp(classtype, idx),
			  ivl_type_covgrp_bin_prop(classtype, idx),
			  ivl_type_covgrp_bin_lo(classtype, idx),
			  ivl_type_covgrp_bin_hi(classtype, idx),
			  ivl_type_covgrp_bin_kind(classtype, idx),
			  ivl_type_covgrp_bin_tuple(classtype, idx),
			  ivl_type_covgrp_bin_item(classtype, idx));
	    }
	    int nd = ivl_type_covgrp_dyn_bins(classtype);
	    for (idx = 0 ; idx < nd ; idx += 1) {
		  fprintf(vvp_out,
			  " .covgrp_dyn_bin %u %u %u %u %" PRIu64
			  " \"%s\" \"%s\" \"%s\"\n",
			  ivl_type_covgrp_dyn_bin_cp(classtype, idx),
			  ivl_type_covgrp_dyn_bin_item(classtype, idx),
			  ivl_type_covgrp_dyn_bin_kind(classtype, idx),
			  ivl_type_covgrp_dyn_bin_family(classtype, idx),
			  ivl_type_covgrp_dyn_bin_array_size(classtype, idx),
			  ivl_type_covgrp_dyn_bin_name(classtype, idx),
			  ivl_type_covgrp_dyn_bin_lo_ir(classtype, idx),
			  ivl_type_covgrp_dyn_bin_hi_ir(classtype, idx));
	    }
	    int ni = ivl_type_covgrp_items(classtype);
	    for (idx = 0 ; idx < ni ; idx += 1) {
		    /* M12-7: the trailing string is the coverpoint/cross
		       label, consumed by the VPI drill-down handles. */
		  fprintf(vvp_out, " .covgrp_item %u %u %u \"%s\" \"%s\" %d\n",
			  ivl_type_covgrp_item_at_least(classtype, idx),
			  ivl_type_covgrp_item_weight(classtype, idx),
			  ivl_type_covgrp_item_is_cross(classtype, idx),
			  ivl_type_covgrp_item_name(classtype, idx),
			  ivl_type_covgrp_item_weight_ir(classtype, idx),
			  ivl_type_covgrp_item_guardsrc(classtype, idx) + 1);
	    }
	      /* M11-3: event-driven sampling metadata — the hidden
		 parent-handle property plus per-coverpoint parent
		 source/guard property indexes. */
	      /* Property indexes are emitted biased by +1 (0 = none)
		 because the vvp lexer only accepts unsigned numbers. */
	    int pprop = ivl_type_covgrp_parent_prop(classtype);
	    if (pprop >= 0) {
		  fprintf(vvp_out, " .covgrp_parent %d\n", pprop);
		  int ncp = ivl_type_covgrp_ncoverpoints(classtype);
		  for (idx = 0 ; idx < ncp ; idx += 1) {
			fprintf(vvp_out, " .covgrp_src %d %d\n",
				ivl_type_covgrp_srcprop(classtype, idx) + 1,
				ivl_type_covgrp_guardsrc(classtype, idx) + 1);
		  }
	    }
      }

      fprintf(vvp_out, " ;\n");
      if (emitted_class)
	    emitted_class->state = CLASS_EMITTED;
}

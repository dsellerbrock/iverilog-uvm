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

      if (!struct_type || emitted_struct_cobject_(struct_type))
	    return;

      mark_struct_cobject_emitted_(struct_type);

      for (idx = 0 ; idx < ivl_type_properties(struct_type) ; idx += 1) {
	    emit_struct_cobject_dependencies_(ivl_type_prop_type(struct_type, idx));
      }

      name = ivl_type_name(struct_type);
      if (!name)
	    name = "";

      fprintf(vvp_out, "C%p  .class \"%s\" [%d]\n",
	      struct_type, name, ivl_type_properties(struct_type));
      for (idx = 0 ; idx < ivl_type_properties(struct_type) ; idx += 1) {
	    ivl_type_t ptype = ivl_type_prop_type(struct_type, idx);
	    fprintf(vvp_out, " %3d: \"%s\", ", idx, ivl_type_prop_name(struct_type, idx));
	    show_prop_type(ptype, "");
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

static void show_prop_type_queue(ivl_type_t ptype)
{
      ivl_type_t element_type = ivl_type_element(ptype);
      int assoc_compat = ivl_type_queue_assoc_compat(ptype);

      if (!element_type) {
	    fprintf(vvp_out, assoc_compat ? "\"Mo\"" : "\"Qo\"");
	    return;
      }

      switch (ivl_type_base(element_type)) {
	  case IVL_VT_REAL:
	    fprintf(vvp_out, assoc_compat ? "\"Mr\"" : "\"Qr\"");
	    break;
	  case IVL_VT_STRING:
	    fprintf(vvp_out, assoc_compat ? "\"MS\"" : "\"QS\"");
	    break;
	  case IVL_VT_BOOL:
	  case IVL_VT_LOGIC:
	    if (assoc_compat)
		  fprintf(vvp_out, "\"Mv%u\"", ivl_type_packed_width(element_type));
	    else
		  fprintf(vvp_out, "\"Qv\"");
	    break;
	  case IVL_VT_CLASS:
	  case IVL_VT_DARRAY:
	  case IVL_VT_QUEUE:
	  case IVL_VT_NO_TYPE:
	  case IVL_VT_VOID:
	    fprintf(vvp_out, assoc_compat ? "\"Mo\"" : "\"Qo\"");
	    break;
	  default:
	    fprintf(vvp_out, assoc_compat ? "\"Mo\"" : "\"Qo\"");
	    break;
      }
}

static void show_prop_type(ivl_type_t ptype, const char*rand_prefix)
{
      ivl_type_t base_ptype = ptype;
      if (is_unpacked_array_property_type(ptype)) {
	    base_ptype = ivl_type_element(ptype);
      }

      ivl_variable_type_t data_type = ivl_type_base(base_ptype);
      unsigned packed_dimensions = ivl_type_packed_dimensions(base_ptype);

      switch (data_type) {
	  case IVL_VT_VOID:
	  case IVL_VT_NO_TYPE:
	    if (base_ptype && ivl_type_properties(base_ptype) > 0)
		  fprintf(vvp_out, "\"oc:C%p\"", base_ptype);
	    else
		  fprintf(vvp_out, "\"o\"");
	    break;
	  case IVL_VT_REAL:
	    fprintf(vvp_out, "\"r\"");
	    break;
	  case IVL_VT_STRING:
	    fprintf(vvp_out, "\"S\"");
	    break;
	  case IVL_VT_QUEUE:
	    show_prop_type_queue(base_ptype);
	    break;
	  case IVL_VT_BOOL:
	  case IVL_VT_LOGIC:
	    show_prop_type_vector(base_ptype, rand_prefix);
	    break;
	  case IVL_VT_DARRAY:
	  case IVL_VT_CLASS:
	    fprintf(vvp_out, "\"o\"");
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
      const char*dispatch_prefix = ivl_type_method_prefix(classtype);
      ivl_type_t super_type = ivl_type_super(classtype);
      const char*super_dispatch_prefix = ivl_type_method_prefix(super_type);

      if (classtype && ivl_type_base(classtype) == IVL_VT_NO_TYPE) {
	    if (emitted_struct_cobject_(classtype))
		  return;
	    mark_struct_cobject_emitted_(classtype);
      }

      for (idx = 0 ; idx < ivl_type_properties(classtype) ; idx += 1) {
	    emit_struct_cobject_dependencies_(ivl_type_prop_type(classtype, idx));
      }

      if (dispatch_prefix && *dispatch_prefix
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
	    fprintf(vvp_out, " %3d: \"%s\", ", idx, ivl_type_prop_name(classtype,idx));
	    show_prop_type(ptype, rand_prefix);
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

      {
	    int nc = ivl_type_constraints(classtype);
	    for (idx = 0 ; idx < nc ; idx += 1) {
		  fprintf(vvp_out, " .constraint \"%s\" \"%s\"\n",
			  ivl_type_constraint_name(classtype, idx),
			  ivl_type_constraint_ir(classtype, idx));
	    }
      }

      {
	    int nb = ivl_type_covgrp_bins(classtype);
	    for (idx = 0 ; idx < nb ; idx += 1) {
		  fprintf(vvp_out, " .covgrp_bin %u %u %" PRIu64 " %" PRIu64 "\n",
			  ivl_type_covgrp_bin_cp(classtype, idx),
			  ivl_type_covgrp_bin_prop(classtype, idx),
			  ivl_type_covgrp_bin_lo(classtype, idx),
			  ivl_type_covgrp_bin_hi(classtype, idx));
	    }
      }

      fprintf(vvp_out, " ;\n");
}

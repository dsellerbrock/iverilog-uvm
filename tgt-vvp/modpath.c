/*
 * Copyright (c) 2007-2020 Stephen Williams (steve@icarus.com)
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
# include  "vpi_user.h"
# include  <string.h>
# include  <stdlib.h>
# include  <assert.h>
# include  "ivl_alloc.h"

static ivl_signal_t find_path_source_port(ivl_delaypath_t path)
{
      unsigned idx;
      ivl_nexus_t nex = ivl_path_source(path);
      ivl_scope_t path_scope = ivl_path_scope(path);

      for (idx = 0 ;  idx < ivl_nexus_ptrs(nex) ;  idx += 1) {
	    ivl_nexus_ptr_t ptr = ivl_nexus_ptr(nex, idx);
	    ivl_signal_t sig = ivl_nexus_ptr_sig(ptr);
	    if (sig == 0)
		  continue;
	    if (ivl_signal_port(sig) == IVL_SIP_NONE)
		  continue;

	      /* The path source scope must match the modpath scope.*/
	    if (ivl_signal_scope(sig) != path_scope)
		  continue;

	    return sig;
      }

	/* An interface member reached through a port handle (IEEE 1800
	   25.6) is not a port of the path scope; the member itself is the
	   input terminal. Never return 0: "%p" of a null pointer is "0x0"
	   on macOS but "(nil)" on glibc, which vvp cannot parse. */
      ivl_signal_t any = 0;
      for (idx = 0 ;  idx < ivl_nexus_ptrs(nex) ;  idx += 1) {
	    ivl_signal_t sig = ivl_nexus_ptr_sig(ivl_nexus_ptr(nex, idx));
	    if (sig == 0)
		  continue;
	    if (!ivl_signal_local(sig))
		  return sig;
	    if (any == 0)
		  any = sig;
      }

      assert(any);
      return any;
}

static void draw_quoted_condition(const char*text)
{
      fputc('"', vvp_out);
      while (*text) {
	    if (*text == '"' || *text == '\\') fputc('\\', vvp_out);
	    fputc(*text++, vvp_out);
      }
      fputc('"', vvp_out);
}

/* The pulse control flags of a module path output: bit 0 showcancelled
   (IEEE 1800-2023 30.7.4.2), bit 1 pulsestyle_ondetect (30.7.4.1). */
static int signal_pulse_flags(ivl_signal_t sig)
{
      unsigned idx;
      int flags = 0;
      for (idx = 0; idx < ivl_signal_attr_cnt(sig); idx += 1) {
	    ivl_attribute_t attr = ivl_signal_attr_val(sig, idx);
	    if (attr->type != IVL_ATT_NUM || attr->val.num == 0) continue;
	    if (strcmp(attr->key, "_ivl_showcancelled") == 0) flags |= 1;
	    if (strcmp(attr->key, "_ivl_pulsestyle_ondetect") == 0) flags |= 2;
      }
      return flags;
}

/*
* Draw a .modpath record. The label is the label to use for this
* record. The driver is the label of the net that feeds into the
* modpath device. (Note that there is only 1 driver.) The path_sig is
* the signal that is the output of this modpath. From that signal we
* can find all the modpath source nodes to generate the complete
* modpath record.
*/
static void draw_modpath_record(const char*label, const char*driver,
				ivl_signal_t path_sig)
{
      unsigned idx;
      typedef const char*ccharp;
      ccharp*src_drivers;
      ccharp*con_drivers;
      ccharp*condition_texts;

      unsigned width = ivl_signal_width(path_sig);

      src_drivers = calloc(ivl_signal_npath(path_sig), sizeof(ccharp));
      con_drivers = calloc(ivl_signal_npath(path_sig), sizeof(ccharp));
      condition_texts = calloc(ivl_signal_npath(path_sig), sizeof(ccharp));
      for (idx = 0 ;  idx < ivl_signal_npath(path_sig) ;  idx += 1) {
	    ivl_delaypath_t path = ivl_signal_path(path_sig, idx);
	    ivl_nexus_t src = ivl_path_source(path);
	    ivl_nexus_t con = ivl_path_condit(path);

	    src_drivers[idx] = draw_net_input(src);

	    if (con) con_drivers[idx] = draw_net_input(con);
	    else if (ivl_path_is_condit(path)) con_drivers[idx] = "";
	    else con_drivers[idx] = 0;
	    condition_texts[idx] = ivl_path_condition_text(path);
      }

      fprintf(vvp_out, "  .scope S_%p;\n", ivl_path_scope(ivl_signal_path(path_sig,0)));
      fprintf(vvp_out, "%s .modpath %u %u %s v%p_0", label, width,
	      signal_pulse_flags(path_sig), driver, path_sig);

      for (idx = 0 ;  idx < ivl_signal_npath(path_sig); idx += 1) {
	    ivl_delaypath_t path = ivl_signal_path(path_sig, idx);
	    int ppos = ivl_path_source_posedge(path);
	    int pneg = ivl_path_source_negedge(path);
	    const char*edge = ppos && pneg ? " *" : ppos ? " +" : pneg ? " -" : "";
	    ivl_signal_t src_sig;

	    fprintf(vvp_out, ",\n   %s%s", src_drivers[idx], edge);
	    fprintf(vvp_out,
		    " (%"PRIu64",%"PRIu64",%"PRIu64
		    ", %"PRIu64",%"PRIu64",%"PRIu64
		    ", %"PRIu64",%"PRIu64",%"PRIu64
		    ", %"PRIu64",%"PRIu64",%"PRIu64,
		    ivl_path_delay(path, IVL_PE_01),
		    ivl_path_delay(path, IVL_PE_10),
		    ivl_path_delay(path, IVL_PE_0z),
		    ivl_path_delay(path, IVL_PE_z1),
		    ivl_path_delay(path, IVL_PE_1z),
		    ivl_path_delay(path, IVL_PE_z0),
		    ivl_path_delay(path, IVL_PE_0x),
		    ivl_path_delay(path, IVL_PE_x1),
		    ivl_path_delay(path, IVL_PE_1x),
		    ivl_path_delay(path, IVL_PE_x0),
		    ivl_path_delay(path, IVL_PE_xz),
		    ivl_path_delay(path, IVL_PE_zx));

	    if (con_drivers[idx]) {
		  fprintf(vvp_out, " ? %s", con_drivers[idx]);
		  if (condition_texts[idx]) {
			fputc(' ', vvp_out);
			draw_quoted_condition(condition_texts[idx]);
		  }
	    }

	    fprintf(vvp_out, ")");

	    src_sig = find_path_source_port(path);
	    fprintf(vvp_out, " v%p_0", src_sig);
	    if (ivl_path_dst_width(path) || ivl_path_src_width(path))
		  fprintf(vvp_out, " [%u %u %u %u]", ivl_path_dst_base(path),
			  ivl_path_dst_width(path), ivl_path_src_base(path),
			  ivl_path_src_width(path));
	    {
		  uint64_t reject, error;
		  if (ivl_path_pulse_limits(path, &reject, &error))
			fprintf(vvp_out, " / %" PRIu64 " %" PRIu64, reject, error);
	    }
      }

      fprintf(vvp_out, ";\n");

	/* A delay that uses a specparam keeps its expressions for SDF
	   LABEL re-evaluation (IEEE 1800 32.4.3). */
      for (idx = 0 ;  idx < ivl_signal_npath(path_sig); idx += 1) {
	    ivl_delaypath_t path = ivl_signal_path(path_sig, idx);
	    unsigned expr, tok;
	    if (ivl_path_delay_exprs(path) == 0) continue;
	    fprintf(vvp_out, "    .pathexpr %s, %u, %u", label, idx,
		    ivl_path_delay_exprs(path));
	    for (expr = 0 ; expr < ivl_path_delay_exprs(path) ; expr += 1) {
		  fprintf(vvp_out, " \"");
		  for (tok = 0 ; tok < ivl_path_delay_expr_tokens(path, expr) ; tok += 1) {
			double value;
			ivl_signal_t sig;
			int kind = ivl_path_delay_expr_token(path, expr, tok,
							     &value, &sig);
			if (tok) fputc(' ', vvp_out);
			if (kind == 'c') fprintf(vvp_out, "%.17g", value);
			else if (kind == 's') fprintf(vvp_out, "v%p_0", sig);
			else fputc(kind, vvp_out);
		  }
		  fprintf(vvp_out, "\"");
	    }
	    fprintf(vvp_out, ";\n");
      }

      free(src_drivers);
      free(con_drivers);
      free(condition_texts);
}

struct modpath_item {
      ivl_signal_t path_sig;
      char*drive_label;
      unsigned drive_index;
      ivl_nexus_ptr_t driver;
      struct modpath_item*next;
};

static struct modpath_item*modpath_list = 0;

void draw_modpath(ivl_signal_t path_sig, char*drive_label, unsigned drive_index,
		  ivl_nexus_ptr_t driver)
{
      struct modpath_item*cur = calloc(1, sizeof(struct modpath_item));
      cur->path_sig = path_sig;
      cur->drive_label = drive_label;
      cur->drive_index = drive_index;
      cur->driver = driver;
      cur->next = modpath_list;
      modpath_list = cur;
}

/* Correlate the original elaborated output pin with the emitted VPI object.
 * The functor label alone can identify a shared input after BUFZ elision. */
struct modpath_assign {
      ivl_scope_t scope;
      const char*name;
      unsigned label;
};

static struct modpath_assign*assigns;
static size_t nassigns, assign_capacity;

void note_modpath_contassign(ivl_scope_t scope, const char*name, unsigned label)
{
      if (!name) return;
      if (nassigns == assign_capacity) {
	    assign_capacity = assign_capacity ? 2 * assign_capacity : 64;
	    assigns = realloc(assigns, assign_capacity * sizeof(*assigns));
      }
      assigns[nassigns++] = (struct modpath_assign){scope, name, label};
}

static int compare_assigns(const void*a, const void*b)
{
      const struct modpath_assign*x = a, *y = b;
      if (x->scope != y->scope)
	    return (uintptr_t)x->scope < (uintptr_t)y->scope ? -1 : 1;
      return strcmp(x->name, y->name);
}

static void draw_stage_conn(const char*stage, unsigned base, unsigned width,
			    int type, const char*symbol, unsigned index)
{
      fprintf(vvp_out, " .modpath_conn %s, %u, %u, %d, %s, %u;\n",
	      stage, base, width, type, symbol, index);
}

/* Every named net on the physical nexus belongs to this side of the device. */
static int draw_stage_nets(const char*stage, ivl_nexus_t nex, int type,
			    unsigned base, unsigned width, unsigned net_base)
{
      int found = 0;
      for (unsigned idx = 0; idx < ivl_nexus_ptrs(nex); ++idx) {
	    ivl_nexus_ptr_t ptr = ivl_nexus_ptr(nex, idx);
	    ivl_signal_t sig = ivl_nexus_ptr_sig(ptr);
	    if (!sig || ivl_signal_local(sig) || ivl_signal_type(sig) == IVL_SIT_REG)
		  continue;
	    if (ivl_signal_data_type(sig) == IVL_VT_REAL
		|| net_base >= ivl_signal_width(sig)
		|| width > ivl_signal_width(sig) - net_base)
		  continue;
	    char symbol[64];
	    snprintf(symbol, sizeof symbol, "v%p_%u", sig, ivl_nexus_ptr_pin(ptr));
	    draw_stage_conn(stage, base, width, type, symbol, net_base);
	    found = 1;
      }
      return found;
}

struct stage_walk {
      ivl_nexus_t nex;
      const struct stage_walk*parent;
};

static void draw_stage_driver(const char*stage, ivl_nexus_ptr_t ptr,
			      unsigned base, unsigned first, unsigned width,
			      const struct stage_walk*walk);

static void draw_stage_input(const char*stage, ivl_nexus_t nex,
			     unsigned base, unsigned first, unsigned width,
			     const struct stage_walk*parent)
{
      if (!nex) return;
      for (const struct stage_walk*cur = parent; cur; cur = cur->parent)
	    if (cur->nex == nex) return;
      if (draw_stage_nets(stage, nex, vpiNet, base, width, first)) return;

      struct stage_walk walk = {nex, parent};
      for (unsigned idx = 0; idx < ivl_nexus_ptrs(nex); ++idx) {
	    ivl_nexus_ptr_t ptr = ivl_nexus_ptr(nex, idx);
	    if (ivl_nexus_ptr_drive0(ptr) != IVL_DR_HiZ
		|| ivl_nexus_ptr_drive1(ptr) != IVL_DR_HiZ)
		  draw_stage_driver(stage, ptr, base, first, width, &walk);
      }
}

static void draw_stage_driver(const char*stage, ivl_nexus_ptr_t ptr,
			      unsigned base, unsigned first, unsigned width,
			      const struct stage_walk*walk)
{
      ivl_net_logic_t logic = ivl_nexus_ptr_log(ptr);
      ivl_lpm_t lpm = ivl_nexus_ptr_lpm(ptr);
      ivl_net_const_t con = ivl_nexus_ptr_con(ptr);
      struct modpath_assign key = {0, 0, 0};
      if (logic) {
	    key.scope = ivl_logic_scope(logic);
	    key.name = ivl_logic_basename(logic);
      } else if (lpm) {
	    key.scope = ivl_lpm_scope(lpm);
	    key.name = ivl_lpm_basename(lpm);
      } else if (con) {
	    key.scope = ivl_const_scope(con);
	    key.name = ivl_const_basename(con);
      }
      const struct modpath_assign*ca = key.name && nassigns
	    ? bsearch(&key, assigns, nassigns, sizeof(*assigns), compare_assigns)
	    : 0;
      char symbol[64];
      if (ca) {
	    snprintf(symbol, sizeof symbol, "CA_%u", ca->label);
	    draw_stage_conn(stage, base, width, vpiContAssign, symbol, 0);
	    return;
      }
      if (logic && vpi_logic_has_primitive(logic)) {
	    snprintf(symbol, sizeof symbol, "VPI_PRIM_%p", logic);
	    draw_stage_conn(stage, base, width, vpiPrimTerm, symbol,
			    ivl_nexus_ptr_pin(ptr));
	    return;
      }
      if (logic && ivl_logic_port_buffer(logic)) {
	    for (unsigned idx = 0; idx < ivl_scope_mod_module_ports(key.scope); ++idx)
		  if (ivl_scope_mod_module_port_buffer(key.scope, idx) == logic) {
			snprintf(symbol, sizeof symbol, "S_%p", key.scope);
			draw_stage_conn(stage, base, width, vpiPort, symbol, idx);
			return;
		  }
      }

	/* Lvalue wiring may put a part-to-vector adapter or a concatenation
	   between a source object and the stage. Follow its bit mapping. */
      if (logic && (ivl_logic_type(logic) == IVL_LO_BUFZ
		    || ivl_logic_type(logic) == IVL_LO_BUFT)) {
	    draw_stage_input(stage, ivl_logic_pin(logic, 1), base, first, width, walk);
      } else if (lpm && ivl_lpm_type(lpm) == IVL_LPM_PART_PV) {
	    unsigned part_base = ivl_lpm_base(lpm);
	    unsigned lo = first > part_base ? first : part_base;
	    unsigned hi = part_base + ivl_lpm_width(lpm);
	    if (hi > first + width) hi = first + width;
	    if (lo < hi)
		  draw_stage_input(stage, ivl_lpm_data(lpm, 0),
				   base + lo - first, lo - part_base, hi - lo, walk);
      } else if (lpm && ivl_lpm_type(lpm) == IVL_LPM_PART_VP
		 && !ivl_lpm_data(lpm, 1)) {
	    draw_stage_input(stage, ivl_lpm_data(lpm, 0), base,
			     first + ivl_lpm_base(lpm), width, walk);
      } else if (lpm && (ivl_lpm_type(lpm) == IVL_LPM_CONCAT
			 || ivl_lpm_type(lpm) == IVL_LPM_CONCATZ)) {
	    unsigned offset = 0;
	    for (unsigned idx = 0; idx < ivl_lpm_size(lpm) && offset < first + width; ++idx) {
		  ivl_nexus_t input = ivl_lpm_data(lpm, idx);
		  unsigned lo = first > offset ? first : offset;
		  unsigned next = offset + width_of_nexus(input);
		  unsigned hi = next < first + width ? next : first + width;
		  if (lo < hi)
			draw_stage_input(stage, input, base + lo - first,
					 lo - offset, hi - lo, walk);
		  offset = next;
	    }
      }
}

static void draw_modpath_connectivity(const char*stage, const struct modpath_item*item)
{
      ivl_nexus_t nex = ivl_signal_nex(item->path_sig, 0);
      unsigned width = ivl_signal_width(item->path_sig);
      unsigned base = 0, span = width;
      ivl_lpm_t lpm = ivl_nexus_ptr_lpm(item->driver);
      if (lpm && ivl_lpm_type(lpm) == IVL_LPM_PART_PV) {
	    base = ivl_lpm_base(lpm);
	    if (base >= width) return;
	    span = ivl_lpm_width(lpm);
	    if (span > width - base) span = width - base;
      }
      draw_stage_nets(stage, nex, vpiOutTerm, base, span, base);
      struct stage_walk walk = {nex, 0};
      draw_stage_driver(stage, item->driver, base, base, span, &walk);
}

void cleanup_modpath(void)
{
      if (modpath_list && nassigns)
	    qsort(assigns, nassigns, sizeof(*assigns), compare_assigns);
      while (modpath_list) {
	    struct modpath_item*cur = modpath_list;
	    char modpath_label[64];

	    modpath_list = cur->next;

	    snprintf(modpath_label, sizeof modpath_label, "V_%p_%u/m", cur->path_sig, cur->drive_index);
	    draw_modpath_record(modpath_label, cur->drive_label, cur->path_sig);
	    draw_modpath_connectivity(modpath_label, cur);
	    free(cur->drive_label);
	    free(cur);
      }
      free(assigns);
      assigns = 0;
      nassigns = assign_capacity = 0;
}

static void draw_tchk_term(ivl_tchk_t tchk, unsigned term)
{
      ivl_signal_t sig = ivl_tchk_term_sig(tchk, term);
      ivl_signal_t condit = ivl_tchk_term_condit(tchk, term);
      const char*text = ivl_tchk_term_condition_text(tchk, term);
      long bit = 0;
      int has_bit;

      if (sig == 0) {
	    fprintf(vvp_out, "0 0 0 0");
	    return;
      }
      has_bit = ivl_tchk_term_bit(tchk, term, &bit);
      fprintf(vvp_out, "v%p_0 %d %ld %u", sig, has_bit, bit,
	      ivl_tchk_term_edge(tchk, term));
      if (condit || text) {
	    if (condit) fprintf(vvp_out, " ? v%p_0 ", condit);
	    else fprintf(vvp_out, " ? 0 ");
	    draw_quoted_condition(text ? text : "");
      }
}

/*
 * Draw the .tchk records of a scope and its children (IEEE 1800-2023
 * 37.40). They come after every other structural record so that the
 * signal labels they name are all defined.
 */
void draw_tchks(ivl_scope_t scope)
{
      unsigned idx, lim;

      for (idx = 0; idx < ivl_scope_childs(scope); idx += 1)
	    draw_tchks(ivl_scope_child(scope, idx));

      if (ivl_scope_tchks(scope) == 0) return;

      fprintf(vvp_out, "  .scope S_%p;\n", scope);
      for (idx = 0; idx < ivl_scope_tchks(scope); idx += 1) {
	    ivl_tchk_t tchk = ivl_scope_tchk(scope, idx);
	    ivl_signal_t notifier = ivl_tchk_notifier(tchk);

	    fprintf(vvp_out, "TC_%p .tchk %d %u %u, ", tchk, ivl_tchk_type(tchk),
		    ivl_file_table_index(ivl_tchk_file(tchk)),
		    ivl_tchk_lineno(tchk));
	    draw_tchk_term(tchk, 0);
	    fprintf(vvp_out, ", ");
	    draw_tchk_term(tchk, 1);
	    fprintf(vvp_out, ", %u", ivl_tchk_limits(tchk));
	    for (lim = 0; lim < ivl_tchk_limits(tchk); lim += 1) {
		  char*value = draw_Cr_to_string(ivl_tchk_limit(tchk, lim));
		  double shift = ivl_tchk_limit_shift(tchk, lim);
		  fprintf(vvp_out, " v%p_0 %s", ivl_tchk_limit_sig(tchk, lim),
			  value);
		  free(value);
		  if (shift != 0.0) {
			value = draw_Cr_to_string(shift);
			fprintf(vvp_out, " / %s", value);
			free(value);
		  }
	    }
	    if (notifier) fprintf(vvp_out, ", v%p_0;\n", notifier);
	    else fprintf(vvp_out, ", 0;\n");
      }
}

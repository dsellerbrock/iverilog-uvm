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

      return 0;
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

static int signal_has_showcancelled(ivl_signal_t sig)
{
      unsigned idx;
      for (idx = 0; idx < ivl_signal_attr_cnt(sig); idx += 1) {
	    ivl_attribute_t attr = ivl_signal_attr_val(sig, idx);
	    if (strcmp(attr->key, "_ivl_showcancelled") == 0)
		  return attr->type == IVL_ATT_NUM && attr->val.num != 0;
      }
      return 0;
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
	      signal_has_showcancelled(path_sig), driver, path_sig);

      for (idx = 0 ;  idx < ivl_signal_npath(path_sig); idx += 1) {
	    ivl_delaypath_t path = ivl_signal_path(path_sig, idx);
	    int ppos = ivl_path_source_posedge(path);
	    int pneg = ivl_path_source_negedge(path);
	    const char*edge = ppos? " +" : pneg ? " -" : "";
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
      struct modpath_item*next;
};

static struct modpath_item*modpath_list = 0;

void draw_modpath(ivl_signal_t path_sig, char*drive_label, unsigned drive_index)
{
      struct modpath_item*cur = calloc(1, sizeof(struct modpath_item));
      cur->path_sig = path_sig;
      cur->drive_label = drive_label;
      cur->drive_index = drive_index;
      cur->next = modpath_list;
      modpath_list = cur;
}

void cleanup_modpath(void)
{
      while (modpath_list) {
	    struct modpath_item*cur = modpath_list;
	    char modpath_label[64];

	    modpath_list = cur->next;

	    snprintf(modpath_label, sizeof modpath_label, "V_%p_%u/m", cur->path_sig, cur->drive_index);
	    draw_modpath_record(modpath_label, cur->drive_label, cur->path_sig);
	    free(cur->drive_label);
	    free(cur);
      }
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

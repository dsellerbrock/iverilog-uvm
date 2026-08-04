/*
 * Copyright (c) 2001-2014 Stephen Williams (steve@icarus.com)
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

# include  "device.h"
# include  "fpga_priv.h"
# include  "edif.h"
# include  <stdlib.h>
# include  <string.h>
# include  <assert.h>
# include  "ivl_alloc.h"

struct nexus_recall {
      struct nexus_recall*next;
      ivl_nexus_t nex;
      unsigned bit;
      char* joined;
};
static struct nexus_recall*net_list = 0;

static unsigned edif_uref = 0;

static void print_name_definition(const char*name, const char*ename)
{
      if (ename) {
	    fprintf(xnf, "(rename %s ", ename);
	    edif_print_string(xnf, name);
	    fprintf(xnf, ")");
      } else {
	    fprintf(xnf, "%s", name);
      }
}

static void edif_set_nexus_joint_bit(ivl_nexus_t nex, unsigned bit,
				     const char*joint)
{
      size_t newlen;
      struct nexus_recall*rec;

      for (rec = net_list ; rec ; rec = rec->next)
	    if ((rec->nex == nex) && (rec->bit == bit))
		  break;

      if (rec == 0) {
	    rec = malloc(sizeof(struct nexus_recall));
	    rec->nex = nex;
	    rec->bit = bit;
	    rec->joined = malloc(8);
	    rec->joined[0] = 0;
	    rec->next = net_list;
	    net_list = rec;
      }

      newlen = strlen(rec->joined) + strlen(joint) + 2;
      rec->joined = realloc(rec->joined, newlen);
      strcat(rec->joined, " ");
      strcat(rec->joined, joint);
}

static void edif_set_nexus_joint(ivl_nexus_t nex, const char*joint)
{
      edif_set_nexus_joint_bit(nex, 0, joint);
}


static void show_root_ports_edif(ivl_scope_t root)
{
      char jbuf[1024];
      unsigned cnt = ivl_scope_sigs(root);
      unsigned idx;

      for (idx = 0 ;  idx < cnt ;  idx += 1) {
	    ivl_signal_t sig = ivl_scope_sig(root, idx);
	    const char*use_name;
	    const char*use_ref;
	    const char*dir = 0;
	    char ref_buf[32];

	    if (ivl_signal_attr(sig, "PAD") != 0)
		  continue;

	    switch (ivl_signal_port(sig)) {
		case IVL_SIP_NONE:
		  continue;

		case IVL_SIP_INPUT:
		  dir = "INPUT";
		  break;

		case IVL_SIP_OUTPUT:
		  dir = "OUTPUT";
		  break;

		case IVL_SIP_INOUT:
		  dir = "INOUT";
		  break;

		case IVL_SIP_REF:
		  fprintf(stderr, "%s:%u: fpga.tgt error: generic-edif "
			  "cannot represent a ref port.\n",
			  ivl_signal_file(sig), ivl_signal_lineno(sig));
		  fpga_errors += 1;
		  continue;
	    }

	    use_name = ivl_signal_basename(sig);
	    snprintf(ref_buf, sizeof ref_buf, "PORT%u", idx);
	    use_ref = ref_buf;
	    if (ivl_signal_width(sig) == 1) {
		  fprintf(xnf, "            (port ");
		  print_name_definition(use_name, use_ref);
		  fprintf(xnf, " (direction %s))\n", dir);

		  snprintf(jbuf, sizeof jbuf, "(portRef %s)", use_ref);
		  edif_set_nexus_joint_bit(ivl_signal_nex(sig, 0), 0, jbuf);

	    } else {
		  unsigned pin;

		  for (pin = 0 ; pin < ivl_signal_width(sig); pin += 1) {
			char bit_ref[64];
			char*display_name = edif_vector_name(use_name, pin);
			snprintf(bit_ref, sizeof bit_ref, "PORT%u_%u", idx, pin);
			fprintf(xnf, "            (port (rename %s ", bit_ref);
			edif_print_string(xnf, display_name);
			fprintf(xnf, ") (direction %s))\n", dir);
			snprintf(jbuf, sizeof jbuf, "(portRef %s)", bit_ref);
			edif_set_nexus_joint_bit(ivl_signal_nex(sig, 0), pin,
						 jbuf);
			free(display_name);
		  }
	    }
      }
}


static void edif_show_header_generic(ivl_design_t des, const char*library)
{
      ivl_scope_t root = fpga_design_root(des);
      const char*root_name = ivl_scope_name(root);
      const char*root_ename = "TOP";

	/* write the primitive header */
      fprintf(xnf, "(edif ");
      print_name_definition(root_name, root_ename);
      fprintf(xnf, "\n");
      fprintf(xnf, "    (edifVersion 2 0 0)\n");
      fprintf(xnf, "    (edifLevel 0)\n");
      fprintf(xnf, "    (keywordMap (keywordLevel 0))\n");
      fprintf(xnf, "    (status\n");
      fprintf(xnf, "     (written\n");
      fprintf(xnf, "        (timeStamp 0 0 0 0 0 0)\n");
      fprintf(xnf, "        (author \"unknown\")\n");
      fprintf(xnf, "        (program \"Icarus Verilog/fpga.tgt\")))\n");

	/* Write out the external references here? */
      fputs(library, xnf);

	/* Write out the library header */
      fprintf(xnf, "    (library DESIGN\n");
      fprintf(xnf, "      (edifLevel 0)\n");
      fprintf(xnf, "      (technology (numberDefinition))\n");

	/* The root module is a cell in the library. */
      fprintf(xnf, "      (cell ");
      print_name_definition(root_name, root_ename);
      fprintf(xnf, "\n");
      fprintf(xnf, "        (cellType GENERIC)\n");
      fprintf(xnf, "        (view net\n");
      fprintf(xnf, "          (viewType NETLIST)\n");
      fprintf(xnf, "          (interface\n");

      show_root_ports_edif(root);

      fprintf(xnf, "          )\n"); /* end the (interface ) sexp */

      fprintf(xnf, "          (contents\n");
}

static const char*external_library_text =
"    (external VIRTEX (edifLevel 0) (technology (numberDefinition))\n"
"      (cell AND2 (cellType GENERIC)\n"
"            (view net\n"
"              (viewType NETLIST)\n"
"              (interface\n"
"                 (port O (direction OUTPUT))\n"
"                 (port I0 (direction INPUT))\n"
"                 (port I1 (direction INPUT)))))\n"
"      (cell BUF (cellType GENERIC)\n"
"            (view net\n"
"              (viewType NETLIST)\n"
"              (interface\n"
"                 (port O (direction OUTPUT))\n"
"                 (port I (direction INPUT)))))\n"
"      (cell INV (cellType GENERIC)\n"
"            (view net\n"
"              (viewType NETLIST)\n"
"              (interface\n"
"                 (port O (direction OUTPUT))\n"
"                 (port I (direction INPUT)))))\n"
"      (cell FDCE (cellType GENERIC)\n"
"            (view net\n"
"              (viewType NETLIST)\n"
"              (interface\n"
"                 (port Q (direction OUTPUT))\n"
"                 (port D (direction INPUT))\n"
"                 (port C (direction INPUT))\n"
"                 (port CE (direction INPUT))\n"
"                 (port CLR (direction INPUT)))))\n"
"      (cell FDCPE (cellType GENERIC)\n"
"            (view net\n"
"              (viewType NETLIST)\n"
"              (interface\n"
"                 (port Q (direction OUTPUT))\n"
"                 (port D (direction INPUT))\n"
"                 (port C (direction INPUT))\n"
"                 (port CE (direction INPUT))\n"
"                 (port PRE (direction INPUT))\n"
"                 (port CLR (direction INPUT)))))\n"
"      (cell GND (cellType GENERIC)\n"
"            (view net\n"
"              (viewType NETLIST)\n"
"              (interface (port G (direction OUTPUT)))))\n"
"      (cell NOR2 (cellType GENERIC)\n"
"            (view net\n"
"              (viewType NETLIST)\n"
"              (interface\n"
"                 (port O (direction OUTPUT))\n"
"                 (port I0 (direction INPUT))\n"
"                 (port I1 (direction INPUT)))))\n"
"      (cell NOR3 (cellType GENERIC)\n"
"            (view net\n"
"              (viewType NETLIST)\n"
"              (interface\n"
"                 (port O (direction OUTPUT))\n"
"                 (port I0 (direction INPUT))\n"
"                 (port I1 (direction INPUT))\n"
"                 (port I2 (direction INPUT)))))\n"
"      (cell VCC (cellType GENERIC)\n"
"            (view net\n"
"              (viewType NETLIST)\n"
"              (interface (port P (direction OUTPUT)))))\n"
"    )\n"
;

static void edif_show_header(ivl_design_t des)
{
      edif_show_header_generic(des, external_library_text);
}

static void edif_show_consts(ivl_design_t des)
{
      unsigned idx;
      char jbuf[128];

      for (idx = 0 ;  idx < ivl_design_consts(des) ;  idx += 1) {
	    unsigned pin;
	    ivl_net_const_t net = ivl_design_const(des, idx);
	    const char*val = ivl_const_bits(net);

	    for (pin = 0 ; pin < ivl_const_width(net) ; pin += 1) {
		  if (val[pin] == '0' || val[pin] == '1')
			continue;

		  fprintf(stderr, "%s:%u: error: generic-edif cannot "
			  "represent constant bit '%c'.\n",
			  ivl_const_file(net), ivl_const_lineno(net), val[pin]);
		  fpga_errors += 1;
		  break;
	    }
	    if (pin < ivl_const_width(net))
		  continue;

	    for (pin = 0 ;  pin < ivl_const_width(net) ;  pin += 1) {
		  ivl_nexus_t nex = ivl_const_nex(net);
		  const char*name;
		  const char*port;

		  edif_uref += 1;

		  switch (val[pin]) {
		      case '0':
			name = "GND";
			port = "G";
			break;
		      case '1':
			name = "VCC";
			port = "P";
			break;
		      default:
			assert(0);
		  }

		  fprintf(xnf, "(instance U%u "
			  "(viewRef net"
			  " (cellRef %s (libraryRef VIRTEX))))\n",
			  edif_uref, name);

		  sprintf(jbuf, "(portRef %s (instanceRef U%u))",
			  port, edif_uref);
		  edif_set_nexus_joint_bit(nex, pin, jbuf);
	    }
      }

}

static void edif_show_footer(ivl_design_t des)
{
      unsigned nref = 0;
      struct nexus_recall*cur;
      ivl_scope_t root = fpga_design_root(des);
      const char*root_name = ivl_scope_name(root);
      const char*root_ename = "TOP";

      edif_show_consts(des);

      for (cur = net_list ;  cur ;  cur = cur->next) {
	    fprintf(xnf, "(net N%u (joined %s))\n", nref, cur->joined);
	    nref += 1;
      }

      fprintf(xnf, "          )\n"); /* end the (contents ) sexp */
      fprintf(xnf, "        )\n"); /* end the (view ) sexp */
      fprintf(xnf, "      )\n"); /* end the (cell ) sexp */
      fprintf(xnf, "    )\n"); /* end the (library ) sexp */

	/* Make an instance of the defined object */
      fprintf(xnf, "    (design ");
      print_name_definition(root_name, root_ename);
      fprintf(xnf, "\n");
      fprintf(xnf, "      (cellRef %s (libraryRef DESIGN))\n",
		      root_ename? root_ename : root_name);

      if (part)
	    { fprintf(xnf, "      (property PART (string ");
	      edif_print_string(xnf, part);
	      fprintf(xnf, "))\n");
	    }

      fprintf(xnf, "    )\n");

      fprintf(xnf, ")\n"); /* end the (edif  ) sexp */
}

static void edif_show_logic(ivl_net_logic_t net)
{
      char jbuf[1024];
      char cell_name[32];
      unsigned bit, idx;
      unsigned width = ivl_logic_width(net);

      switch (ivl_logic_type(net)) {

	  case IVL_LO_AND:
	    if (ivl_logic_pins(net) != 3) {
		  fprintf(stderr, "%s:%u: error: generic-edif only supports "
			  "two-input AND gates.\n", ivl_logic_file(net),
			  ivl_logic_lineno(net));
		  fpga_errors += 1;
		  return;
	    }
	    snprintf(cell_name, sizeof cell_name, "AND%u",
		     ivl_logic_pins(net) - 1);
	    break;

	  case IVL_LO_BUF:
	    assert(ivl_logic_pins(net) == 2);
	    strcpy(cell_name, "BUF");
	    break;

	  case IVL_LO_NOT:
	    assert(ivl_logic_pins(net) == 2);
	    strcpy(cell_name, "INV");
	    break;

        case IVL_LO_BUFZ:
          {
            assert(ivl_logic_pins(net) == 2);
	    strcpy(cell_name, "BUF");
          }
          break;

	  case IVL_LO_NOR:
	    if (ivl_logic_pins(net) < 3 || ivl_logic_pins(net) > 4) {
		  fprintf(stderr, "%s:%u: error: generic-edif only supports "
			  "two- or three-input NOR gates.\n",
			  ivl_logic_file(net), ivl_logic_lineno(net));
		  fpga_errors += 1;
		  return;
	    }
	    snprintf(cell_name, sizeof cell_name, "NOR%u",
		     ivl_logic_pins(net) - 1);
	    break;

	  case IVL_LO_PULLDOWN:
	  case IVL_LO_PULLUP:
	    assert(ivl_logic_pins(net) == 1);
	    for (bit = 0 ; bit < width ; bit += 1) {
		  edif_uref += 1;
		  fprintf(xnf, "(instance U%u (viewRef net (cellRef %s "
			  "(libraryRef VIRTEX))))\n", edif_uref,
			  ivl_logic_type(net) == IVL_LO_PULLUP
			  ? "VCC" : "GND");
		  sprintf(jbuf, "(portRef %c (instanceRef U%u))",
			  ivl_logic_type(net) == IVL_LO_PULLUP ? 'P' : 'G',
			  edif_uref);
		  edif_set_nexus_joint_bit(ivl_logic_pin(net, 0), bit, jbuf);
	    }
	    return;

	  default:
	    fprintf(stderr, "%s:%u: error: generic-edif does not support "
		    "logic type %d.\n", ivl_logic_file(net),
		    ivl_logic_lineno(net), ivl_logic_type(net));
	    fpga_errors += 1;
	    return;
      }

	/* EDIF primitive cells are scalar, so instantiate one per bit. */
      for (bit = 0 ; bit < width ; bit += 1) {
	    char*display_name;

	    edif_uref += 1;
	    if (width == 1)
		  display_name = strdup(ivl_logic_basename(net));
	    else
		  display_name = edif_vector_name(ivl_logic_basename(net), bit);

	    fprintf(xnf, "(instance (rename U%u ", edif_uref);
	    edif_print_string(xnf, display_name);
	    fprintf(xnf, ")");
	    fprintf(xnf, " (viewRef net (cellRef %s "
		    "(libraryRef VIRTEX))))\n", cell_name);
	    free(display_name);

	    sprintf(jbuf, "(portRef O (instanceRef U%u))", edif_uref);
	    edif_set_nexus_joint_bit(ivl_logic_pin(net, 0), bit, jbuf);

	    for (idx = 1 ; idx < ivl_logic_pins(net) ; idx += 1) {
		  if (ivl_logic_type(net) == IVL_LO_AND ||
		      ivl_logic_type(net) == IVL_LO_NOR)
			sprintf(jbuf, "(portRef I%u (instanceRef U%u))",
				idx-1, edif_uref);
		  else
			sprintf(jbuf, "(portRef I (instanceRef U%u))",
				edif_uref);
		  edif_set_nexus_joint_bit(ivl_logic_pin(net, idx), bit, jbuf);
	    }
      }
}

static int edif_nexus_has_re_nor(ivl_lpm_t owner, ivl_nexus_t nex)
{
      unsigned idx;

      for (idx = 0 ; idx < ivl_nexus_ptrs(nex) ; idx += 1) {
	    ivl_lpm_t lpm = ivl_nexus_ptr_lpm(ivl_nexus_ptr(nex, idx));
	    if (lpm && lpm != owner && ivl_lpm_type(lpm) == IVL_LPM_RE_NOR
		&& ivl_lpm_q(lpm) == nex)
		  return 1;
      }

      return 0;
}

static int edif_validate_generic_dff(ivl_lpm_t net, const char**abits)
{
      ivl_expr_t avalue;
      ivl_nexus_t aclr = ivl_lpm_async_clr(net);
      ivl_nexus_t aset = ivl_lpm_async_set(net);
      unsigned idx;

      *abits = 0;

      if (ivl_lpm_negedge(net)) {
	    fprintf(stderr, "%s:%u: fpga.tgt error: architecture %s only "
		    "supports positive-edge flip-flops.\n",
		    ivl_lpm_file(net), ivl_lpm_lineno(net), arch);
	    fpga_errors += 1;
	    return 0;
      }

      if (ivl_lpm_sync_clr(net) || ivl_lpm_sync_set(net)) {
	    fprintf(stderr, "%s:%u: fpga.tgt error: architecture %s does not "
		    "support synchronous set/clear controls.\n",
		    ivl_lpm_file(net), ivl_lpm_lineno(net), arch);
	    fpga_errors += 1;
	    return 0;
      }

      if (aclr && edif_nexus_has_re_nor(net, aclr)) {
	    fprintf(stderr, "%s:%u: fpga.tgt error: architecture %s does not "
		    "support active-low asynchronous clear controls.\n",
		    ivl_lpm_file(net), ivl_lpm_lineno(net), arch);
	    fpga_errors += 1;
	    return 0;
      }

      if (aset && edif_nexus_has_re_nor(net, aset)) {
	    fprintf(stderr, "%s:%u: fpga.tgt error: architecture %s does not "
		    "support active-low asynchronous set controls.\n",
		    ivl_lpm_file(net), ivl_lpm_lineno(net), arch);
	    fpga_errors += 1;
	    return 0;
      }

      if (aset == 0)
	    return 1;

	/* A null set-value is the API representation of the all-ones
	 * default. Only non-default values have an expression. */
      avalue = ivl_lpm_aset_value(net);
      if (avalue == 0)
	    return 1;

      if (ivl_expr_type(avalue) != IVL_EX_NUMBER
	  || ivl_expr_width(avalue) != ivl_lpm_width(net)) {
	    fprintf(stderr, "%s:%u: fpga.tgt error: architecture %s received "
		    "an invalid asynchronous set value.\n",
		    ivl_lpm_file(net), ivl_lpm_lineno(net), arch);
	    fpga_errors += 1;
	    return 0;
      }

      *abits = ivl_expr_bits(avalue);
      for (idx = 0 ; idx < ivl_lpm_width(net) ; idx += 1) {
	    if ((*abits)[idx] == '0' || (*abits)[idx] == '1')
		  continue;

	    fprintf(stderr, "%s:%u: fpga.tgt error: architecture %s does not "
		    "support asynchronous set values containing X or Z.\n",
		    ivl_lpm_file(net), ivl_lpm_lineno(net), arch);
	    fpga_errors += 1;
	    return 0;
      }

      return 1;
}

static void edif_show_generic_dff(ivl_lpm_t net)
{
      char jbuf[1024];
      unsigned idx;
      ivl_nexus_t aclr = ivl_lpm_async_clr(net);
      ivl_nexus_t aset = ivl_lpm_async_set(net);
      const char*abits = 0;
      const char*fdcell = "FDCE";

      if (!edif_validate_generic_dff(net, &abits))
	    return;

      if (aset != 0)
	    fdcell = "FDCPE";

      for (idx = 0 ;  idx < ivl_lpm_width(net) ;  idx += 1) {
	    ivl_nexus_t nex;
	    const char*scope_name = ivl_scope_name(ivl_lpm_scope(net));
	    const char*lpm_name = ivl_lpm_basename(net);
	    size_t display_size = strlen(scope_name) + strlen(lpm_name) + 32;
	    char*display_name = malloc(display_size);

	    edif_uref += 1;

	    snprintf(display_name, display_size, "%s.%s[%u]", scope_name,
		     lpm_name, idx);
	    fprintf(xnf, "(instance (rename U%u ", edif_uref);
	    edif_print_string(xnf, display_name);
	    fprintf(xnf, ")");
	    fprintf(xnf, " (viewRef net"
		    " (cellRef %s (libraryRef VIRTEX))))\n",
		    fdcell);
	    free(display_name);

	    nex = ivl_lpm_q(net);
	    sprintf(jbuf, "(portRef Q (instanceRef U%u))", edif_uref);
	    edif_set_nexus_joint_bit(nex, idx, jbuf);

	    nex = ivl_lpm_data(net, 0);
	    sprintf(jbuf, "(portRef D (instanceRef U%u))", edif_uref);
	    edif_set_nexus_joint_bit(nex, idx, jbuf);

	    nex = ivl_lpm_clk(net);
	    sprintf(jbuf, "(portRef C (instanceRef U%u))", edif_uref);
	    edif_set_nexus_joint(nex, jbuf);

	    if ((nex = ivl_lpm_enable(net))) {
		  sprintf(jbuf, "(portRef CE (instanceRef U%u))", edif_uref);
		  edif_set_nexus_joint(nex, jbuf);
	    }

	    if (aclr) {
		  sprintf(jbuf, "(portRef CLR (instanceRef U%u))", edif_uref);
		  edif_set_nexus_joint(aclr, jbuf);
	    }


	    if (aset) {
	       if (abits == 0 || abits[idx] == '1') {
		     sprintf(jbuf, "(portRef PRE (instanceRef U%u))",
			     edif_uref);
		     edif_set_nexus_joint(aset, jbuf);
	       } else {
		     assert(aclr == 0);
		     sprintf(jbuf, "(portRef CLR (instanceRef U%u))",
			     edif_uref);
		     edif_set_nexus_joint(aset, jbuf);
	       }
	    }
      }
}


const struct device_s d_generic_edif = {
      edif_show_header,
      edif_show_footer,
      0, /* show_cell_scope not implemented. */
      0, /* draw_pad not implemented */
      edif_show_logic,
      edif_show_generic_dff,
      0, /* show_cmp_eq */
      0, /* show_cmp_ne */
      0, /* show_cmp_ge */
      0, /* show_cmp_gt */
      0,
      0, /* show_add */
      0, /* show_sub */
      0, /* show_shiftl */
      0, /* show_shiftr */
      0, /* show_mult */
      0  /* show_constant */
};

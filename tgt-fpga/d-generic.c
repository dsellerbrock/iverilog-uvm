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
# include  <assert.h>
# include  <stdlib.h>
# include  <string.h>

static void xnf_print_nexus_bit(ivl_nexus_t nex, unsigned bit, unsigned width)
{
      const char*base = xnf_mangle_nexus_name(nex);

      fputs(base, xnf);
      if (width > 1)
	    fprintf(xnf, "[%u]", bit);
}

static void xnf_draw_pin_bit(ivl_nexus_t nex, unsigned bit, unsigned width,
			     const char*nam, char dir)
{
      const char*use_name = nam;
      int invert = 0;

      if (use_name[0] == '~') {
	    invert = 1;
	    use_name += 1;
      }

      fprintf(xnf, "    PIN, %s, %c, ", use_name, dir);
      xnf_print_nexus_bit(nex, bit, width);

      if (invert)
	    fprintf(xnf, ",,INV");

      fprintf(xnf, "\n");
}

/*
 * This is the device emitter for the most generic FPGA. It doesn't
 * know anything special about device types, so can't handle complex
 * logic.
 */

static void xnf_draw_pin(ivl_nexus_t nex, const char*nam, char dir)
{
      const char*use_name = nam;
      const char*nex_name = xnf_mangle_nexus_name(nex);
      int invert = 0;

      if (use_name[0] == '~') {
	    invert = 1;
	    use_name += 1;
      }

      fprintf(xnf, "    PIN, %s, %c, %s", use_name, dir, nex_name);

      if (invert)
	    fprintf(xnf, ",,INV");

      fprintf(xnf, "\n");
}

static void show_root_ports_xnf(ivl_scope_t root)
{
      unsigned cnt = ivl_scope_sigs(root);
      unsigned idx;

      for (idx = 0 ;  idx < cnt ;  idx += 1) {
	    ivl_signal_t sig = ivl_scope_sig(root, idx);
	    char*use_name;

	    if (ivl_signal_port(sig) == IVL_SIP_NONE)
		  continue;

	    use_name = xnf_mangle_identifier(ivl_signal_basename(sig));
	    if (ivl_signal_width(sig) == 1) {
		  ivl_nexus_t nex = ivl_signal_nex(sig, 0);
		  fprintf(xnf, "SIG, %s, PIN=%s\n",
			  xnf_mangle_nexus_name(nex), use_name);

	    } else {
		  unsigned pin;

		  for (pin = 0 ; pin < ivl_signal_width(sig); pin += 1) {
			ivl_nexus_t nex = ivl_signal_nex(sig, 0);
			fputs("SIG, ", xnf);
			xnf_print_nexus_bit(nex, pin, ivl_signal_width(sig));
			fprintf(xnf, ", PIN=%s%u\n", use_name, pin);
		  }
	    }
	    free(use_name);
      }
}

static void show_design_consts_xnf(ivl_design_t des)
{
      unsigned idx;

      for (idx = 0 ;  idx < ivl_design_consts(des) ;  idx += 1) {
	    unsigned pin;
	    ivl_net_const_t net = ivl_design_const(des, idx);
	    const char*val = ivl_const_bits(net);

	    for (pin = 0 ; pin < ivl_const_width(net) ; pin += 1) {
		  if (val[pin] == '0' || val[pin] == '1')
			continue;

		  fprintf(stderr, "%s:%u: error: generic-xnf cannot "
			  "represent constant bit '%c'.\n",
			  ivl_const_file(net), ivl_const_lineno(net), val[pin]);
		  fpga_errors += 1;
		  break;
	    }
	    if (pin < ivl_const_width(net))
		  continue;

	    for (pin = 0 ;  pin < ivl_const_width(net) ;  pin += 1) {
		  ivl_nexus_t nex = ivl_const_nex(net);
		  fprintf(xnf, "PWR,%c,", val[pin]);
		  xnf_print_nexus_bit(nex, pin, ivl_const_width(net));
		  fputc('\n', xnf);
	    }
      }
}

static void generic_show_header(ivl_design_t des)
{
      ivl_scope_t root = fpga_design_root(des);

      fprintf(xnf, "LCANET,6\n");
      fprintf(xnf, "PROG,iverilog,$Name:  $,\"Icarus Verilog/fpga.tgt\"\n");

      if (part && (part[0]!=0)) {
	    fprintf(xnf, "PART,%s\n", part);
      }

      show_root_ports_xnf(root);
}

static void generic_show_footer(ivl_design_t des)
{
      show_design_consts_xnf(des);
      fprintf(xnf, "EOF\n");
}


static void generic_show_logic(ivl_net_logic_t net)
{
      char*name;
      const char*cell = 0;
      unsigned bit, idx;
      unsigned width = ivl_logic_width(net);

      switch (ivl_logic_type(net)) {

	  case IVL_LO_AND:
	    cell = "AND";
	    break;

	  case IVL_LO_BUF:
	    assert(ivl_logic_pins(net) == 2);
	    cell = "BUF";
	    break;

	  case IVL_LO_NAND:
	    cell = "NAND";
	    break;

	  case IVL_LO_NOR:
	    cell = "NOR";
	    break;

	  case IVL_LO_NOT:
	    assert(ivl_logic_pins(net) == 2);
	    cell = "INV";
	    break;

	  case IVL_LO_OR:
	    cell = "OR";
	    break;

	  case IVL_LO_XOR:
	    cell = "XOR";
	    break;

	  case IVL_LO_XNOR:
	    cell = "XNOR";
	    break;

	  case IVL_LO_PULLDOWN:
	  case IVL_LO_PULLUP:
	    assert(ivl_logic_pins(net) == 1);
	    for (bit = 0 ; bit < width ; bit += 1) {
		  fprintf(xnf, "PWR,%c,",
			  ivl_logic_type(net) == IVL_LO_PULLUP ? '1' : '0');
		  xnf_print_nexus_bit(ivl_logic_pin(net, 0), bit, width);
		  fputc('\n', xnf);
	    }
	    return;

	  case IVL_LO_BUFIF0:
	    assert(ivl_logic_pins(net) == 3);
	    cell = "TBUF";
	    break;

	  case IVL_LO_BUFIF1:
	    assert(ivl_logic_pins(net) == 3);
	    cell = "TBUF";
	    break;

	  default:
	    fprintf(stderr, "%s:%u: error: generic-xnf does not support "
		    "logic type %d.\n", ivl_logic_file(net),
		    ivl_logic_lineno(net), ivl_logic_type(net));
	    fpga_errors += 1;
	    return;
      }

      name = xnf_mangle_logic_name(net);

	/* ivl_logic_width applies to every pin of a logic primitive. */
      for (bit = 0 ; bit < width ; bit += 1) {
	    fprintf(xnf, "SYM, %s", name);
	    if (width > 1)
		  fprintf(xnf, "[%u]", bit);
	    fprintf(xnf, ", %s, LIBVER=2.0.0\n", cell);
	    xnf_draw_pin_bit(ivl_logic_pin(net, 0), bit, width, "O", 'O');

	    for (idx = 1 ; idx < ivl_logic_pins(net) ; idx += 1) {
		  char ipin[32];

		  if (ivl_logic_type(net) == IVL_LO_BUF ||
		      ivl_logic_type(net) == IVL_LO_NOT)
			strcpy(ipin, "I");
		  else if (ivl_logic_type(net) == IVL_LO_BUFIF0)
			strcpy(ipin, idx == 1 ? "I" : "~T");
		  else if (ivl_logic_type(net) == IVL_LO_BUFIF1)
			strcpy(ipin, idx == 1 ? "I" : "T");
		  else
			sprintf(ipin, "I%u", idx-1);

		  xnf_draw_pin_bit(ivl_logic_pin(net, idx), bit, width,
				   ipin, 'I');
	    }
	    fprintf(xnf, "END\n");
      }
      free(name);
}

static void generic_show_dff(ivl_lpm_t net)
{
      char*name;
      ivl_nexus_t nex;
      unsigned idx;
      unsigned width = ivl_lpm_width(net);

      if (ivl_lpm_negedge(net)) {
	    fprintf(stderr, "%s:%u: fpga.tgt error: architecture %s only "
		    "supports positive-edge flip-flops.\n",
		    ivl_lpm_file(net), ivl_lpm_lineno(net), arch);
	    fpga_errors += 1;
	    return;
      }

      name = xnf_mangle_lpm_name(net);

      for (idx = 0 ; idx < width ; idx += 1) {
	    if (width == 1)
		  fprintf(xnf, "SYM, %s, DFF, LIBVER=2.0.0\n", name);
	    else
		  fprintf(xnf, "SYM, %s/FF%u, DFF, LIBVER=2.0.0\n",
			  name, idx);

	    nex = ivl_lpm_q(net);
	    xnf_draw_pin_bit(nex, idx, width, "Q", 'O');

	    nex = ivl_lpm_data(net, 0);
	    xnf_draw_pin_bit(nex, idx, width, "D", 'I');

	    nex = ivl_lpm_clk(net);
	    xnf_draw_pin(nex, "C", 'I');

	    if ((nex = ivl_lpm_enable(net)))
		  xnf_draw_pin(nex, "CE", 'I');

	    fprintf(xnf, "END\n");
      }
      free(name);
}

/*
 * The generic == comparator uses EQN records to generate 2-bit
 * comparators, that are then connected together by a wide AND gate.
 */
static void generic_show_cmp_eq(ivl_lpm_t net)
{
      ivl_nexus_t nex;
      unsigned idx;
      char*name;
	/* Make this many dual pair comparators, and */
      unsigned deqn = ivl_lpm_width(net) / 2;
	/* Make this many single pair comparators. */
      unsigned seqn = ivl_lpm_width(net) % 2;

      name = xnf_mangle_lpm_name(net);

      for (idx = 0 ;  idx < deqn ;  idx += 1) {
	    fprintf(xnf, "SYM, %s/CD%u, EQN, "
		    "EQN=(~((I0 @ I1) + (I2 @ I3)))\n",
		    name, idx);

	    fprintf(xnf, "    PIN, O, O, %s/CDO%u\n", name, idx);

	    nex = ivl_lpm_data(net, 0);
	    xnf_draw_pin_bit(nex, 2*idx, ivl_lpm_width(net), "I0", 'I');
	    nex = ivl_lpm_data(net, 1);
	    xnf_draw_pin_bit(nex, 2*idx, ivl_lpm_width(net), "I1", 'I');

	    nex = ivl_lpm_data(net, 0);
	    xnf_draw_pin_bit(nex, 2*idx+1, ivl_lpm_width(net), "I2", 'I');
	    nex = ivl_lpm_data(net, 1);
	    xnf_draw_pin_bit(nex, 2*idx+1, ivl_lpm_width(net), "I3", 'I');

	    fprintf(xnf, "END\n");
      }

      if (seqn != 0) {
	    fprintf(xnf, "SYM, %s/CT, XNOR, LIBVER=2.0.0\n", name);

	    fprintf(xnf, "    PIN, O, O, %s/CTO\n", name);

	    nex = ivl_lpm_data(net, 0);
	    xnf_draw_pin_bit(nex, 2*deqn, ivl_lpm_width(net), "I0", 'I');

	    nex = ivl_lpm_data(net, 1);
	    xnf_draw_pin_bit(nex, 2*deqn, ivl_lpm_width(net), "I1", 'I');

	    fprintf(xnf, "END\n");
      }

      if (ivl_lpm_type(net) == IVL_LPM_CMP_EQ)
	    fprintf(xnf, "SYM, %s/OUT, AND, LIBVER=2.0.0\n", name);
      else
	    fprintf(xnf, "SYM, %s/OUT, NAND, LIBVER=2.0.0\n", name);

      nex = ivl_lpm_q(net);
      xnf_draw_pin(nex, "O", 'O');

      for (idx = 0 ;  idx < deqn ;  idx += 1)
	    fprintf(xnf, "    PIN, I%u, I, %s/CDO%u\n", idx, name, idx);

      for (idx = 0 ;  idx < seqn ;  idx += 1)
	    fprintf(xnf, "    PIN, I%u, I, %s/CTO\n", deqn+idx, name);

      fprintf(xnf, "END\n");
      free(name);
}

/*
 * This function draws N-bit wide binary mux devices. These are so
 * very popular because they are the result of such expressions as:
 *
 *        x = sel? a : b;
 *
 * This code only supports the case where sel is a single bit. It
 * works by drawing for each bit of the width an EQN device that takes
 * as inputs I0 and I1 the alternative inputs, and I2 the select. The
 * select bit is common with all the generated mux devices.
 */
static void generic_show_mux(ivl_lpm_t net)
{
      char*name;
      ivl_nexus_t sel;
      unsigned idx;

	/* Access the single select bit. This is common to the whole
	   width of the mux. */
      if (ivl_lpm_selects(net) != 1) {
	    fprintf(stderr, "%s:%u: error: generic-xnf does not support "
		    "muxes with %u select bits.\n", ivl_lpm_file(net),
		    ivl_lpm_lineno(net), ivl_lpm_selects(net));
	    fpga_errors += 1;
	    return;
      }
      name = xnf_mangle_lpm_name(net);
      sel = ivl_lpm_select(net);

      for (idx = 0 ;  idx < ivl_lpm_width(net) ;  idx += 1) {
	    ivl_nexus_t nex;

	    fprintf(xnf, "SYM, %s/M%u, EQN, "
		    "EQN=((I0 * ~I2) + (I1 * I2))\n",
		    name, idx);

	    nex = ivl_lpm_q(net);
	    xnf_draw_pin_bit(nex, idx, ivl_lpm_width(net), "O", 'O');

	    nex = ivl_lpm_data(net, 0);
	    xnf_draw_pin_bit(nex, idx, ivl_lpm_width(net), "I0", 'I');

	    nex = ivl_lpm_data(net, 1);
	    xnf_draw_pin_bit(nex, idx, ivl_lpm_width(net), "I1", 'I');

	    xnf_draw_pin(sel, "I2", 'I');

	    fprintf(xnf, "END\n");
      }
      free(name);
}

/*
 * This code cheats and just generates ADD4 devices enough to support
 * the add. Make no effort to optimize, because we have no idea what
 * kind of device we have.
 */
static void generic_show_add(ivl_lpm_t net)
{
      char*name;
      ivl_nexus_t nex;
      unsigned idx, nadd4, tail;

      name = xnf_mangle_lpm_name(net);

	/* Make this many ADD4 devices. */
      nadd4 = ivl_lpm_width(net) / 4;
      tail  = ivl_lpm_width(net) % 4;

      for (idx = 0 ;  idx < nadd4 ;  idx += 1) {
	    fprintf(xnf, "SYM, %s/A%u, ADD4\n", name, idx);

	    if (idx > 0)
		  fprintf(xnf, "    PIN, CI, I, %s/CO%u\n", name, idx-1);

	    nex = ivl_lpm_q(net);
	    xnf_draw_pin_bit(nex, idx*4+0, ivl_lpm_width(net), "S0", 'O');

	    nex = ivl_lpm_q(net);
	    xnf_draw_pin_bit(nex, idx*4+1, ivl_lpm_width(net), "S1", 'O');

	    nex = ivl_lpm_q(net);
	    xnf_draw_pin_bit(nex, idx*4+2, ivl_lpm_width(net), "S2", 'O');

	    nex = ivl_lpm_q(net);
	    xnf_draw_pin_bit(nex, idx*4+3, ivl_lpm_width(net), "S3", 'O');

	    nex = ivl_lpm_data(net, 0);
	    xnf_draw_pin_bit(nex, idx*4+0, ivl_lpm_width(net), "A0", 'I');

	    nex = ivl_lpm_data(net, 0);
	    xnf_draw_pin_bit(nex, idx*4+1, ivl_lpm_width(net), "A1", 'I');

	    nex = ivl_lpm_data(net, 0);
	    xnf_draw_pin_bit(nex, idx*4+2, ivl_lpm_width(net), "A2", 'I');

	    nex = ivl_lpm_data(net, 0);
	    xnf_draw_pin_bit(nex, idx*4+3, ivl_lpm_width(net), "A3", 'I');

	    nex = ivl_lpm_data(net, 1);
	    xnf_draw_pin_bit(nex, idx*4+0, ivl_lpm_width(net), "B0", 'I');

	    nex = ivl_lpm_data(net, 1);
	    xnf_draw_pin_bit(nex, idx*4+1, ivl_lpm_width(net), "B1", 'I');

	    nex = ivl_lpm_data(net, 1);
	    xnf_draw_pin_bit(nex, idx*4+2, ivl_lpm_width(net), "B2", 'I');

	    nex = ivl_lpm_data(net, 1);
	    xnf_draw_pin_bit(nex, idx*4+3, ivl_lpm_width(net), "B3", 'I');

	    if ((idx*4+4) < ivl_lpm_width(net))
		  fprintf(xnf, "    PIN, CO, O, %s/CO%u\n", name, idx);

	    fprintf(xnf, "END\n");
      }

      if (tail > 0) {
	    fprintf(xnf, "SYM, %s/A%u, ADD4\n", name, nadd4);
	    if (nadd4 > 0)
		  fprintf(xnf, "    PIN, CI, I, %s/CO%u\n", name, nadd4-1);

	    switch (tail) {
		case 3:
		  nex = ivl_lpm_data(net, 0);
		  xnf_draw_pin_bit(nex, nadd4*4+2, ivl_lpm_width(net), "A2", 'I');

		  nex = ivl_lpm_data(net, 1);
		  xnf_draw_pin_bit(nex, nadd4*4+2, ivl_lpm_width(net), "B2", 'I');

		  nex = ivl_lpm_q(net);
		  xnf_draw_pin_bit(nex, nadd4*4+2, ivl_lpm_width(net), "S2", 'O');
		case 2:
		  nex = ivl_lpm_data(net, 0);
		  xnf_draw_pin_bit(nex, nadd4*4+1, ivl_lpm_width(net), "A1", 'I');

		  nex = ivl_lpm_data(net, 1);
		  xnf_draw_pin_bit(nex, nadd4*4+1, ivl_lpm_width(net), "B1", 'I');

		  nex = ivl_lpm_q(net);
		  xnf_draw_pin_bit(nex, nadd4*4+1, ivl_lpm_width(net), "S1", 'O');
		case 1:
		  nex = ivl_lpm_data(net, 0);
		  xnf_draw_pin_bit(nex, nadd4*4+0, ivl_lpm_width(net), "A0", 'I');

		  nex = ivl_lpm_data(net, 1);
		  xnf_draw_pin_bit(nex, nadd4*4+0, ivl_lpm_width(net), "B0", 'I');

		  nex = ivl_lpm_q(net);
		  xnf_draw_pin_bit(nex, nadd4*4+0, ivl_lpm_width(net), "S0", 'O');
	    }

	    fprintf(xnf, "END\n");
      }
      free(name);
}

const struct device_s d_generic = {
      generic_show_header,
      generic_show_footer,
      0, /* show_scope */
      0, /* show_pad not implemented */
      generic_show_logic,
      generic_show_dff,
      generic_show_cmp_eq,
      generic_show_cmp_eq,
      0, /* ge not implemented */
      0, /* gt not implemented */
      generic_show_mux,
      generic_show_add,
      0, /* subtract not implemented */
      0,
      0,
      0, /* multiply not implemented */
      0  /* constant hook not implemented */
};

/*
 * Copyright (c) 2000-2026 Stephen Williams (steve@icarus.com)
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

# include "config.h"

# include  "ivl_target.h"
# include  <stdio.h>
# include  <assert.h>
# include  "priv.h"

/*
 * The fit_registers function scans all the scopes for flip-flop
 * devices to be assigned to macrocells. First look to see if the
 * device is connected to a PAD directly or through a bufif device. If
 * not, then just pick a free macrocell and drop it there.
 */

static int scan_ff_q(ivl_lpm_t ff, unsigned q);

static int nexus_is_constant_one(ivl_nexus_t nex)
{
      unsigned drivers = 0;
      unsigned idx;

      for (idx = 0 ; idx < ivl_nexus_ptrs(nex) ; idx += 1) {
	    ivl_nexus_ptr_t ptr = ivl_nexus_ptr(nex, idx);
	    ivl_net_const_t con;
	    ivl_net_logic_t log;

	    if ((ivl_nexus_ptr_drive0(ptr) == IVL_DR_HiZ) &&
	        (ivl_nexus_ptr_drive1(ptr) == IVL_DR_HiZ))
		  continue;

	    drivers += 1;
	    con = ivl_nexus_ptr_con(ptr);
	    if (con) {
		  const char*bits = ivl_const_bits(con);
		  if ((ivl_const_width(con) == 1) && bits && (bits[0] == '1'))
			continue;
		  return 0;
	    }

	    log = ivl_nexus_ptr_log(ptr);
	    if (log && (ivl_logic_type(log) == IVL_LO_PULLUP))
		  continue;

	    return 0;
      }

      return drivers != 0;
}

static int nexus_has_lpm_driver(ivl_nexus_t nex, ivl_lpm_type_t type)
{
      unsigned idx;

      for (idx = 0 ; idx < ivl_nexus_ptrs(nex) ; idx += 1) {
	    ivl_nexus_ptr_t ptr = ivl_nexus_ptr(nex, idx);
	    ivl_lpm_t lpm;

	    if ((ivl_nexus_ptr_drive0(ptr) == IVL_DR_HiZ) &&
	        (ivl_nexus_ptr_drive1(ptr) == IVL_DR_HiZ))
		  continue;

	    lpm = ivl_nexus_ptr_lpm(ptr);
	    if (lpm && (ivl_lpm_type(lpm) == type))
		  return 1;
      }

      return 0;
}

int fit_registers(ivl_scope_t scope, void*x)
{
      int rc;
      unsigned idx;
      unsigned lpms;

	/* Scan child scopes first... */
      rc = ivl_scope_children(scope, fit_registers, 0);
      if (rc != 0)
	    return rc;


	/* Scan the current scope for flip-flop devices. Pass the
	   devices we find to the scan_ff_q function to assign to a
	   macrocell. */

      lpms = ivl_scope_lpms(scope);
      for (idx = 0 ;  idx < lpms ;  idx += 1) {
	    ivl_lpm_t lpm = ivl_scope_lpm(scope, idx);
	    ivl_nexus_t async_clr, async_set;
	    unsigned wid, q;

	    if (ivl_lpm_type(lpm) != IVL_LPM_FF)
		  continue;

	    wid = ivl_lpm_width(lpm);
	    if (wid != 1) {
		  fprintf(stderr, "%s:%u: error: PAL target does not "
		                  "support vector flip-flops; only width 1 "
		                  "is supported.\n",
		                  ivl_lpm_file(lpm), ivl_lpm_lineno(lpm));
		  pal_errors += 1;
		  continue;
	    }

	    async_clr = ivl_lpm_async_clr(lpm);
	    async_set = ivl_lpm_async_set(lpm);
	    if (async_clr || async_set) {
		  const char*control = async_clr && async_set
		        ? "both asynchronous clear and asynchronous set"
		        : async_clr ? "asynchronous clear" : "asynchronous set";
		  fprintf(stderr, "%s:%u: error: PAL target does not "
		                  "support flip-flops with %s.\n",
		                  ivl_lpm_file(lpm), ivl_lpm_lineno(lpm),
		                  control);
		  pal_errors += 1;
		  continue;
	    }

	    if (ivl_lpm_negedge(lpm)) {
		  fprintf(stderr, "%s:%u: error: PAL target does not "
		                  "support negative-edge-triggered "
		                  "flip-flops.\n",
		                  ivl_lpm_file(lpm), ivl_lpm_lineno(lpm));
		  pal_errors += 1;
		  continue;
	    }

	    if (ivl_lpm_enable(lpm) &&
	        !nexus_is_constant_one(ivl_lpm_enable(lpm))) {
		  fprintf(stderr, "%s:%u: error: PAL target does not "
		                  "support flip-flops with a nonconstant "
		                  "clock enable.\n",
		                  ivl_lpm_file(lpm), ivl_lpm_lineno(lpm));
		  pal_errors += 1;
		  continue;
	    }

	    if (ivl_lpm_sync_clr(lpm) || ivl_lpm_sync_set(lpm)) {
		  fprintf(stderr, "%s:%u: error: PAL target does not "
		                  "support flip-flops with synchronous "
		                  "set/clear controls.\n",
		                  ivl_lpm_file(lpm), ivl_lpm_lineno(lpm));
		  pal_errors += 1;
		  continue;
	    }

	      /* Synchronous set/clear currently lowers to a mux on D rather
	       * than the dedicated FF control pins. The PAL fitter cannot
	       * express that mux, so reject it before it is silently dropped. */
	    if (nexus_has_lpm_driver(ivl_lpm_data(lpm, 0), IVL_LPM_MUX)) {
		  fprintf(stderr, "%s:%u: error: PAL target does not "
		                  "support flip-flops with multiplexed data "
		                  "(including synchronous set/clear).\n",
		                  ivl_lpm_file(lpm), ivl_lpm_lineno(lpm));
		  pal_errors += 1;
		  continue;
	    }

	    for (q = 0 ;  q < wid ;  q += 1) {
		  rc = scan_ff_q(lpm, q);
		  assert(rc == 0);
	    }
      }

      return 0;
}

/*
 * This is the part that actually assigns the single bit of a single
 * flip-flop to a single macrocell.
 */
int scan_ff_q(ivl_lpm_t ff, unsigned q)
{
      unsigned idx;
      ivl_nexus_t nex;

      nex = ivl_lpm_q(ff);

	/* First, look to see if the Q is already connected to a pin
	   or an enable. If I find such a connection, then immediately
	   finish. */

      for (idx = 0 ; idx < pins ;  idx += 1) {
	    struct pal_bind_s*pin = bind_pin + idx;

	    if (pin->sop == 0)
		  continue;

	    if (pin->enable) {

		  if (nex == ivl_logic_pin(pin->enable, 1)) {
			pin->reg = ff;
			pin->reg_q = q;
			return 0;
		  }

	    } else if (pin->nexus == nex) {

		  pin->reg = ff;
		  pin->reg_q = q;
		  return 0;
	    }
      }

	/* There is no pin connection, so try setting this to an
	   unbound sop cell. We know that a sop is unbound if there
	   are no enables, nexus or ff devices connected to it. */

      for (idx = 0 ;  idx < pins ;  idx += 1) {
	    struct pal_bind_s*pin = bind_pin + idx;

	    if (pin->sop == 0)
		  continue;

	    if (pin->enable || pin->nexus || pin->reg)
		  continue;

	      /* Found one. Put the reg here. Leave the nexus empty so
		 that the code generator knows to disable the pin. */
	    pin->reg = ff;
	    pin->reg_q = q;
	    return 0;
      }

      fprintf(stderr, "No room for this ff.\n");
      pal_errors += 1;
      return 0;
}

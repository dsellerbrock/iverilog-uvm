/*
 * Copyright (c) 2002-2021 Stephen Williams (steve@icarus.com)
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

# include <iostream>

# include  <cassert>
# include  <typeinfo>
# include  "netlist.h"
# include  "netmisc.h"

using namespace std;

void NetProc::nex_output(NexusSet&)
{
      cerr << get_fileline()
	   << ": internal error: NetProc::nex_output not implemented"
	   << endl;
      cerr << get_fileline()
	   << ":               : on object type " << typeid(*this).name()
	   << endl;
}

void NetAlloc::nex_output(NexusSet&)
{
}

/*
 * Off by default: NetAssign_::nex_output() claims the whole signal for a
 * bit/part-select l-value, which is what synthesis expects. Only the
 * always_comb sensitivity subtraction in NetBlock::nex_input() turns it
 * on, and only around its own walk.
 */
bool nex_output_precise_partsel = false;

void NetAssign_::nex_output(NexusSet&out)
{
      assert(! nest_);
      assert(sig_);
      unsigned use_word = 0;
      unsigned use_base = 0;
      unsigned use_wid = lwidth();
      if (word_) {
	    long tmp = 0;
	    if (eval_as_long(tmp, word_)) {
		    // A constant word select, so add the selected word.
		  use_word = tmp;
	    } else {
		    // For always_comb sensitivity subtraction, claiming the
		    // whole array could remove words that the block only reads.
		    // Synthesis, however, needs every possible word in the output
		    // map before it unrolls a loop and contextually evaluates the
		    // word expression. Keep the precise walk conservative and
		    // expose all words to the default synthesis walk.
		  if (!nex_output_precise_partsel) {
			for (unsigned idx = 0; idx < sig_->pin_count(); idx += 1) {
			      Nexus*word_nex = sig_->pin(idx).nexus();
			      out.add(word_nex, 0, word_nex->vector_width());
			}
		  }
		  return;
	    }
      }
      Nexus*nex = sig_->pin(use_word).nexus();
      if (base_) {

	      // Unable to evaluate the bit/part select of
	      // the l-value, so this is a mux. Pretty
	      // sure I don't know how to handle this yet
	      // in synthesis, so punt for now.

	      // By DEFAULT a bit/part select still claims the entire
	      // signal as an output. Synthesis depends on that: it reads
	      // this set to decide what a process drives, and narrowing
	      // it leaves bits undriven (ivtest if_part_no_else,
	      // inside_synth, multireg, br_gh99x all regress).
	      //
	      // The one caller that needs precision is the always_comb
	      // sensitivity subtraction in NetBlock::nex_input(): it
	      // removes the block's outputs from its inputs, so claiming
	      // all of `st' there removes bits the block only READS.
	      //
	      //     always_comb begin
	      //       tmp   = st[0] ^ 8'h0F;   // reads st (widened)
	      //       st[1] = tmp + 8'd1;      // claimed ALL of st
	      //     end
	      //
	      // left the process with an EMPTY sensitivity set, so it ran
	      // once at time 0 and simulated a stale value thereafter.
	      // That caller turns the flag on around its own walk.
	      //
	      // Even then, only a CONSTANT base is narrowed: a run-time base
	      // can land anywhere. Clamp a constant select to the bits that
	      // actually overlap the signal; a completely out-of-range write
	      // contributes no output bits.
	    bool narrow = false;
	    if (nex_output_precise_partsel) {
		  const NetEConst*base_c = dynamic_cast<const NetEConst*>(base_);
		  if (base_c && base_c->value().is_defined()) {
			long off = base_c->value().as_long();
			long end = off + use_wid;
			long overlap_base = std::max(off, 0L);
			long overlap_end = std::min(
			      end, static_cast<long>(nex->vector_width()));
			if (overlap_end <= overlap_base)
			      return;
			use_base = static_cast<unsigned>(overlap_base);
			use_wid = static_cast<unsigned>(overlap_end
						    - overlap_base);
			narrow = true;
		  }
	    }
	    if (!narrow) {
		  use_base = 0;
		  use_wid = nex->vector_width();
	    }
      }
      out.add(nex, use_base, use_wid);
}

/*
 * Assignments have as output all the bits of the concatenated signals
 * of the l-value.
 */
void NetAssignBase::nex_output(NexusSet&out)
{
      for (NetAssign_*cur = lval_ ;  cur ;  cur = cur->more) {
	    cur->nex_output(out);
      }
}

void NetBlock::nex_output(NexusSet&out)
{
      if (last_ == 0) return;

      NetProc*cur = last_;
      do {
	    cur = cur->next_;
	    cur->nex_output(out);
      } while (cur != last_);
}

void NetBreak::nex_output(NexusSet&)
{
}

void NetContinue::nex_output(NexusSet&)
{
}

void NetCase::nex_output(NexusSet&out)
{
      for (size_t idx = 0 ;  idx < items_.size() ;  idx += 1) {

	      // Empty statements clearly have no output.
	    if (items_[idx].statement == 0) continue;

	    items_[idx].statement->nex_output(out);
      }

}

void NetCondit::nex_output(NexusSet&out)
{
      if (if_) if_->nex_output(out);
      if (else_) else_->nex_output(out);
}

void NetDisable::nex_output(NexusSet&)
{
}

void NetDoWhile::nex_output(NexusSet&out)
{
      if (proc_) proc_->nex_output(out);
}

void NetEvTrig::nex_output(NexusSet&)
{
}

void NetEvNBTrig::nex_output(NexusSet&)
{
}

void NetEvWait::nex_output(NexusSet&out)
{
      if (statement_) statement_->nex_output(out);
}

void NetForever::nex_output(NexusSet&out)
{
      if (statement_) statement_->nex_output(out);
}

void NetForLoop::nex_output(NexusSet&out)
{
      if (statement_) statement_->nex_output(out);
}

void NetFree::nex_output(NexusSet&)
{
}

void NetPDelay::nex_output(NexusSet&out)
{
      if (statement_) statement_->nex_output(out);
}

void NetRepeat::nex_output(NexusSet&out)
{
      if (statement_) statement_->nex_output(out);
}

/*
 * For the purposes of synthesis, system task calls have no output at
 * all. This is OK because most system tasks are not synthesizable in
 * the first place.
 */
void NetSTask::nex_output(NexusSet&)
{
}

/*
* Consider a task call to not have any outputs. This is not quite
* right, we should be listing as outputs all the output ports, but for
* the purposes that this method is used, this will do for now.
*/
void NetUTask::nex_output(NexusSet&)
{
}

void NetWhile::nex_output(NexusSet&out)
{
      if (proc_) proc_->nex_output(out);
}

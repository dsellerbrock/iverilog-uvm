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
# include  "netclass.h"
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
bool nex_output_precise_array_word = false;

void NetAssign_::nex_output(NexusSet&out)
{
      NetNet*interface_member = resolve_interface_member_signal();
      NetNet*use_sig = interface_member ? interface_member : sig_;
      bool nested_root_fallback = false;

	/* A class property may be encoded either on the root assignment node or
	 * as one or more nested nodes. In both cases, output discovery only needs
	 * a conservative provisional map: synthesis will issue the supported-
	 * boundary diagnostic before lowering the property store. */
      if (!interface_member) {
	    const NetAssign_*root = this;
	    while (root->nest())
		  root = root->nest();
	    NetNet*root_sig = root->sig();
	    const netclass_t*root_class = root_sig
		  ? dynamic_cast<const netclass_t*>(root_sig->net_type()) : 0;
	    if (root_class && !root_class->is_interface()) {
		  use_sig = root_sig;
		  nested_root_fallback = true;
	    }
      }
      if (!use_sig && nest_) {
	    /* Object member l-values are rooted in a nested assignment node.
	     * Synthesis validation must be allowed to reject unsupported
	     * object-backed word selects before this output-discovery walk tries
	     * to treat the member as a standalone signal. Use the root carrier
	     * only to construct the provisional process output map. */
	    const NetAssign_*root = nest_;
	    while (root->nest())
		  root = root->nest();
	    use_sig = root->sig();
	    nested_root_fallback = true;
      }
      assert(use_sig);

	/* A nested property's word/base selects describe the property, not the
	 * root object handle. Never apply them to the root carrier: class handles
	 * have a single object pin, so `obj.array_property[1]' otherwise indexes
	 * pin 1 and aborts before synthesis can issue its supported-boundary
	 * diagnostic. Conservatively expose every root word, then let the normal
	 * synthesis validation reject unsupported object-backed l-values. */
      if (nested_root_fallback) {
	    for (unsigned idx = 0; idx < use_sig->pin_count(); idx += 1) {
		  Nexus*nex = use_sig->pin(idx).nexus();
		  out.add(nex, 0, nex->vector_width());
	    }
	    return;
      }

	// A synchronous synthesis pass may replace a single run-time-selected
	// whole-word write by one structural array write port. Let that pass
	// collect all writes first, then substitute its compact output token.
      if (!interface_member && synth_array_write_nex_output(this, out))
	    return;

	// A whole unpacked-array assignment writes every word, and an
	// unpacked-array slice writes every word in its contiguous canonical
	// sub-array. Treating either as one selected word leaves words out of the
	// process output map; a slice additionally reports lwidth()==1 because
	// its netuarray_t is unpacked, creating an overlapping one-bit map entry.
      if (use_sig->unpacked_dimensions() && (!word_ || is_array_slice())) {
	    unsigned long first_word = 0;
	    unsigned long word_count = use_sig->pin_count();

	    if (is_array_slice()) {
		  long base = 0;
		  if (!eval_as_long(base, word_) || base < 0)
			return;
		  first_word = static_cast<unsigned long>(base);
		  word_count = netrange_width(net_type()->slice_dimensions());
		  if (word_count == 0 || first_word >= use_sig->pin_count()
		      || word_count > use_sig->pin_count() - first_word)
			return;
	    }

	    for (unsigned long idx = 0; idx < word_count; idx += 1) {
		  Nexus*word_nex = use_sig->pin(first_word + idx).nexus();
		  out.add(word_nex, 0, word_nex->vector_width());
	    }
	    return;
      }

      unsigned use_word = 0;
      unsigned use_base = 0;
      unsigned use_wid = lwidth();
      if (word_) {
	    const NetEConst*word_const = dynamic_cast<const NetEConst*>(word_);
	    if (word_const) {
		    // A constant word select, so add the selected word.
		  if (!word_const->value().is_defined())
			return;
		  unsigned long tmp = word_const->value().as_ulong();
		  if (tmp >= use_sig->pin_count())
			return;
		  use_word = static_cast<unsigned>(tmp);
	    } else {
		    // For always_comb sensitivity subtraction, claiming the
		    // whole array could remove words that the block only reads.
		    // Synthesis, however, needs every possible word in the output
		    // map before it unrolls a loop and contextually evaluates the
		    // word expression. Keep the precise walk conservative and
		    // expose all words to the default synthesis walk.
		  if (!nex_output_precise_array_word) {
			for (unsigned idx = 0; idx < use_sig->pin_count(); idx += 1) {
			      Nexus*word_nex = use_sig->pin(idx).nexus();
			      out.add(word_nex, 0, word_nex->vector_width());
			}
		  }
		  return;
	    }
      }
      Nexus*nex = use_sig->pin(use_word).nexus();
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
			bool negative = false;
			uint64_t magnitude = verinum_signed_magnitude(
			      base_c->value(), negative);
			uint64_t selected_width = use_wid;
			uint64_t signal_width = nex->vector_width();
			uint64_t overlap_base = 0;
			uint64_t overlap_width = 0;
			if (negative) {
			      if (magnitude < selected_width)
				overlap_width = std::min(
				      selected_width-magnitude, signal_width);
			} else if (magnitude < signal_width) {
			      overlap_base = magnitude;
			      overlap_width = std::min(
				    selected_width, signal_width-magnitude);
			}
			if (overlap_width == 0)
			      return;
			use_base = static_cast<unsigned>(overlap_base);
			use_wid = static_cast<unsigned>(overlap_width);
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
      synth_array_write_loop_enter();
      if (statement_) statement_->nex_output(out);
      synth_array_write_loop_leave();
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

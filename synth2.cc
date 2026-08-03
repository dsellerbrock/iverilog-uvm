/*
 * Copyright (c) 2002-2026 Stephen Williams (steve@icarus.com)
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

# include  "functor.h"
# include  "netlist.h"
# include  "netvector.h"
# include  "netmisc.h"
# include  "compiler.h"
# include  "ivl_assert.h"

using namespace std;

/* General notes on enables and bitmasks.
 *
 * When synthesising an asynchronous process that contains conditional
 * statements (if/case statements), we need to determine the conditions
 * that cause each nexus driven by that process to be updated. If a
 * nexus is not updated under all circumstances, we must infer a latch.
 * To this end, we generate an enable signal for each output nexus. As
 * we walk the statement tree for the process, for each substatement we
 * pass the enable signals generated so far into the synth_async method,
 * and on return from the synth_async method, the enable signals will be
 * updated to reflect any conditions introduced by that substatement.
 * Once we have synthesised all the statements for that process, if an
 * enable signal is not tied high, we must infer a latch for that nexus.
 *
 * When synthesising a synchronous process, we use the synth_async method
 * to synthesise the combinatorial inputs to the D pins of the flip-flops
 * we infer for that process. In this case the enable signal can be used
 * as a clock enable for the flip-flop. This saves us explicitly feeding
 * back the flip-flop output to undriven inputs of any synthesised muxes.
 *
 * A bitmask accompanies each output nexus when different statements drive
 * different parts of a vector. A true bit is unconditionally written along
 * the paths represented by that mask. If an asynchronous process has a
 * constant-high process enable and every bit written anywhere is true in the
 * unconditional mask, false bits are outside its ownership and are driven
 * with Z. This allows disjoint generated processes to compose one packed
 * vector without inventing state. Other conditional partial writes still need
 * independent bit-level latch enables and remain a loud unsupported case. A
 * synchronous process can feed the complete flip-flop output back to undriven
 * mux inputs because it owns the complete registered vector.
 *
 * The enable signals are passed as links to the current output nexus
 * for each signal. If an enable signal is not linked, this is treated
 * as if the signal was tied low.
 *
 * The bitmasks are passed as bool vectors. 'true' indicates a bit is
 * unconditionally driven. An empty vector (size = 0) indicates that
 * the current substatement doesn't drive any bits in the nexus.
 */

static void qualify_enable(Design*des, NetScope*scope, NetNet*qualifier,
			   bool active_state, NetLogic::TYPE gate_type,
			   Link&enable_i, Link&enable_o)
{
      if (enable_i.is_linked(scope->tie_lo())) {
	    connect(enable_o, scope->tie_lo());
	    return;
      }

      if (active_state == false) {
	    NetLogic*gate = new NetLogic(scope, scope->local_symbol(),
					 2, NetLogic::NOT, 1);
	    des->add_node(gate);
	    connect(gate->pin(1), qualifier->pin(0));

	    NetNet*sig = new NetNet(scope, scope->local_symbol(), NetNet::WIRE,
				    &netvector_t::scalar_logic);
	    sig->local_flag(true);
	    connect(sig->pin(0), gate->pin(0));

	    qualifier = sig;
      }

      if (enable_i.is_linked(scope->tie_hi())) {
	    connect(enable_o, qualifier->pin(0));
	    return;
      }

      NetLogic*gate = new NetLogic(scope, scope->local_symbol(),
				   3, gate_type, 1);
      des->add_node(gate);
      connect(gate->pin(1), qualifier->pin(0));
      connect(gate->pin(2), enable_i);
      connect(enable_o, gate->pin(0));

      NetNet*sig = new NetNet(scope, scope->local_symbol(), NetNet::WIRE,
			      &netvector_t::scalar_logic);
      sig->local_flag(true);
      connect(sig->pin(0), gate->pin(0));
}

static void multiplex_enables(Design*des, NetScope*scope, NetNet*select,
			      Link&enable_1, Link&enable_0, Link&enable_o)
{
      if (!enable_1.is_linked() &&
	  !enable_0.is_linked() )
	    return;

      if ( enable_1.is_linked(scope->tie_hi()) &&
	   enable_0.is_linked(scope->tie_hi()) ) {
	    connect(enable_o, scope->tie_hi());
	    return;
      }

      if (enable_1.is_linked(scope->tie_lo()) || !enable_1.is_linked()) {
	    qualify_enable(des, scope, select, false, NetLogic::AND,
			   enable_0, enable_o);
	    return;
      }
      if (enable_0.is_linked(scope->tie_lo()) || !enable_0.is_linked()) {
	    qualify_enable(des, scope, select, true,  NetLogic::AND,
			   enable_1, enable_o);
	    return;
      }
      if (enable_1.is_linked(scope->tie_hi())) {
	    qualify_enable(des, scope, select, true,  NetLogic::OR,
			   enable_0, enable_o);
	    return;
      }
      if (enable_0.is_linked(scope->tie_hi())) {
	    qualify_enable(des, scope, select, false, NetLogic::OR,
			   enable_1, enable_o);
	    return;
      }

      NetMux*mux = new NetMux(scope, scope->local_symbol(), 1, 2, 1);
      des->add_node(mux);
      connect(mux->pin_Sel(),	select->pin(0));
      connect(mux->pin_Data(1), enable_1);
      connect(mux->pin_Data(0), enable_0);
      connect(enable_o, mux->pin_Result());

      NetNet*sig = new NetNet(scope, scope->local_symbol(), NetNet::WIRE,
			      &netvector_t::scalar_logic);
      sig->local_flag(true);
      connect(sig->pin(0), mux->pin_Result());
}

static void merge_sequential_enables(Design*des, NetScope*scope,
				     Link&top_enable, Link&sub_enable)
{
      if (!sub_enable.is_linked())
	    return;

      if (top_enable.is_linked(scope->tie_hi()))
	    return;

      if (sub_enable.is_linked(scope->tie_hi()))
	    top_enable.unlink();

      if (top_enable.is_linked() && sub_enable.is_linked()
	  && top_enable.nexus() == sub_enable.nexus())
	    return;

      if (top_enable.is_linked()) {
	    NetLogic*gate = new NetLogic(scope, scope->local_symbol(),
					 3, NetLogic::OR, 1);
	    des->add_node(gate);
	    connect(gate->pin(1), sub_enable);
	    connect(gate->pin(2), top_enable);
	    top_enable.unlink();
	    connect(top_enable, gate->pin(0));

	    NetNet*sig = new NetNet(scope, scope->local_symbol(), NetNet::WIRE,
				    &netvector_t::scalar_logic);
	    sig->local_flag(true);
	    connect(sig->pin(0), gate->pin(0));
      } else {
	    connect(top_enable, sub_enable);
      }
}

static void merge_sequential_masks(NetScope*scope,
				   Link&top_enable, Link&sub_enable,
				   NetProc::mask_t&top_mask,
				   const NetProc::mask_t&sub_mask)
{
      if (sub_mask.size() == 0)
	    return;

      if (top_mask.size() == 0) {
	    top_mask = sub_mask;
	    return;
      }

      assert(top_mask.size() == sub_mask.size());

	// The vector enable accumulated for sequential statements is their OR.
	// Bits written under different enables are not necessarily written every
	// time that OR is active. Preserve only the bits whose data path is valid
	// for the combined enable; otherwise the top-level latch check must reject
	// the process until independent bit-level enables are available.
      bool top_linked = top_enable.is_linked()
	    && !top_enable.is_linked(scope->tie_lo());
      bool sub_linked = sub_enable.is_linked()
	    && !sub_enable.is_linked(scope->tie_lo());
      if (!top_linked) {
	    top_mask = sub_mask;
	    return;
      }
      if (!sub_linked)
	    return;

      bool top_high = top_enable.is_linked(scope->tie_hi());
      bool sub_high = sub_enable.is_linked(scope->tie_hi());
      if (top_high && !sub_high)
	    return;
      if (sub_high && !top_high) {
	    top_mask = sub_mask;
	    return;
      }

      bool same_enable = top_enable.nexus() == sub_enable.nexus();
      for (unsigned idx = 0 ; idx < top_mask.size() ; idx += 1) {
	    if (top_high || same_enable) {
		  if (sub_mask[idx])
			top_mask[idx] = true;
	    } else if (!sub_mask[idx]) {
		  top_mask[idx] = false;
	    }
      }
}

static void merge_parallel_masks(NetProc::mask_t&top_mask, const NetProc::mask_t&sub_mask)
{
      if (sub_mask.size() == 0)
	    return;

      if (top_mask.size() == 0) {
	    top_mask = sub_mask;
	    return;
      }

      assert(top_mask.size() == sub_mask.size());
      for (unsigned idx = 0 ; idx < top_mask.size() ; idx += 1) {
	    if (sub_mask[idx] == false)
		  top_mask[idx] = false;
      }
}

static bool all_bits_driven(const NetProc::mask_t&mask)
{
      if (mask.size() == 0)
	    return false;

      for (unsigned idx = 0 ; idx < mask.size() ; idx += 1) {
	    if (mask[idx] == false)
		  return false;
      }
      return true;
}

static bool any_bits_driven(const NetProc::mask_t&mask)
{
      for (unsigned idx = 0; idx < mask.size(); idx += 1) {
	    if (mask[idx])
		  return true;
      }
      return false;
}

static void collect_process_write_masks(
		NetProc*statement, NexusSet&output_map,
		vector<NetProc::mask_t>&write_masks)
{
      ivl_assert(*statement, write_masks.size() == output_map.size());

      NexusSet precise_outputs;
      bool saved_precise_partsel = nex_output_precise_partsel;
      nex_output_precise_partsel = true;
      statement->nex_output(precise_outputs);
      nex_output_precise_partsel = saved_precise_partsel;

      for (unsigned out = 0; out < precise_outputs.size(); out += 1) {
	    unsigned precise_base = precise_outputs[out].base;
	    unsigned precise_end = precise_base + precise_outputs[out].wid;
	    Nexus*nexus = precise_outputs[out].lnk.nexus();

	    for (unsigned idx = 0; idx < output_map.size(); idx += 1) {
		  if (output_map[idx].lnk.nexus() != nexus)
			continue;

		  unsigned map_base = output_map[idx].base;
		  unsigned map_end = map_base + output_map[idx].wid;
		  unsigned overlap_base = max(precise_base, map_base);
		  unsigned overlap_end = min(precise_end, map_end);
		  if (overlap_end <= overlap_base)
			continue;

		  NetProc::mask_t&mask = write_masks[idx];
		  if (mask.size() < output_map[idx].wid)
			mask.resize(output_map[idx].wid, false);
		  for (unsigned bit = overlap_base; bit < overlap_end;
		       bit += 1)
			mask[bit - map_base] = true;
	    }
      }
}

static bool all_process_writes_are_driven(
		const NetProc::mask_t&driven_mask,
		const NetProc::mask_t&write_mask)
{
      for (unsigned bit = 0; bit < write_mask.size(); bit += 1) {
	    if (write_mask[bit]
		  && (bit >= driven_mask.size() || !driven_mask[bit]))
		  return false;
      }
      return true;
}

struct synth_write_mask_context_t {
      NexusSet*output_map;
      vector<NetProc::mask_t>*write_masks;
};

static synth_write_mask_context_t*active_synth_write_mask_context = 0;

class synth_write_mask_guard_t {

    public:
      explicit synth_write_mask_guard_t(synth_write_mask_context_t*context)
      : saved_(active_synth_write_mask_context)
      {
	    active_synth_write_mask_context = context;
      }

      ~synth_write_mask_guard_t()
      {
	    active_synth_write_mask_context = saved_;
      }

    private:
      synth_write_mask_context_t*saved_;
};

static void record_synthesized_write(const LineInfo&loc, Nexus*nexus,
				     unsigned base, unsigned width)
{
      if (!active_synth_write_mask_context || width == 0)
	    return;

      NexusSet&output_map = *active_synth_write_mask_context->output_map;
      vector<NetProc::mask_t>&write_masks =
	    *active_synth_write_mask_context->write_masks;
      ivl_assert(loc, write_masks.size() == output_map.size());

      unsigned write_end = base + width;
      bool found = false;
      for (unsigned idx = 0; idx < output_map.size(); idx += 1) {
	    if (output_map[idx].lnk.nexus() != nexus)
		  continue;

	    unsigned map_base = output_map[idx].base;
	    unsigned map_end = map_base + output_map[idx].wid;
	    unsigned overlap_base = max(base, map_base);
	    unsigned overlap_end = min(write_end, map_end);
	    if (overlap_end <= overlap_base)
		  continue;

	    NetProc::mask_t&mask = write_masks[idx];
	    ivl_assert(loc, mask.size() == output_map[idx].wid);
	    for (unsigned bit = overlap_base; bit < overlap_end; bit += 1)
		  mask[bit - map_base] = true;
	    found = true;
      }
      ivl_assert(loc, found);
}

static void claim_synthesized_process_outputs(
		Design*des, const LineInfo&loc, NexusSet&outputs,
		const vector<NetProc::mask_t>&write_masks)
{
      ivl_assert(loc, write_masks.size() == outputs.size());

        // A process may mention the same nexus in several branches or
        // assignments. Union those ranges locally before making global
        // claims so repeated writes within one process are not mistaken for
        // multiple-process ownership.
      map<Nexus*, NetProc::mask_t> process_masks;
      for (unsigned idx = 0; idx < outputs.size(); idx += 1) {
	    Nexus*nexus = outputs[idx].lnk.nexus();
	    NetProc::mask_t&mask = process_masks[nexus];
	    const NetProc::mask_t&write_mask = write_masks[idx];
	    ivl_assert(loc, write_mask.size() == outputs[idx].wid);
	    unsigned end = outputs[idx].base + write_mask.size();
	    if (mask.size() < end)
		  mask.resize(end, false);
	    for (unsigned bit = 0; bit < write_mask.size(); bit += 1) {
		  if (write_mask[bit])
			mask[outputs[idx].base + bit] = true;
	    }
      }

      bool any_overlap = false;
      for (map<Nexus*, NetProc::mask_t>::iterator cur = process_masks.begin();
	   cur != process_masks.end(); ++cur) {
	    Nexus*nexus = cur->first;
	    const NetProc::mask_t&mask = cur->second;
	    for (unsigned bit = 0; bit < mask.size(); bit += 1) {
		  if (!mask[bit])
			continue;

		  if (!nexus->claim_synthesized_process_driver(bit, 1))
			continue;

		  NetNet*net = nexus->pick_any_net();
		  cerr << loc.get_fileline() << ": warning: '"
		       << (net ? net->name() : perm_string::literal("<unnamed>"))
		       << "' bit " << bit
		       << " is driven by more than one process." << endl;
		  any_overlap = true;
	    }
      }

      if (any_overlap) {
	    cerr << loc.get_fileline() << ": sorry: Cannot synthesize packed bits "
		    "that are driven by more than one process." << endl;
	    des->errors += 1;
      }
}

static void connect_synthesized_process_output(
		Design*des, NetScope*scope, const LineInfo&loc,
		unsigned width, Link&output, Link&input)
{
        // Keep the variable owned by this process on the output side of a
        // structural device. A direct nexus merge makes ownership propagate
        // backward through module inputs and into an upstream process, so a
        // legal chain such as `always_comb d_o = d_i' is misdiagnosed as
        // multiple procedural drivers. A transparent buffer preserves the
        // synthesized value and four-state behavior while retaining the
        // directional process boundary.
      NetBUFZ*driver = new NetBUFZ(scope, scope->local_symbol(), width, true);
      driver->set_line(loc);
      des->add_node(driver);
      connect(driver->pin(0), output);
      connect(driver->pin(1), input);
}

static NetNet*mask_synthesized_process_output(
		Design*des, NetScope*scope, const LineInfo&loc,
		NetNet*source, const NetProc::mask_t&write_mask)
{
      unsigned width = source->vector_width();
      ivl_assert(loc, write_mask.size() == width);
      if (all_bits_driven(write_mask))
	    return source;

	// A process that owns only part of a packed variable must drive Z on
	// every other bit so disjoint synthesized processes compose. Build the
	// masked vector from contiguous owned ranges to avoid one node per bit.
      NetNet*result = make_const_z(des, scope, width);
      for (unsigned base = 0; base < width;) {
	    while (base < width && !write_mask[base])
		  base += 1;
	    if (base == width)
		  break;

	    unsigned end = base + 1;
	    while (end < width && write_mask[end])
		  end += 1;
	    unsigned part_width = end - base;

	    NetPartSelect*select = new NetPartSelect(
		  source, base, part_width, NetPartSelect::VP);
	    select->set_line(loc);
	    des->add_node(select);

	    const netvector_t*part_type = new netvector_t(
		  source->data_type(), part_width-1, 0);
	    NetNet*part = new NetNet(scope, scope->local_symbol(),
			       NetNet::WIRE, part_type);
	    part->local_flag(true);
	    part->set_line(loc);
	    connect(part->pin(0), select->pin(0));

	    const netvector_t*result_type = new netvector_t(
		  source->data_type(), width-1, 0);
	    NetNet*next = new NetNet(scope, scope->local_symbol(),
			       NetNet::WIRE, result_type);
	    next->local_flag(true);
	    next->set_line(loc);
	    NetSubstitute*substitute = new NetSubstitute(
		  result, part, width, base);
	    substitute->set_line(loc);
	    des->add_node(substitute);
	    connect(next->pin(0), substitute->pin(0));
	    result = next;
	    base = end;
      }

      return result;
}

static NetNet*synthesize_array_word_match(
		Design*des, NetScope*scope, const LineInfo&loc,
		NetNet*word_select, unsigned long word)
{
      unsigned width = word_select->vector_width();
      ivl_assert(loc, width > 0);

      NetConst*constant = new NetConst(scope, scope->local_symbol(),
				      verinum(static_cast<uint64_t>(word), width));
      constant->set_line(loc);
      des->add_node(constant);

      const netvector_t*constant_type = new netvector_t(
		IVL_VT_LOGIC, width-1, 0);
      NetNet*constant_signal = new NetNet(
		scope, scope->local_symbol(), NetNet::WIRE, constant_type);
      constant_signal->local_flag(true);
      constant_signal->set_line(loc);
      connect(constant_signal->pin(0), constant->pin(0));

	// A run-time array index containing X or Z selects no word for an
	// l-value update. Case equality makes every decoder output a definite
	// zero in that case instead of propagating X into a flip-flop enable.
      NetCaseCmp*compare = new NetCaseCmp(scope, scope->local_symbol(),
					 width, NetCaseCmp::EEQ);
      compare->set_line(loc);
      des->add_node(compare);
      connect(compare->pin(1), word_select->pin(0));
      connect(compare->pin(2), constant_signal->pin(0));

      NetNet*match = new NetNet(scope, scope->local_symbol(), NetNet::WIRE,
				&netvector_t::scalar_logic);
      match->local_flag(true);
      match->set_line(loc);
      connect(match->pin(0), compare->pin(0));
      return match;
}

bool NetProcTop::tie_off_floating_inputs_(Design*des,
					  NexusSet&nex_map, NetBus&nex_in,
					  const vector<NetProc::mask_t>&bitmasks,
					  bool is_ff_input,
					  NetBus*process_enables,
					  const vector<NetProc::mask_t>*
						process_write_masks)
{
      bool flag = true;
      if (process_write_masks)
	    ivl_assert(*this,
		  process_write_masks->size() == nex_in.pin_count());
      for (unsigned idx = 0 ; idx < nex_in.pin_count() ; idx += 1) {
	    if (process_write_masks
		&& !any_bits_driven((*process_write_masks)[idx]))
		  continue;

	    if (nex_in.pin(idx).nexus()->has_floating_input()) {
		  if (all_bits_driven(bitmasks[idx])) {
			  // If all bits are unconditionally driven, we can
			  // use the enable signal to prevent the flip-flop/
			  // latch from updating when an undriven mux input
			  // is selected, so we can just tie off the input.
			unsigned width = nex_map[idx].wid;
			NetLogic*gate = new NetLogic(scope(), scope()->local_symbol(),
						     1, NetLogic::PULLDOWN, width);
			des->add_node(gate);
			connect(nex_in.pin(idx), gate->pin(0));

			if (nex_in.pin(idx).nexus()->pick_any_net())
			      continue;

			ivl_variable_type_t data_type = IVL_VT_LOGIC;
			const netvector_t*tmp_vec = new netvector_t(data_type, width-1,0);
			NetNet*sig = new NetNet(scope(), scope()->local_symbol(),
						NetNet::WIRE, tmp_vec);
			sig->local_flag(true);
			connect(sig->pin(0), gate->pin(0));
		  } else if (is_ff_input) {
			  // For a flip-flop, we can feed back the output
			  // to ensure undriven bits hold their last value.
			connect(nex_in.pin(idx), nex_map[idx].lnk);
		  } else {
			bool fully_enabled = process_enables
			      && process_enables->pin(idx).is_linked(
				    scope()->tie_hi());
			bool every_write_is_driven = process_write_masks
			      && all_process_writes_are_driven(
				    bitmasks[idx], (*process_write_masks)[idx]);
			if (fully_enabled && every_write_is_driven) {
			      NetNet*z_value =
				    make_const_z(des, scope(), nex_map[idx].wid);
			      connect(nex_in.pin(idx), z_value->pin(0));
			      continue;
			}

			cerr << get_fileline() << ": warning: A latch "
			     << "has been inferred for some bits of '"
			     << nex_map[idx].lnk.nexus()->pick_any_net()->name()
			     << "'." << endl;
			cerr << get_fileline() << ": sorry: Bit-level "
				"latch gate enables are not currently "
				"supported in synthesis." << endl;
			des->errors += 1;
			flag = false;
		  }
	    }
      }
      return flag;
}

bool NetProc::synth_async(Design*, NetScope*, NexusSet&, NetBus&, NetBus&, vector<mask_t>&)
{
      return false;
}

/* Return true when constant-function evaluation can fold this expression
 * without encountering a run-time signal. This lets synthesis substitute an
 * unrolled loop index quietly, while preserving a dynamic l-value index such
 * as vec[index_signal][loop_index]. */
static bool synth_context_constant(const NetExpr*expr,
				   const map<perm_string,LocalVar>&context)
{
      if (dynamic_cast<const NetEConst*>(expr))
	    return true;

      if (const NetESignal*sig = dynamic_cast<const NetESignal*>(expr)) {
	    if (context.find(sig->name()) == context.end())
		  return false;
	    return !sig->word_index()
		  || synth_context_constant(sig->word_index(), context);
      }

      if (const NetEBinary*binary = dynamic_cast<const NetEBinary*>(expr))
	    return synth_context_constant(binary->left(), context)
		&& synth_context_constant(binary->right(), context);

      if (const NetEUnary*unary = dynamic_cast<const NetEUnary*>(expr))
	    return synth_context_constant(unary->expr(), context);

      if (const NetESelect*select = dynamic_cast<const NetESelect*>(expr))
	    return synth_context_constant(select->sub_expr(), context)
		&& (!select->select()
		    || synth_context_constant(select->select(), context));

      if (const NetETernary*ternary = dynamic_cast<const NetETernary*>(expr))
	    return synth_context_constant(ternary->cond_expr(), context)
		&& synth_context_constant(ternary->true_expr(), context)
		&& synth_context_constant(ternary->false_expr(), context);

      return false;
}

/* Synthesize a procedural write to a run-time selected packed part. Build one
 * case-equality decoder per legal canonical base, then mux only the affected
 * scalar bits and concatenate them back into a vector. Case equality is
 * intentional: an index containing X/Z, or an out-of-range index, matches no
 * legal base and therefore leaves the value unchanged, as a procedural packed
 * write must. */
static NetNet*synth_variable_part_update(Design*des, NetScope*scope,
					 const LineInfo&loc,
					 const NetExpr*base_expr,
					 NetNet*prior, NetNet*replacement,
					 unsigned full_width,
					 unsigned part_width)
{
      NetExpr*base_copy = base_expr->dup_expr();
      NetNet*base_sig = base_copy->synthesize(des, scope, base_copy);
      delete base_copy;
      if (!base_sig)
	    return 0;

      unsigned select_width = base_sig->vector_width();
      if (select_width == 0 || part_width == 0)
	    return 0;
      if (debug_synth2) {
	    cerr << loc.get_fileline() << ": synth_variable_part_update: selector "
		 << "width=" << select_width
		 << ", signed=" << base_sig->get_signed()
		 << ", full_width=" << full_width
		 << ", part_width=" << part_width << endl;
      }

      long first_base = 1 - static_cast<long>(part_width);
      long last_base = static_cast<long>(full_width) - 1;
      if (select_width < 8 * sizeof(long)) {
	    if (base_sig->get_signed()) {
		  const long representable_min = -(1L << (select_width - 1));
		  const long representable_max = (1L << (select_width - 1)) - 1;
		  first_base = max(first_base, representable_min);
		  last_base = min(last_base, representable_max);
	    } else {
		  first_base = max(first_base, 0L);
		  const unsigned long representable_max =
			(1UL << select_width) - 1;
		  if (static_cast<unsigned long>(last_base) > representable_max)
			last_base = static_cast<long>(representable_max);
	    }
      } else if (!base_sig->get_signed()) {
	    first_base = max(first_base, 0L);
      }
      ivl_assert(loc, first_base <= last_base);

      vector<NetNet*>base_selected(last_base - first_base + 1,
					  static_cast<NetNet*>(0));
      for (long base = first_base; base <= last_base; base += 1) {
	    verinum base_value = cast_to_width(
		  verinum(static_cast<int64_t>(base)), select_width);
	    NetEConst base_constant(base_value);
	    base_constant.set_line(loc);
	    NetNet*constant_sig =
		  base_constant.synthesize(des, scope, &base_constant);
	    ivl_assert(loc, constant_sig);

	    NetCaseCmp*compare = new NetCaseCmp(scope, scope->local_symbol(),
						 select_width, NetCaseCmp::EEQ);
	    compare->set_line(loc);
	    des->add_node(compare);
	    connect(compare->pin(1), base_sig->pin(0));
	    connect(compare->pin(2), constant_sig->pin(0));

	    const unsigned decoder_index = base - first_base;
	    base_selected[decoder_index] =
		  new NetNet(scope, scope->local_symbol(), NetNet::WIRE,
			     &netvector_t::scalar_logic);
	    base_selected[decoder_index]->local_flag(true);
	    base_selected[decoder_index]->set_line(loc);
	    connect(base_selected[decoder_index]->pin(0), compare->pin(0));
      }

      auto select_bit = [des, scope, &loc](NetNet*vector,
						  unsigned bit) -> NetNet* {
	    NetPartSelect*select =
		  new NetPartSelect(vector, bit, 1, NetPartSelect::VP);
	    select->set_line(loc);
	    des->add_node(select);
	    NetNet*result = new NetNet(scope, scope->local_symbol(),
					NetNet::WIRE, &netvector_t::scalar_logic);
	    result->local_flag(true);
	    result->set_line(loc);
	    connect(result->pin(0), select->pin(0));
	    return result;
      };

      vector<NetNet*>replacement_bits(part_width, static_cast<NetNet*>(0));
      for (unsigned bit = 0; bit < part_width; bit += 1)
	    replacement_bits[bit] = select_bit(replacement, bit);

      NetConcat*concat = new NetConcat(scope, scope->local_symbol(),
				      full_width, full_width, false);
      concat->set_line(loc);
      des->add_node(concat);
      for (unsigned dst_bit = 0; dst_bit < full_width; dst_bit += 1) {
	    NetNet*current = select_bit(prior, dst_bit);
	    for (unsigned src_bit = 0; src_bit < part_width; src_bit += 1) {
		  const long base = static_cast<long>(dst_bit) - src_bit;
		  if (base < first_base || base > last_base)
			continue;

		  NetMux*mux = new NetMux(scope, scope->local_symbol(), 1, 2, 1);
		  mux->set_line(loc);
		  des->add_node(mux);
		  connect(mux->pin_Sel(),
			  base_selected[base - first_base]->pin(0));
		  connect(mux->pin_Data(0), current->pin(0));
		  connect(mux->pin_Data(1), replacement_bits[src_bit]->pin(0));

		  NetNet*next = new NetNet(scope, scope->local_symbol(),
					    NetNet::WIRE,
					    &netvector_t::scalar_logic);
		  next->local_flag(true);
		  next->set_line(loc);
		  connect(next->pin(0), mux->pin_Result());
		  current = next;
	    }
	    connect(concat->pin(dst_bit + 1), current->pin(0));
      }

      const netvector_t*result_type =
	    new netvector_t(replacement->data_type(), full_width-1, 0);
      NetNet*result = new NetNet(scope, scope->local_symbol(),
				NetNet::WIRE, result_type);
      result->local_flag(true);
      result->set_line(loc);
      connect(result->pin(0), concat->pin(0));
      return result;
}

/*
 * Async synthesis of assignments is done by synthesizing the rvalue
 * expression, then connecting the l-value directly to the output of
 * the r-value.
 *
 * The nex_map is the O-set for the statement, and lists the positions
 * of the outputs as the caller wants results linked up. The nex_out,
 * however, is the set of nexa that are to actually get linked to the
 * r-value.
 */
bool NetAssignBase::synth_async(Design*des, NetScope*scope,
				NexusSet&nex_map, NetBus&nex_out,
				NetBus&enables, vector<mask_t>&bitmasks)
{
      if (dynamic_cast<NetCAssign*>(this) || dynamic_cast<NetDeassign*>(this) ||
          dynamic_cast<NetForce*>(this) || dynamic_cast<NetRelease*>(this)) {
	    cerr << get_fileline() << ": sorry: Procedural continuous "
		    "assignment is not currently supported in synthesis."
		 << endl;
	    des->errors += 1;
	    return false;
      }

	/* If the lval is a concatenation, synthesise each part
	   separately. */
      if (lval_->more ) {
	      /* Temporarily set the lval_ and rval_ fields for each
		 part in turn and recurse. Restore them when done. */
	    NetAssign_*full_lval = lval_;
	    NetExpr*full_rval = rval_;
	    unsigned offset = 0;
	    bool flag = true;
	    while (lval_) {
		  unsigned width = lval_->lwidth();
		  NetEConst*base = new NetEConst(verinum(offset));
		  base->set_line(*this);
		  rval_ = new NetESelect(full_rval->dup_expr(), base, width);
		  rval_->set_line(*this);
		  eval_expr(rval_, width);
		  NetAssign_*more = lval_->more;
		  lval_->more = 0;
		  if (!synth_async(des, scope, nex_map, nex_out, enables, bitmasks))
			flag = false;
		  lval_->more = more;
		  lval_ = lval_->more;
		  offset += width;
	    }
	    lval_ = full_lval;
	    rval_ = full_rval;
	    return flag;
      }

      assert(rval_);
      NetNet*rsig = rval_->synthesize(des, scope, rval_);
      assert(rsig);

      NetNet*lsig = lval_->sig();
      if (!lsig) {
	    cerr << get_fileline() << ": error: "
		    "NetAssignBase::synth_async on unsupported lval ";
	    dump_lval(cerr);
	    cerr << endl;
	    des->errors += 1;
	    return false;
      }

	// Array patterns and whole-array expressions synthesize to one NetNet
	// pin per unpacked word. Lower the assignment word-by-word so each word
	// is matched to its own process-output nexus. The vector assignment path
	// below intentionally handles a single packed word and cannot infer this
	// mapping from lwidth(), which is the packed width of the array element.
      if (lsig->unpacked_dimensions() && !lval_->word()) {
	    if (rsig->pin_count() != lsig->pin_count()) {
		  cerr << get_fileline() << ": error: Whole unpacked-array "
		       << "assignment has " << rsig->pin_count()
		       << " source words but " << lsig->pin_count()
		       << " destination words." << endl;
		  des->errors += 1;
		  return false;
	    }

	    for (unsigned word = 0; word < lsig->pin_count(); word += 1) {
		  Nexus*word_nex = lsig->pin(word).nexus();
		  NexusSet word_set;
		  word_set.add(word_nex, 0, word_nex->vector_width());
		  unsigned ptr = nex_map.find_nexus(word_set[0]);
		  ivl_assert(*this, ptr < nex_out.pin_count());
		  ivl_assert(*this, ptr < enables.pin_count());
		  ivl_assert(*this, ptr < bitmasks.size());
		  ivl_assert(*this, nex_map[ptr].wid == word_nex->vector_width());
		  ivl_assert(*this,
			     rsig->pin(word).nexus()->vector_width()
				   == word_nex->vector_width());

		  nex_out.pin(ptr).unlink();
		  enables.pin(ptr).unlink();
		  connect(nex_out.pin(ptr), rsig->pin(word));
		  connect(enables.pin(ptr), scope->tie_hi());
		  bitmasks[ptr] = mask_t(word_nex->vector_width(), true);
		  record_synthesized_write(*this, word_nex, 0,
					   word_nex->vector_width());
	    }

	    lval_->turn_sig_to_wire_on_release();
	    return true;
      }

      bool lval_has_word = lval_->word() != 0;
      unsigned lval_word = 0;
      if (lval_has_word) {
	    NetExpr*word_expr = lval_->word();
	    NetExpr*word_result = 0;
	    const NetExpr*word_value = word_expr;
	    if (!dynamic_cast<const NetEConst*>(word_expr)
		&& synth_context_constant(word_expr, scope->loop_index_tmp)) {
		  word_result = word_expr->evaluate_function(*this,
						 scope->loop_index_tmp);
		  word_value = word_result;
	    }

	    long word_index = 0;
	    const NetEConst*word_constant =
		  dynamic_cast<const NetEConst*>(word_value);
	    bool undefined_constant_word = word_constant
		  && !word_constant->value().is_defined();
	    bool constant_word = !undefined_constant_word
		  && eval_as_long(word_index, word_value);
	    delete word_result;
	    if (undefined_constant_word) {
		    // A compile-time X/Z memory index selects no word.
		  lval_->turn_sig_to_wire_on_release();
		  return true;
	    }
	    if (!constant_word) {
		  if (lval_->get_base()
		      || lval_->lwidth() != lsig->vector_width()) {
			cerr << get_fileline() << ": sorry: Assignment to a "
				  "packed select of a run-time selected memory "
				  "word is not currently supported in synthesis."
			     << endl;
			des->errors += 1;
			return false;
		  }

		  NetNet*word_select = word_expr->synthesize(des, scope,
							 word_expr);
		  if (!word_select || word_select->pin_count() != 1) {
			cerr << get_fileline() << ": error: unable to synthesize "
				  "run-time memory word select." << endl;
			des->errors += 1;
			return false;
		  }

		    // Lower a variable word write to one data input per possible
		    // array word and a decoded enable. In synchronous logic the
		    // enables become per-word flip-flop enables; enclosing if/case
		    // conditions are combined by the ordinary enable machinery.
		  ivl_assert(*this, rsig->pin_count() == 1);
		  for (unsigned word = 0; word < lsig->pin_count(); word += 1) {
			Nexus*word_nex = lsig->pin(word).nexus();
			NexusSet word_set;
			word_set.add(word_nex, 0, word_nex->vector_width());
			unsigned ptr = nex_map.find_nexus(word_set[0]);
			ivl_assert(*this, ptr < nex_out.pin_count());
			ivl_assert(*this, ptr < enables.pin_count());
			ivl_assert(*this, ptr < bitmasks.size());
			ivl_assert(*this,
				   nex_map[ptr].wid == word_nex->vector_width());

			NetNet*match = synthesize_array_word_match(
			      des, scope, *this, word_select, word);
			nex_out.pin(ptr).unlink();
			enables.pin(ptr).unlink();
			connect(nex_out.pin(ptr), rsig->pin(0));
			connect(enables.pin(ptr), match->pin(0));
			bitmasks[ptr] = mask_t(word_nex->vector_width(), true);
			record_synthesized_write(*this, word_nex, 0,
						 word_nex->vector_width());
		  }

		  lval_->turn_sig_to_wire_on_release();
		  return true;
	    }
	    if (word_index < 0
		|| static_cast<unsigned long>(word_index) >= lsig->pin_count()) {
		  cerr << get_fileline() << ": error: Contextually constant memory "
			  "word index " << word_index << " is out of range for "
			  << lsig->name() << "." << endl;
		  des->errors += 1;
		  return false;
	    }
	    lval_word = static_cast<unsigned>(word_index);
      }

      if (debug_synth2) {
	    cerr << get_fileline() << ": NetAssignBase::synth_async: "
		 << "l-value signal is " << lsig->vector_width() << " bits, "
		 << "r-value signal is " << rsig->vector_width() << " bits." << endl;
	    cerr << get_fileline() << ": NetAssignBase::synth_async: "
		 << "lval_->lwidth()=" << lval_->lwidth() << endl;
	    cerr << get_fileline() << ": NetAssignBase::synth_async: "
		 << "lsig = " << scope_path(scope) << "." << lsig->name() << endl;
	    if (const NetExpr*base = lval_->get_base()) {
		  cerr << get_fileline() << ": NetAssignBase::synth_async: "
		       << "base_=" << *base << endl;
	    }
	    cerr << get_fileline() << ": NetAssignBase::synth_async: "
		 << "nex_map.size()==" << nex_map.size()
		 << ", nex_out.pin_count()==" << nex_out.pin_count() << endl;
      }

      unsigned ptr = 0;
      if (nex_out.pin_count() > 1) {
	    NexusSet tmp_set;
	    if (lval_has_word) {
		  Nexus*word_nex = lsig->pin(lval_word).nexus();
		  tmp_set.add(word_nex, 0, word_nex->vector_width());
	    } else {
		  nex_output(tmp_set);
	    }
	    ivl_assert(*this, tmp_set.size() == 1);
	    ptr = nex_map.find_nexus(tmp_set[0]);
	    ivl_assert(*this, nex_out.pin_count() > ptr);
	    ivl_assert(*this, enables.pin_count() > ptr);
	    ivl_assert(*this, bitmasks.size() > ptr);
      } else {
	    ivl_assert(*this, nex_out.pin_count() == 1);
	    ivl_assert(*this, enables.pin_count() == 1);
	    ivl_assert(*this, bitmasks.size() == 1);
      }

      unsigned lval_width = lval_->lwidth();
      unsigned lsig_width = lsig->vector_width();
      ivl_assert(*this, nex_map[ptr].wid == lsig_width);

      // Here we note if the l-value is actually a bit/part
      // select. If so, generate a NetPartSelect to perform the select.
      bool is_part_select = lval_->get_base() != 0;
	// The unrolled-loop path can retain the expression's wider natural
	// width; size it to the selected l-value before substitution. Preserve
	// the established non-loop lowering, where an otherwise undriven part
	// of a synthesized register remains undriven rather than stateful.
      if (is_part_select && !scope->loop_index_tmp.empty())
	    rsig = crop_to_width(des, rsig, lval_width);

      long base_off = 0;
      bool variable_part_select = false;
      bool clipped_constant_part_select = false;
      unsigned clipped_base = 0;
      unsigned clipped_width = 0;
      bool no_op_part_select = false;
      if (is_part_select) {
	    const NetExpr*base_expr_raw = lval_->get_base();
	    ivl_assert(*this, base_expr_raw);

	    NetExpr*base_expr = 0;
	    if (synth_context_constant(base_expr_raw, scope->loop_index_tmp))
		  base_expr = base_expr_raw->evaluate_function(*this,
							 scope->loop_index_tmp);

	    const NetEConst*base_constant =
		  dynamic_cast<const NetEConst*>(base_expr);
	    bool undefined_constant_base = base_constant
		  && !base_constant->value().is_defined();
	    bool constant_base = !undefined_constant_base
		  && eval_as_long(base_off, base_expr);
	    delete base_expr;
	    if (undefined_constant_base) {
		    // A compile-time X/Z packed index selects no bit. Preserve the
		    // accumulated value and write mask exactly as for an out-of-range
		    // constant select.
		  rsig = nex_out.pin(ptr).nexus()->pick_any_net();
		  if (!rsig) {
			const netvector_t*tmp_type =
			      new netvector_t(lsig->data_type(), lsig_width-1, 0);
			rsig = new NetNet(scope, scope->local_symbol(),
					  NetNet::WIRE, tmp_type);
			rsig->local_flag(true);
			rsig->set_line(*this);
			connect(rsig->pin(0), nex_out.pin(ptr));
		  }
		  no_op_part_select = true;
	    } else if (constant_base && base_off >= 0
		&& static_cast<unsigned long>(base_off) + lval_width <= lsig_width) {
		  ivl_variable_type_t tmp_data_type = rsig->data_type();
		  const netvector_t*tmp_type =
			new netvector_t(tmp_data_type, lsig_width-1, 0);
		  NetNet*tmp = new NetNet(scope, scope->local_symbol(),
					  NetNet::WIRE, tmp_type);
		  tmp->local_flag(true);
		  tmp->set_line(*this);

		  NetNet*isig = nex_out.pin(ptr).nexus()->pick_any_net();
		  if (!isig) {
			isig = new NetNet(scope, scope->local_symbol(),
					  NetNet::WIRE, tmp_type);
			isig->local_flag(true);
			isig->set_line(*this);
			connect(isig->pin(0), nex_out.pin(ptr));
		  }
		  NetSubstitute*ps =
			new NetSubstitute(isig, rsig, lsig_width, base_off);
		  ps->set_line(*this);
		  des->add_node(ps);
		  connect(ps->pin(0), tmp->pin(0));
		  rsig = tmp;
	    } else if (constant_base
		       && (base_off >= static_cast<long>(lsig_width)
			   || base_off + static_cast<long>(lval_width) <= 0)) {
		    // A statically non-overlapping procedural select writes no bits.
		  rsig = nex_out.pin(ptr).nexus()->pick_any_net();
		  if (!rsig) {
			const netvector_t*tmp_type =
			      new netvector_t(lsig->data_type(), lsig_width-1, 0);
			rsig = new NetNet(scope, scope->local_symbol(),
					  NetNet::WIRE, tmp_type);
			rsig->local_flag(true);
			rsig->set_line(*this);
			connect(rsig->pin(0), nex_out.pin(ptr));
		  }
		  no_op_part_select = true;
	    } else {
		  const netvector_t*tmp_type =
			new netvector_t(lsig->data_type(), lsig_width-1, 0);
		  NetNet*isig = nex_out.pin(ptr).nexus()->pick_any_net();
		  if (!isig) {
			isig = new NetNet(scope, scope->local_symbol(),
					  NetNet::WIRE, tmp_type);
			isig->local_flag(true);
			isig->set_line(*this);
			connect(isig->pin(0), nex_out.pin(ptr));
		  }
		  rsig = synth_variable_part_update(des, scope, *this,
						    base_expr_raw, isig, rsig,
						    lsig_width, lval_width);
		  if (!rsig) {
			cerr << get_fileline() << ": error: unable to synthesize "
				  "variable packed l-value select." << endl;
			des->errors += 1;
			return false;
		  }
		  if (constant_base) {
			long overlap_base = max(base_off, 0L);
			long overlap_end = min(
			      base_off + static_cast<long>(lval_width),
			      static_cast<long>(lsig_width));
			ivl_assert(*this, overlap_end > overlap_base);
			clipped_constant_part_select = true;
			clipped_base = static_cast<unsigned>(overlap_base);
			clipped_width = static_cast<unsigned>(overlap_end
						       - overlap_base);
		  } else {
			variable_part_select = true;
		  }
	    }
      }

      rsig = crop_to_width(des, rsig, lsig_width);

      ivl_assert(*this, rsig->pin_count()==1);
      if (!no_op_part_select) {
	    nex_out.pin(ptr).unlink();
	    enables.pin(ptr).unlink();
	    connect(nex_out.pin(ptr), rsig->pin(0));
	    connect(enables.pin(ptr), scope->tie_hi());
	}

      mask_t&bitmask = bitmasks[ptr];
      if (no_op_part_select) {
	    // Preserve the accumulated mask: a statically non-overlapping
	    // procedural select writes no bits.
      } else if (variable_part_select) {
	    // A run-time select can potentially write every bit, but no bit is
	    // guaranteed to be written on every activation (and an X/Z or wholly
	    // out-of-range base writes none). A preceding whole-vector default
	    // assignment can still make the accumulated sequential mask complete.
	    if (bitmask.size() == 0)
		  bitmask = mask_t(lsig_width, false);
	    ivl_assert(*this, bitmask.size() == lsig_width);
      } else if (clipped_constant_part_select) {
	    if (bitmask.size() == 0)
		  bitmask = mask_t(lsig_width, false);
	    ivl_assert(*this, bitmask.size() == lsig_width);
	    for (unsigned idx = 0; idx < clipped_width; idx += 1)
		  bitmask[clipped_base + idx] = true;
      } else if (is_part_select) {
	    if (bitmask.size() == 0) {
		  bitmask = mask_t (lsig_width, false);
	    }
	    ivl_assert(*this, bitmask.size() == lsig_width);
	    for (unsigned idx = 0; idx < lval_width; idx += 1) {
		  bitmask[base_off + idx] = true;
	    }
      } else if (bitmask.size() > 0) {
	    for (unsigned idx = 0; idx < bitmask.size(); idx += 1) {
		  bitmask[idx] = true;
	    }
      } else {
	    bitmask = mask_t (lsig_width, true);
      }

      if (!no_op_part_select) {
	    Nexus*write_nexus = lsig->pin(lval_has_word ? lval_word : 0).nexus();
	    if (variable_part_select) {
		  record_synthesized_write(*this, write_nexus, 0, lsig_width);
	    } else if (clipped_constant_part_select) {
		  record_synthesized_write(*this, write_nexus,
					   clipped_base, clipped_width);
	    } else if (is_part_select) {
		  ivl_assert(*this, base_off >= 0);
		  record_synthesized_write(*this, write_nexus,
					   static_cast<unsigned>(base_off),
					   lval_width);
	    } else {
		  record_synthesized_write(*this, write_nexus, 0, lsig_width);
	    }
      }

	/* This lval_ represents a reg that is a WIRE in the
	   synthesized results. This function signals the destructor
	   to change the REG that this l-value refers to into a
	   WIRE. It is done then, at the last minute, so that pending
	   synthesis can continue to work with it as a REG. */
      lval_->turn_sig_to_wire_on_release();

      return true;
}

bool NetProc::synth_async_block_substatement_(Design*des, NetScope*scope,
					      NexusSet&nex_map,
					      NetBus&nex_out,
					      NetBus&enables,
					      vector<mask_t>&bitmasks,
					      NetProc*substmt)
{
      ivl_assert(*this, nex_map.size() == nex_out.pin_count());
      ivl_assert(*this, nex_map.size() == enables.pin_count());
      ivl_assert(*this, nex_map.size() == bitmasks.size());

	// Create a temporary map of the output only from this statement.
      NexusSet tmp_map;
      substmt->nex_output(tmp_map);
      if (debug_synth2) {
	    cerr << get_fileline() << ": NetProc::synth_async_block_substatement_: "
		 << "tmp_map.size()==" << tmp_map.size()
		 << " for statement at " << substmt->get_fileline()
		 << endl;
	    for (unsigned idx  = 0 ; idx < nex_out.pin_count() ; idx += 1) {
		  cerr << get_fileline() << ": NetProc::synth_async_block_substatement_: "
		       << "incoming nex_out[" << idx << "] dump link" << endl;
		  nex_out.pin(idx).dump_link(cerr, 8);
	    }
      }

	// Create temporary variables to collect the output from the synthesis.
      NetBus tmp_out (scope, tmp_map.size());
      NetBus tmp_ena (scope, tmp_map.size());
      vector<mask_t> tmp_masks (tmp_map.size());

	// Map (and move) the accumulated nex_out for this block
	// to the version that we can pass to the next statement.
	// We will move the result back later.
      for (unsigned idx = 0 ; idx < tmp_out.pin_count() ; idx += 1) {
	    unsigned ptr = nex_map.find_nexus(tmp_map[idx]);
	    ivl_assert(*this, ptr < nex_out.pin_count());
	    connect(tmp_out.pin(idx), nex_out.pin(ptr));
	    nex_out.pin(ptr).unlink();
      }

      if (debug_synth2) {
	    for (unsigned idx = 0 ; idx < nex_map.size() ; idx += 1) {
		  cerr << get_fileline() << ": NetProc::synth_async_block_substatement_: nex_map[" << idx << "] dump link, base=" << nex_map[idx].base << ", wid=" << nex_map[idx].wid << endl;
		  nex_map[idx].lnk.dump_link(cerr, 8);
	     }
	    for (unsigned idx = 0 ; idx < tmp_map.size() ; idx += 1) {
		  cerr << get_fileline() << ": NetProc::synth_async_block_substatement_: tmp_map[" << idx << "] dump link, base=" << tmp_map[idx].base << ", wid=" << tmp_map[idx].wid << endl;
		  tmp_map[idx].lnk.dump_link(cerr, 8);
	     }
	    for (unsigned idx = 0 ; idx < tmp_out.pin_count() ; idx += 1) {
		  cerr << get_fileline() << ": NetProc::synth_async_block_substatement_: tmp_out[" << idx << "] dump link" << endl;
		  tmp_out.pin(idx).dump_link(cerr, 8);
	    }
      }


      bool flag = substmt->synth_async(des, scope, tmp_map, tmp_out, tmp_ena, tmp_masks);

      if (debug_synth2) {
	    cerr << get_fileline() << ": NetProc::synth_async_block_substatement_: "
		  "substmt->synch_async(...) --> " << (flag? "true" : "false")
		 << " for statement at " << substmt->get_fileline() << "." << endl;
      }

      if (!flag) return false;

	// Now map the output from the substatement back to the
	// outputs for this block.
      for (unsigned idx = 0 ;  idx < tmp_out.pin_count() ;  idx += 1) {
	    unsigned ptr = nex_map.find_nexus(tmp_map[idx]);
	    ivl_assert(*this, ptr < nex_out.pin_count());
	    if (debug_synth2) {
		  cerr << get_fileline() << ": NetProc::synth_async_block_substatement_: "
		       << "tmp_out.pin(" << idx << "):" << endl;
		  tmp_out.pin(idx).dump_link(cerr, 8);
	    }
	    connect(nex_out.pin(ptr), tmp_out.pin(idx));

	    merge_sequential_masks(scope, enables.pin(ptr), tmp_ena.pin(idx),
				   bitmasks[ptr], tmp_masks[idx]);
	    merge_sequential_enables(des, scope, enables.pin(ptr), tmp_ena.pin(idx));
      }

      return true;
}

/*
 * Sequential blocks are translated to asynchronous logic by
 * translating each statement of the block, in order, into gates.
 * The nex_out for the block is the union of the nex_out for all
 * the substatements.
 */
bool NetBlock::synth_async(Design*des, NetScope*scope,
			   NexusSet&nex_map, NetBus&nex_out,
			   NetBus&enables, vector<mask_t>&bitmasks)
{
      if (last_ == 0) {
	    return true;
      }

      bool flag = true;
      NetProc*cur = last_;
      do {
	    cur = cur->next_;

	    bool sub_flag = synth_async_block_substatement_(des, scope, nex_map, nex_out,
							    enables, bitmasks, cur);
	    flag = flag && sub_flag;

      } while (cur != last_);

      return flag;
}

/*
 * This function is used to fix up a MUX selector to be no longer than
 * it needs to be. The general idea is that if the selector needs to
 * be only N bits, but is actually M bits, we translate it to this:
 *
 *     osig = { |esig[M-1:N-1], esig[N-2:0] }
 *
 * This obviously implies that (N >= 2) and (M >= N). In the code
 * below, N is sel_need, and M is sel_got (= esig->vector_width()).
 */
static NetNet* mux_selector_reduce_width(Design*des, NetScope*scope,
					 const LineInfo&loc,
					 NetNet*esig, unsigned sel_need)
{
      const unsigned sel_got = esig->vector_width();

      ivl_assert(*esig, sel_got >= sel_need);

	// If the actual width matches the desired width (M==N) then
	// osig is esig itself. We're done.
      if (sel_got == sel_need)
	    return esig;

      if (debug_synth2) {
	    cerr << loc.get_fileline() << ": mux_selector_reduce_width: "
		 << "Reduce selector width=" << sel_got
		 << " to " << sel_need << " bits." << endl;
      }

      ivl_assert(*esig, sel_need >= 2);

	// This is the output signal, osig.
      ivl_variable_type_t osig_data_type = IVL_VT_LOGIC;
      const netvector_t*osig_vec = new netvector_t(osig_data_type, sel_need-1, 0);
      NetNet*osig = new NetNet(scope, scope->local_symbol(),
			       NetNet::TRI, osig_vec);
      osig->local_flag(true);
      osig->set_line(loc);

	// Create the concat: osig = {...,...}
      NetConcat*osig_cat = new NetConcat(scope, scope->local_symbol(),
					 sel_need, 2, !disable_concatz_generation);
      osig_cat->set_line(loc);
      des->add_node(osig_cat);
      connect(osig_cat->pin(0), osig->pin(0));

	// Create the part select esig[N-2:0]...
      NetPartSelect*ps0 = new NetPartSelect(esig, 0, sel_need-1,
					    NetPartSelect::VP);
      ps0->set_line(loc);
      des->add_node(ps0);
      connect(ps0->pin(1), esig->pin(0));

      const netvector_t*ps0_vec = new netvector_t(osig_data_type, sel_need-2, 0);
      NetNet*ps0_sig = new NetNet(scope, scope->local_symbol(),
				  NetNet::TRI, ps0_vec);
      ps0_sig->local_flag(true);
      ps0_sig->set_line(loc);
      connect(ps0_sig->pin(0), ps0->pin(0));

	// osig = {..., esig[N-2:0]}
      connect(osig_cat->pin(1), ps0_sig->pin(0));

	// Create the part select esig[M-1:N-1]
      NetPartSelect*ps1 = new NetPartSelect(esig, sel_need-1,
					    sel_got-sel_need+1,
					    NetPartSelect::VP);
      ps1->set_line(loc);
      des->add_node(ps1);
      connect(ps1->pin(1), esig->pin(0));

      const netvector_t*ps1_vec = new netvector_t(osig_data_type, sel_got-sel_need, 0);
      NetNet*ps1_sig = new NetNet(scope, scope->local_symbol(),
				  NetNet::TRI, ps1_vec);
      ps1_sig->local_flag(true);
      ps1_sig->set_line(loc);
      connect(ps1_sig->pin(0), ps1->pin(0));

	// Create the reduction OR: | esig[M-1:N-1]
      NetUReduce*ered = new NetUReduce(scope, scope->local_symbol(),
				       NetUReduce::OR, sel_got-sel_need+1);
      ered->set_line(loc);
      des->add_node(ered);
      connect(ered->pin(1), ps1_sig->pin(0));

      NetNet*ered_sig = new NetNet(scope, scope->local_symbol(),
				   NetNet::TRI, &netvector_t::scalar_logic);
      ered_sig->local_flag(true);
      ered_sig->set_line(loc);
      connect(ered->pin(0), ered_sig->pin(0));

	// osig = { |esig[M-1:N-1], esig[N-2:0] }
      connect(osig_cat->pin(2), ered_sig->pin(0));

      return osig;
}

bool NetCase::synth_async(Design*des, NetScope*scope,
			  NexusSet&nex_map, NetBus&nex_out,
			  NetBus&enables, vector<mask_t>&bitmasks)
{
      if (type()==NetCase::EQZ || type()==NetCase::EQX)
	    return synth_async_casez_(des, scope, nex_map, nex_out,
				      enables, bitmasks);

	// A dense mux is a good representation for compact ordinary cases, but
	// sparse constant values make its input count proportional to the largest
	// guard rather than the number of clauses. Lower those cases as a chain of
	// exact case-equality comparisons and binary muxes, just as casez/casex are
	// lowered below. Undefined and variable guards also require comparisons to
	// preserve ordinary case matching instead of coercing them through an
	// unsigned mux index.
      bool use_comparison_chain = false;
      bool chain_has_default = false;
      size_t guard_count = 0;
      unsigned long chain_max_guard = 0;
      for (size_t item = 0 ; item < items_.size() ; item += 1) {
	    if (!items_[item].guard) {
		  chain_has_default = true;
		  continue;
	    }
	    guard_count += 1;
	    const NetEConst*guard =
		  dynamic_cast<const NetEConst*>(items_[item].guard);
	    if (!guard || !guard->value().is_defined()) {
		  use_comparison_chain = true;
		  break;
	    }
	    unsigned long guard_value = guard->value().as_ulong();
	    if (guard_value > chain_max_guard)
		  chain_max_guard = guard_value;
      }
      if (!use_comparison_chain && guard_count > 0
	  && chain_max_guard / guard_count >= 4)
	    use_comparison_chain = true;
      unsigned chain_sel_need =
	    max(ceil(log2(chain_max_guard + 1)), 1.0);
      if (!use_comparison_chain && !chain_has_default && guard_count > 0
	  && expr_->expr_width() > chain_sel_need)
	    use_comparison_chain = true;
      if (use_comparison_chain)
	    return synth_async_casez_(des, scope, nex_map, nex_out,
				      enables, bitmasks);

	// Special case: If the case expression is constant, then this
	// is a pattern where the guards are non-constant and tested
	// against a constant case. Handle this as chained conditions
	// instead.
      if (dynamic_cast<NetEConst*> (expr_))
	    return synth_async_casez_(des, scope, nex_map, nex_out,
				      enables, bitmasks);

      ivl_assert(*this, nex_map.size() == nex_out.pin_count());
      ivl_assert(*this, nex_map.size() == enables.pin_count());
      ivl_assert(*this, nex_map.size() == bitmasks.size());

      if (debug_synth2) {
	    cerr << get_fileline() << ": NetCase::synth_async: "
		 << "Selector expression: " << *expr_ << endl;
      }

	/* Synthesize the select expression. */
      NetNet*esig = expr_->synthesize(des, scope, expr_);

      unsigned sel_width = esig->vector_width();
      ivl_assert(*this, sel_width > 0);

      if (debug_synth2) {
	    cerr << get_fileline() << ": NetCase::synth_async: "
		 << "selector width (sel_width) = " << sel_width << endl;
      }

      vector<unsigned> mux_width (nex_out.pin_count());
      for (unsigned idx = 0 ;  idx < nex_out.pin_count() ;  idx += 1) {
	    mux_width[idx] = nex_map[idx].wid;
	    if (debug_synth2) {
		  cerr << get_fileline() << ": NetCase::synth_async: "
		       << "idx=" << idx
		       << ", mux_width[idx]=" << mux_width[idx] << endl;
	    }
      }

	// The incoming nex_out is taken as the input for this
	// statement. Since there are collection of statements
	// that start at this same point, we save all these
	// inputs and reuse them for each statement. Unlink the
	// nex_out now, so we can hook up the mux outputs.
      NetBus statement_input (scope, nex_out.pin_count());
      for (unsigned idx = 0 ; idx < nex_out.pin_count() ; idx += 1) {
	    connect(statement_input.pin(idx), nex_out.pin(idx));
	    nex_out.pin(idx).unlink();
	    if (debug_synth2) {
		  cerr << get_fileline() << ": NetCase::synth_async: "
		       << "statement_input.pin(" << idx << "):" << endl;
		  statement_input.pin(idx).dump_link(cerr, 8);
	    }
      }

	/* Collect all the statements into a map of index to statement.
	   The guard expression it evaluated to be the index of the mux
	   value, and the statement is bound to that index. */

      unsigned long max_guard_value = 0;
      map<unsigned long,NetProc*>statement_map;
      bool has_default_clause = false;
      NetProc*default_statement = 0;

      for (size_t item = 0 ;  item < items_.size() ;  item += 1) {
	    if (items_[item].guard == 0) {
		  has_default_clause = true;
		  default_statement = items_[item].statement;
		  continue;
	    }

	    const NetEConst*ge = dynamic_cast<NetEConst*>(items_[item].guard);
	    if (ge == 0) {
		  cerr << items_[item].guard->get_fileline() << ": sorry: "
		       << "variable case item expressions with a variable "
		       << "case select expression are not supported in "
		       << "synthesis. " << endl;
		  des->errors += 1;
		  return false;
	    }
	    ivl_assert(*this, ge);
	    verinum gval = ge->value();

	    unsigned long sel_idx = gval.as_ulong();

	    if (statement_map[sel_idx]) {
		  cerr << ge->get_fileline() << ": warning: duplicate case "
		       << "value '" << sel_idx << "' detected. This case is "
		       << "unreachable." << endl;
		  delete items_[item].statement;
		  items_[item].statement = 0;
		  continue;
	    }

	    if (sel_idx > max_guard_value)
		  max_guard_value = sel_idx;

	    if (items_[item].statement) {
		  statement_map[sel_idx] = items_[item].statement;
		  continue;
	    }

	      // Handle the special case of an empty statement.
	    statement_map[sel_idx] = this;
      }

	// The minimum selector width is the number of inputs that
	// are selected, rounded up to the nearest power of 2.
      unsigned sel_need = max(ceil(log2(max_guard_value + 1)), 1.0);

	// If the sel_width can select more than just the explicit
	// guard values, and there is a default statement, then adjust
	// the sel_need to allow for the implicit selections.
	if (has_default_clause && (sel_width > sel_need))
	    sel_need += 1;

	// The mux size is always an exact power of 2.
      if (sel_need >= 8*sizeof(unsigned)) {
	   cerr << get_fileline() << ": sorry: mux select width of "
		<< sel_need << " bits is too large for synthesis." << endl;
	   des->errors += 1;
	   return false;
      }
      unsigned mux_size = 1U << sel_need;

      if (debug_synth2) {
	    cerr << get_fileline() << ": NetCase::synth_async: "
		 << "Adjusted mux_size is " << mux_size
		 << " (max_guard_value=" << max_guard_value
		 << ", sel_need=" << sel_need
		 << ", sel_width=" << sel_width << ")." << endl;
      }

      if (sel_width > sel_need) {
	    if (debug_synth2) {
		  cerr << get_fileline() << ": NetCase::synth_async: "
		       << "Selector is " << sel_width << " bits, "
		       << "need only " << sel_need << " bits." << endl;
	    }
	    esig = mux_selector_reduce_width(des, scope, *this, esig, sel_need);
      }

	/* If there is a default clause, synthesize it once and we'll
	   link it in wherever it is needed. If there isn't, create
	   a dummy default to pass on the accumulated nex_out from
	   preceding statements. */
      NetBus default_out (scope, nex_out.pin_count());
      NetBus default_ena (scope, nex_out.pin_count());
      vector<mask_t> default_masks (nex_out.pin_count());

      for (unsigned idx = 0 ; idx < nex_out.pin_count() ; idx += 1) {
	    connect(default_out.pin(idx), statement_input.pin(idx));
	    connect(default_ena.pin(idx), scope->tie_lo());
      }

      if (default_statement) {

	    bool flag = synth_async_block_substatement_(des, scope, nex_map, default_out,
							default_ena, default_masks,
							default_statement);
	    if (!flag) return false;

	    if (debug_synth2) {
		  cerr << get_fileline() << ": NetCase::synth_async: "
		       << "synthesize default clause at " << default_statement->get_fileline()
		       << " is done." << endl;
	    }
      }

      vector<NetMux*> out_mux (nex_out.pin_count());
      vector<NetMux*> ena_mux (nex_out.pin_count());
      vector<bool>  full_case (nex_out.pin_count());
      for (size_t mdx = 0 ; mdx < nex_out.pin_count() ; mdx += 1) {
	    out_mux[mdx] = new NetMux(scope, scope->local_symbol(),
				      mux_width[mdx], mux_size, sel_need);
	    des->add_node(out_mux[mdx]);

	      // The select signal is already synthesized, and is
	      // common for every mux of this case statement. Simply
	      // hook it up.
	    connect(out_mux[mdx]->pin_Sel(), esig->pin(0));

	      // The outputs are in the nex_out, and connected to the
	      // mux Result pins.
	    connect(out_mux[mdx]->pin_Result(), nex_out.pin(mdx));

	      // Make sure the output is now connected to a net. If
	      // not, then create a fake one to carry the net-ness of
	      // the pin.
	    if (out_mux[mdx]->pin_Result().nexus()->pick_any_net() == 0) {
		  ivl_variable_type_t mux_data_type = IVL_VT_LOGIC;
		  const netvector_t*tmp_vec = new netvector_t(mux_data_type, mux_width[mdx]-1,0);
		  NetNet*tmp = new NetNet(scope, scope->local_symbol(),
					  NetNet::WIRE, tmp_vec);
		  tmp->local_flag(true);
		  ivl_assert(*this, tmp->vector_width() != 0);
		  connect(out_mux[mdx]->pin_Result(), tmp->pin(0));
	    }

	      // Create a mux for the enables, but don't hook it up
	      // until we know we need it.
	    ena_mux[mdx] = new NetMux(scope, scope->local_symbol(),
				      1, mux_size, sel_need);

	      // Assume a full case to start with. We'll check this as
	      // we synthesise each clause.
	    full_case[mdx] = true;
      }

	// Sparse case values can make mux_size much larger than the number of
	// explicit clauses. Most mux inputs then share the same default nexuses.
	// Cache those nexuses so connecting each input remains constant-time
	// instead of repeatedly walking an ever-growing circular link list. The
	// default enable is also invariant across all missing selector values.
      vector<Nexus*> default_out_nex (nex_out.pin_count());
      vector<Nexus*> default_ena_nex (nex_out.pin_count());
      vector<bool> default_full_case (nex_out.pin_count());
      for (size_t mdx = 0 ; mdx < nex_out.pin_count() ; mdx += 1) {
	    default_out_nex[mdx] = default_out.pin(mdx).nexus();
	    default_ena_nex[mdx] = default_ena.pin(mdx).nexus();
	    default_full_case[mdx] =
		  default_ena.pin(mdx).is_linked(scope->tie_hi());
      }

      for (unsigned idx = 0 ;  idx < mux_size ;  idx += 1) {

	    map<unsigned long,NetProc*>::const_iterator stmt_it =
		  statement_map.find(idx);
	    NetProc*stmt = stmt_it == statement_map.end()? 0 : stmt_it->second;
	    if (stmt==0) {
		  ivl_assert(*this, default_out.pin_count() == out_mux.size());
		  for (unsigned mdx = 0 ; mdx < nex_out.pin_count() ; mdx += 1) {
			connect(default_out_nex[mdx], out_mux[mdx]->pin_Data(idx));
			connect(default_ena_nex[mdx], ena_mux[mdx]->pin_Data(idx));
			merge_parallel_masks(bitmasks[mdx], default_masks[mdx]);
			if (!default_full_case[mdx])
			      full_case[mdx] = false;
		  }
		  continue;
	    }
	    ivl_assert(*this, stmt);
	    if (stmt == this) {
		    // Handle the special case of an empty statement.
		  ivl_assert(*this, statement_input.pin_count() == out_mux.size());
		  for (unsigned mdx = 0 ; mdx < nex_out.pin_count() ; mdx += 1) {
			connect(out_mux[mdx]->pin_Data(idx), statement_input.pin(mdx));
			connect(ena_mux[mdx]->pin_Data(idx), scope->tie_lo());
			bitmasks[mdx] = mask_t (mux_width[mdx], false);
			full_case[mdx] = false;
		  }
		  continue;
	    }

	    NetBus tmp_out (scope, nex_out.pin_count());
	    NetBus tmp_ena (scope, nex_out.pin_count());
	    for (unsigned mdx = 0 ; mdx < nex_out.pin_count() ; mdx += 1) {
		  connect(tmp_out.pin(mdx), statement_input.pin(mdx));
		  connect(tmp_ena.pin(mdx), scope->tie_lo());
	    }
	    vector<mask_t> tmp_masks (nex_out.pin_count());
	    bool flag = synth_async_block_substatement_(des, scope, nex_map, tmp_out,
							tmp_ena, tmp_masks, stmt);
	    if (!flag) return false;

	    for (size_t mdx = 0 ; mdx < nex_out.pin_count() ; mdx += 1) {
		  connect(out_mux[mdx]->pin_Data(idx), tmp_out.pin(mdx));
		  connect(ena_mux[mdx]->pin_Data(idx), tmp_ena.pin(mdx));
		  merge_parallel_masks(bitmasks[mdx], tmp_masks[mdx]);
		  if (!tmp_ena.pin(mdx).is_linked(scope->tie_hi()))
			full_case[mdx] = false;
	    }
      }

      for (unsigned mdx = 0 ; mdx < nex_out.pin_count() ; mdx += 1) {
	      // Optimize away the enable mux if we have a full case,
	      // otherwise hook it up.
	    if (full_case[mdx]) {
		  connect(enables.pin(mdx), scope->tie_hi());
		  delete ena_mux[mdx];
		  continue;
	    }

	    des->add_node(ena_mux[mdx]);

	    connect(ena_mux[mdx]->pin_Sel(), esig->pin(0));

	    connect(enables.pin(mdx), ena_mux[mdx]->pin_Result());

	    NetNet*tmp = new NetNet(scope, scope->local_symbol(),
				    NetNet::WIRE, &netvector_t::scalar_logic);
	    tmp->local_flag(true);
	    connect(ena_mux[mdx]->pin_Result(), tmp->pin(0));
      }
      return true;
}

/*
 * casez statements are hard to implement as a single wide mux because
 * the test doesn't really map to a select input. Instead, implement
 * it as a chain of binary muxes. This gives the synthesizer more
 * flexibility, and is more typically what is desired from a casez anyhow.
 */
bool NetCase::synth_async_casez_(Design*des, NetScope*scope,
				 NexusSet&nex_map, NetBus&nex_out,
				 NetBus&enables, vector<mask_t>&bitmasks)
{
      ivl_assert(*this, nex_map.size() == nex_out.pin_count());
      ivl_assert(*this, nex_map.size() == enables.pin_count());
      ivl_assert(*this, nex_map.size() == bitmasks.size());

	/* Synthesize the select expression. */
      NetNet*esig = expr_->synthesize(des, scope, expr_);

      unsigned sel_width = esig->vector_width();
      ivl_assert(*this, sel_width > 0);

      vector<unsigned>mux_width (nex_out.pin_count());
      for (unsigned idx = 0 ; idx < nex_out.pin_count() ; idx += 1) {
	    mux_width[idx] = nex_map[idx].wid;
	    if (debug_synth2) {
		  cerr << get_fileline() << ": NetCase::synth_async_casez_: "
		       << "idx=" << idx
		       << ", mux_width[idx]=" << mux_width[idx] << endl;
	    }
      }

	// The incoming nex_out is taken as the input for this
	// statement. Since there are collection of statements
	// that start at this same point, we save all these
	// inputs and reuse them for each statement. Unlink the
	// nex_out now, so we can hook up the mux outputs.
      NetBus statement_input (scope, nex_out.pin_count());
      for (unsigned idx = 0 ; idx < nex_out.pin_count() ; idx += 1) {
	    connect(statement_input.pin(idx), nex_out.pin(idx));
	    nex_out.pin(idx).unlink();
	    if (debug_synth2) {
		  cerr << get_fileline() << ": NetCase::synth_async_casez_: "
		       << "statement_input.pin(" << idx << "):" << endl;
		  statement_input.pin(idx).dump_link(cerr, 8);
	    }

      }

	// Look for a default statement.
      NetProc*default_statement = 0;
      for (size_t item = 0 ; item < items_.size() ; item += 1) {
	    if (items_[item].guard != 0)
		  continue;

	    ivl_assert(*this, default_statement==0);
	    default_statement = items_[item].statement;
      }

	/* If there is a default clause, synthesize it once and we'll
	   link it in wherever it is needed. If there isn't, create
	   a dummy default to pass on the accumulated nex_out from
	   preceding statements. */
      NetBus default_out (scope, nex_out.pin_count());

      for (unsigned idx = 0 ; idx < default_out.pin_count() ; idx += 1)
	    connect(default_out.pin(idx), statement_input.pin(idx));

      if (default_statement) {
	    bool flag = synth_async_block_substatement_(des, scope, nex_map, default_out,
							enables, bitmasks, default_statement);
	    if (!flag) return false;

	    if (debug_synth2) {
		  cerr << get_fileline() << ": NetCase::synth_async_casez_: "
		       << "synthesize default clause at " << default_statement->get_fileline()
		       << " is done." << endl;
	    }
      }

      const netvector_t*condit_type = new netvector_t(IVL_VT_LOGIC, 0, 0);

      NetCaseCmp::kind_t case_kind = NetCaseCmp::EEQ;
      switch (type()) {
	  case NetCase::EQ:
	    case_kind = NetCaseCmp::EEQ;
	    break;
	  case NetCase::EQX:
	    case_kind = NetCaseCmp::XEQ;
	    break;
	  case NetCase::EQZ:
	    case_kind = NetCaseCmp::ZEQ;
	    break;
	  default:
	    assert(0);
      }

	// Process the items from last to first. We generate a
	// true/false mux, with the select being the comparison of
	// the case select with the guard expression. The true input
	// (data1) is the current statement, and the false input is
	// the result of a later statement.
      vector<NetMux*>prev_mux (nex_out.pin_count());
      for (size_t idx = 0 ; idx < items_.size() ; idx += 1) {
	    size_t item = items_.size()-idx-1;
	    if (items_[item].guard == 0)
		  continue;

	    NetProc*stmt = items_[item].statement;

	    NetExpr*guard_expr = items_[item].guard;
	    NetNet*guard = guard_expr->synthesize(des, scope, guard_expr);

	    NetCaseCmp*condit_dev = new NetCaseCmp(scope, scope->local_symbol(),
						   sel_width, case_kind);
	    des->add_node(condit_dev);
	    condit_dev->set_line(*this);
	      // Note that the expression that may have wildcards must
	      // go in the pin(2) input. This is the definition of the
	      // NetCaseCmp statement.
	    connect(condit_dev->pin(1), esig->pin(0));
	    connect(condit_dev->pin(2), guard->pin(0));

	    NetNet*condit = new NetNet(scope, scope->local_symbol(),
				       NetNet::TRI, condit_type);
	    condit->set_line(*this);
	    condit->local_flag(true);
	    connect(condit_dev->pin(0), condit->pin(0));

	      // Synthesize the guarded statement.
	    NetBus tmp_out (scope, nex_out.pin_count());
	    NetBus tmp_ena (scope, nex_out.pin_count());
	    vector<mask_t> tmp_masks (nex_out.pin_count());

	    for (unsigned pdx = 0 ; pdx < nex_out.pin_count() ; pdx += 1)
		  connect(tmp_out.pin(pdx), statement_input.pin(pdx));

	    if (stmt) {
		  bool flag = synth_async_block_substatement_(des, scope, nex_map,
						  tmp_out, tmp_ena, tmp_masks,
						  stmt);
		  if (!flag) return false;
	    }

	    NetBus prev_ena (scope, nex_out.pin_count());
	    for (unsigned mdx = 0 ; mdx < nex_out.pin_count() ; mdx += 1) {
		  NetMux*mux = new NetMux(scope, scope->local_symbol(),
					  mux_width[mdx], 2, 1);
		  des->add_node(mux);
		  mux->set_line(*this);
		  connect(mux->pin_Sel(), condit->pin(0));

		  connect(mux->pin_Data(1), tmp_out.pin(mdx));

		    // If there is a previous mux, then use that as the
		    // false clause input. Otherwise, use the default.
		  if (prev_mux[mdx])
			connect(mux->pin_Data(0), prev_mux[mdx]->pin_Result());
		  else
			connect(mux->pin_Data(0), default_out.pin(mdx));

		    // Make a NetNet for the result.
		  ivl_variable_type_t mux_data_type = IVL_VT_LOGIC;
		  const netvector_t*tmp_vec = new netvector_t(mux_data_type, mux_width[mdx]-1,0);
		  NetNet*tmp = new NetNet(scope, scope->local_symbol(),
					  NetNet::WIRE, tmp_vec);
		  tmp->local_flag(true);
		  tmp->set_line(*this);
		  ivl_assert(*this, tmp->vector_width() != 0);
		  connect(mux->pin_Result(), tmp->pin(0));

		    // This mux becomes the "false" input to the next mux.
		  prev_mux[mdx] = mux;

		  connect(prev_ena.pin(mdx), enables.pin(mdx));
		  enables.pin(mdx).unlink();

		  multiplex_enables(des, scope, condit, tmp_ena.pin(mdx),
				    prev_ena.pin(mdx), enables.pin(mdx));

		  merge_parallel_masks(bitmasks[mdx], tmp_masks[mdx]);
	    }
      }

	// Connect the last mux to the output.
      for (size_t mdx = 0 ; mdx < prev_mux.size() ; mdx += 1)
	    connect(prev_mux[mdx]->pin_Result(), nex_out.pin(mdx));

      return true;
}

/*
 * A condit statement (if (cond) ... else ... ;) infers an A-B mux,
 * with the cond expression acting as a select input. If the cond
 * expression is true, the if_ clause is selected, and if false, the
 * else_ clause is selected.
 */
bool NetCondit::synth_async(Design*des, NetScope*scope,
			    NexusSet&nex_map, NetBus&nex_out,
			    NetBus&enables, vector<mask_t>&bitmasks)
{
	// Handle the unlikely case that both clauses are empty.
      if ((if_ == 0) && (else_ == 0))
	    return true;

      ivl_assert(*this, nex_map.size() == nex_out.pin_count());
      ivl_assert(*this, nex_map.size() == enables.pin_count());
      ivl_assert(*this, nex_map.size() == bitmasks.size());

	// Synthesize the condition. This will act as a select signal
	// for a binary mux.
      NetNet*ssig = expr_->synthesize(des, scope, expr_);
      ivl_assert(*this, ssig);

	// The incoming nex_out is taken as the input for this
	// statement. Since there are two statements that start
	// at this same point, we save all these inputs and reuse
	// them for both statements. Unlink the nex_out now, so
	// we can hook up the mux outputs.
      NetBus statement_input (scope, nex_out.pin_count());
      for (unsigned idx = 0 ; idx < nex_out.pin_count() ; idx += 1) {
	    connect(statement_input.pin(idx), nex_out.pin(idx));
	    nex_out.pin(idx).unlink();
	    if (debug_synth2) {
		  cerr << get_fileline() << ": NetCondit::synth_async: "
		       << "statement_input.pin(" << idx << "):" << endl;
		  statement_input.pin(idx).dump_link(cerr, 8);
	    }
      }

      NetBus a_out (scope, nex_out.pin_count());
      NetBus a_ena (scope, nex_out.pin_count());
      vector<mask_t> a_masks (nex_out.pin_count());
      if (if_) {
	    if (debug_synth2) {
		  cerr << get_fileline() << ": NetCondit::synth_async: "
		       << "Synthesize if clause at " << if_->get_fileline()
		       << endl;
	    }

	    for (unsigned idx = 0 ; idx < a_out.pin_count() ; idx += 1) {
		  connect(a_out.pin(idx), statement_input.pin(idx));
	    }

	    bool flag = synth_async_block_substatement_(des, scope, nex_map, a_out,
							a_ena, a_masks, if_);
	    if (!flag) return false;

      } else {
	    for (unsigned idx = 0 ; idx < a_out.pin_count() ; idx += 1) {
		  connect(a_out.pin(idx), statement_input.pin(idx));
		  connect(a_ena.pin(idx), scope->tie_lo());
	    }
      }

      NetBus b_out(scope, nex_out.pin_count());
      NetBus b_ena(scope, nex_out.pin_count());
      vector<mask_t> b_masks (nex_out.pin_count());
      if (else_) {
	    if (debug_synth2) {
		  cerr << get_fileline() << ": NetCondit::synth_async: "
		       << "Synthesize else clause at " << else_->get_fileline()
		       << endl;
	    }

	    for (unsigned idx = 0 ; idx < b_out.pin_count() ; idx += 1) {
		  connect(b_out.pin(idx), statement_input.pin(idx));
	    }

	    bool flag = synth_async_block_substatement_(des, scope, nex_map, b_out,
							b_ena, b_masks, else_);
	    if (!flag) return false;

      } else {
	    for (unsigned idx = 0 ; idx < b_out.pin_count() ; idx += 1) {
		  connect(b_out.pin(idx), statement_input.pin(idx));
		  connect(b_ena.pin(idx), scope->tie_lo());
	    }
      }

	/* The nex_out output, a_out input, and b_out input all have the
	   same pin count (usually, but not always 1) because they are
	   net arrays of the same dimension. The for loop below creates
	   a NetMux for each pin of the output. (Note that pins may
	   be, in fact usually are, vectors.) */

      for (unsigned idx = 0 ; idx < nex_out.pin_count() ; idx += 1) {

	    bool a_driven = a_out.pin(idx).nexus()->pick_any_net();
	    bool b_driven = b_out.pin(idx).nexus()->pick_any_net();
	    if (!a_driven && !b_driven) {
		  connect(nex_out.pin(idx), statement_input.pin(idx));
		  continue;
	    }

	    merge_parallel_masks(bitmasks[idx], a_masks[idx]);
	    merge_parallel_masks(bitmasks[idx], b_masks[idx]);

	      // If one clause is empty and the other clause unconditionally
	      // drives all bits of the vector, we can rely on the enable
	      // to prevent the flip-flop or latch updating when the empty
	      // clause is selected, and hence don't need a mux.
	    if (!a_driven && all_bits_driven(b_masks[idx])) {
		  connect(nex_out.pin(idx), b_out.pin(idx));
		  continue;
	    }
	    if (!b_driven && all_bits_driven(a_masks[idx])) {
		  connect(nex_out.pin(idx), a_out.pin(idx));
		  continue;
	    }

	      // Guess the mux type from the type of the output.
	    ivl_variable_type_t mux_data_type = IVL_VT_LOGIC;
	    if (const NetNet*tmp = nex_out.pin(idx).nexus()->pick_any_net()) {
		  mux_data_type = tmp->data_type();
	    }

	    unsigned mux_off = 0;
	    unsigned mux_width = nex_map[idx].wid;

	    if (debug_synth2) {
		  cerr << get_fileline() << ": NetCondit::synth_async: "
		       << "Calculated mux_width=" << mux_width
		       << endl;
	    }

	    NetPartSelect*apv = detect_partselect_lval(a_out.pin(idx));
	    if (debug_synth2 && apv) {
		  cerr << get_fileline() << ": NetCondit::synth_async: "
		       << "Assign-to-part apv base=" << apv->base()
		       << ", width=" << apv->width() << endl;
	    }

	    NetPartSelect*bpv = detect_partselect_lval(b_out.pin(idx));
	    if (debug_synth2 && bpv) {
		  cerr << get_fileline() << ": NetCondit::synth_async: "
		       << "Assign-to-part bpv base=" << bpv->base()
		       << ", width=" << bpv->width() << endl;
	    }

	    unsigned mux_lwidth = mux_width;
	    ivl_assert(*this, mux_width != 0);

	    if (apv && bpv && apv->width()==bpv->width() && apv->base()==bpv->base()) {
		    // The a and b sides are both assigning to the
		    // same bits of the output, so we can use that to
		    // create a much narrower mux that only
		    // manipulates the width of the part.
		  mux_width = apv->width();
		  mux_off = apv->base();
		  a_out.pin(idx).unlink();
		  b_out.pin(idx).unlink();
		  connect(a_out.pin(idx), apv->pin(0));
		  connect(b_out.pin(idx), bpv->pin(0));
		  delete apv;
		  delete bpv;
	    } else {
		    // The part selects are of no use. Forget them.
		  if (apv) delete apv;
		  if (bpv) delete bpv;
	    }

	    NetMux*mux = new NetMux(scope, scope->local_symbol(),
				    mux_width, 2, 1);
	    mux->set_line(*this);
	    des->add_node(mux);

	    const netvector_t*tmp_type = 0;
	    if (mux_width==1)
		  tmp_type = new netvector_t(mux_data_type);
	    else
		  tmp_type = new netvector_t(mux_data_type, mux_width-1,0);

	      // Bind some temporary signals to carry pin type.
	    NetNet*otmp = new NetNet(scope, scope->local_symbol(),
				     NetNet::WIRE, tmp_type);
	    otmp->local_flag(true);
	    otmp->set_line(*this);
	    connect(mux->pin_Result(),otmp->pin(0));

	    connect(mux->pin_Sel(),   ssig->pin(0));
	    connect(mux->pin_Data(1), a_out.pin(idx));
	    connect(mux->pin_Data(0), b_out.pin(idx));

	      // If we are only muxing a part of the output vector, make a
	      // NetSubstitute to blend the mux output with the accumulated
	      // output from previous statements.
	    if (mux_width < mux_lwidth) {
		  tmp_type = new netvector_t(mux_data_type, mux_lwidth-1,0);

		  NetNet*itmp = statement_input.pin(idx).nexus()->pick_any_net();
		  if (itmp == 0) {
			itmp = new NetNet(scope, scope->local_symbol(),
					  NetNet::WIRE, tmp_type);
			itmp->local_flag(true);
			itmp->set_line(*this);
			connect(itmp->pin(0), statement_input.pin(idx));
		  }

		  NetNet*tmp = new NetNet(scope, scope->local_symbol(),
					  NetNet::WIRE, tmp_type);
		  tmp->local_flag(true);
		  tmp->set_line(*this);
		  NetSubstitute*ps = new NetSubstitute(itmp, otmp, mux_lwidth, mux_off);
		  des->add_node(ps);
		  connect(ps->pin(0), tmp->pin(0));
		  otmp = tmp;
	    }

	    connect(nex_out.pin(idx), otmp->pin(0));
      }

      for (unsigned idx = 0 ; idx < nex_out.pin_count() ; idx += 1) {
	    multiplex_enables(des, scope, ssig, a_ena.pin(idx), b_ena.pin(idx), enables.pin(idx));
      }

      return true;
}

bool NetEvWait::synth_async(Design*des, NetScope*scope,
			    NexusSet&nex_map, NetBus&nex_out,
			    NetBus&enables, vector<mask_t>&bitmasks)
{
      bool flag = statement_->synth_async(des, scope, nex_map, nex_out, enables, bitmasks);
      return flag;
}

bool NetForLoop::synth_async(Design*des, NetScope*scope,
			     NexusSet&nex_map, NetBus&nex_out,
			     NetBus&enables, vector<mask_t>&bitmasks)
{
      if (!index_) {
	    cerr << get_fileline() << ": sorry: Unable to synthesize for-loop without explicit index variable." << endl;
	    return false;
      }

      if (!step_statement_) {
	    cerr << get_fileline() << ": sorry: Unable to synthesize for-loop without for_step statement." << endl;
	    return false;
      }

      ivl_assert(*this, index_ && init_expr_);
      if (debug_synth2) {
	    cerr << get_fileline() << ": NetForLoop::synth_async: "
		 << "Index variable is " << index_->name() << endl;
	    cerr << get_fileline() << ": NetForLoop::synth_async: "
		 << "Initialization expression: " << *init_expr_ << endl;
      }

	// Get the step assignment statement and break it into the
	// l-value (should be the index) and the r-value, which is the
	// step expressions.
      NetAssign*step_assign = dynamic_cast<NetAssign*> (step_statement_);
      char assign_operator = step_assign->assign_operator();
      ivl_assert(*this, step_assign);
      const NetExpr*step_expr = step_assign->rval();

	// Tell the scope that this index value is like a genvar.
      LocalVar index_var;
      index_var.nwords = 0;

        // A nested procedural loop inherits the already-unrolled values of
        // its enclosing loop indices. Keep the outer context live while the
        // inner loop adds and advances its own index.
      map<perm_string,LocalVar> saved_index_args = scope->loop_index_tmp;
      NetNet*saved_index_net = scope->loop_index_net_tmp;
      map<NetNet*,perm_string> saved_index_nets =
	    scope->loop_index_nets_tmp;
      perm_string saved_genvar = scope->genvar_tmp;
      long saved_genvar_value = scope->genvar_tmp_val;
      map<perm_string,LocalVar> index_args = saved_index_args;

	// Calculate the initial value for the index.
      index_var.value = init_expr_->evaluate_function(*this, index_args);
      ivl_assert(*this, index_var.value);
	// The declaration supplies the assignment context for the initializer.
	// Preserve it when constant evaluation returns a self-determined literal.
      index_var.value->cast_signed(index_->get_signed());
      index_args[index_->name()] = index_var;

      for (;;) {
	      // Evaluate the condition expression. If it is false,
	      // then we are going to break out of this synthesis loop.
	    NetExpr*tmp = condition_->evaluate_function(*this, index_args);
	    ivl_assert(*this, tmp);

	    long cond_value;
	    bool rc = eval_as_long(cond_value, tmp);
	    ivl_assert(*this, rc);
	    delete tmp;
	    if (!cond_value) break;

	    scope->genvar_tmp = index_->name();
	    rc = eval_as_long(scope->genvar_tmp_val, index_var.value);
	    ivl_assert(*this, rc);

	    if (debug_synth2) {
		  cerr << get_fileline() << ": NetForLoop::synth_async: "
		       << "Synthesis iteration with " << index_->name()
		       << "=" << *index_var.value << endl;
	    }

	      // Synthesize the iterated expression. Stash the loop
	      // index value so that the substatements can see this
	      // value and use it during its own synthesis.
	    scope->loop_index_tmp = index_args;
	    scope->loop_index_net_tmp = index_;
	    scope->loop_index_nets_tmp[index_] = index_->name();

	    NetBus tmp_ena (scope, nex_out.pin_count());
	    vector<mask_t> tmp_masks (nex_out.pin_count());

	    rc = synth_async_block_substatement_(des, scope, nex_map, nex_out,
						 tmp_ena, tmp_masks, statement_);

	    for (unsigned idx = 0 ; idx < nex_out.pin_count() ; idx += 1) {
		  merge_sequential_masks(scope, enables.pin(idx), tmp_ena.pin(idx),
					 bitmasks[idx], tmp_masks[idx]);
		  merge_sequential_enables(
			des, scope, enables.pin(idx), tmp_ena.pin(idx));
	    }

	    scope->loop_index_tmp = saved_index_args;
	    scope->loop_index_net_tmp = saved_index_net;
	    scope->loop_index_nets_tmp = saved_index_nets;
	    scope->genvar_tmp = saved_genvar;
	    scope->genvar_tmp_val = saved_genvar_value;

	      // Evaluate the step_expr to generate the next index value.
	    tmp = step_expr->evaluate_function(*this, index_args);
	    ivl_assert(*this, tmp);

	      // If there is an assign_operator, then replace the
	      // index_var.value with (value <op> tmp) and evaluate
	      // that to get the next value. "value" is the existing
	      // value, and "tmp" is the step value. We are replacing
	      // (value += tmp) with (value = value + tmp) and
	      // evaluating it.
	    switch (assign_operator) {
		case 0:
		  break;
		case '+':
		  index_var.value = new NetEBAdd('+', tmp, index_var.value,
					    32, true);
		  tmp = index_var.value->evaluate_function(*this, index_args);
		  break;
		case '-':
		    // Subtraction is not commutative: i -= step and i-- mean
		    // next = current - step, not step - current. Reversing these
		    // operands makes descending loops alternate forever.
		  index_var.value = new NetEBAdd('-', index_var.value, tmp,
					    32, true);
		  tmp = index_var.value->evaluate_function(*this, index_args);
		  break;

		default:
		  cerr << get_fileline() << ": internal error: "
		       << "NetForLoop::synth_async: What to do with assign_operator=" << assign_operator << endl;
		  ivl_assert(*this, 0);
	    }
	    ivl_assert(*this, tmp);
	      // Constant binary evaluation returns a value-sized expression, but
	      // the loop variable's declared signedness is the context for the
	      // next condition. Without restoring it, -1 from a signed int loop
	      // becomes 32'hffff_ffff and `i >= 0' never terminates.
	    tmp->cast_signed(index_->get_signed());
	    delete index_var.value;
	    index_var.value = tmp;
	    index_args[index_->name()] = index_var;
      }

      delete index_var.value;

	// The loop may have zero iterations, so restore the enclosing context
	// here as well as after each synthesized iteration.
      scope->loop_index_tmp = saved_index_args;
      scope->loop_index_net_tmp = saved_index_net;
      scope->loop_index_nets_tmp = saved_index_nets;
      scope->genvar_tmp = saved_genvar;
      scope->genvar_tmp_val = saved_genvar_value;

      return true;
}

/*
 * This method is called when the process is shown to be
 * asynchronous. Figure out the nexus set of outputs from this
 * process, and pass that to the synth_async method for the statement
 * of the process. The statement will connect its output to the
 * nex_out set, using the nex_map as a guide. Starting from the top,
 * the nex_map is the same as the nex_map.
 */
bool NetProcTop::synth_async(Design*des)
{
      NexusSet nex_set;
      statement_->nex_output(nex_set);

      if (debug_synth2) {
	    cerr << get_fileline() << ": NetProcTop::synth_async: "
		 << "Process has " << nex_set.size() << " outputs." << endl;
      }

      NetBus nex_out (scope(), nex_set.size());
      NetBus enables (scope(), nex_set.size());
      vector<NetProc::mask_t> bitmasks (nex_set.size());
      vector<NetProc::mask_t> process_write_masks(nex_set.size());
      for (unsigned idx = 0; idx < nex_set.size(); idx += 1)
	    process_write_masks[idx].resize(nex_set[idx].wid, false);

	// Save links to the initial nex_out. These will be used later
	// to detect floating part-substitute and mux inputs that need
	// to be tied off.
      NetBus nex_in (scope(), nex_out.pin_count());
      for (unsigned idx = 0 ; idx < nex_out.pin_count() ; idx += 1)
	    connect(nex_in.pin(idx), nex_out.pin(idx));

      bool flag = false;
      {
	    synth_write_mask_context_t context = {
		  &nex_set, &process_write_masks
	    };
	    synth_write_mask_guard_t guard(&context);
	    flag = statement_->synth_async(
		  des, scope(), nex_set, nex_out, enables, bitmasks);
      }
      if (!flag) return false;

      flag = tie_off_floating_inputs_(des, nex_set, nex_in, bitmasks, false,
				      &enables, &process_write_masks);
      if (!flag) return false;

      for (unsigned idx = 0 ;  idx < nex_set.size() ;  idx += 1) {
	    if (!any_bits_driven(process_write_masks[idx]))
		  continue;

	    if (!all_bits_driven(bitmasks[idx])) {
		  ivl_assert(*this,
			enables.pin(idx).is_linked(scope()->tie_hi())
			&& all_process_writes_are_driven(
			      bitmasks[idx], process_write_masks[idx]));
		  connect_synthesized_process_output(
			des, scope(), *this, nex_set[idx].wid,
			nex_set[idx].lnk, nex_out.pin(idx));
		  continue;
	    }

	    if (enables.pin(idx).is_linked(scope()->tie_hi())) {
		  connect_synthesized_process_output(
			des, scope(), *this, nex_set[idx].wid,
			nex_set[idx].lnk, nex_out.pin(idx));
	    } else {
		  bool intentional_latch = type() == IVL_PR_ALWAYS_LATCH;
		  if (!intentional_latch) {
			cerr << get_fileline() << ": warning: "
			     << "A latch has been inferred for '"
			     << nex_set[idx].lnk.nexus()->pick_any_net()->name()
			     << "'." << endl;
		  }

		  if (!intentional_latch
		      && enables.pin(idx).nexus()->pick_any_net()->local_flag()) {
			cerr << get_fileline() << ": warning: The latch "
			        "enable is connected to a synthesized "
			        "expression. The latch may be sensitive "
			        "to glitches." << endl;
		  }

		  if (debug_synth2) {
			cerr << get_fileline() << ": debug: "
			     << "Top level making a "
			     << nex_set[idx].wid << "-wide "
			     << "NetLatch device." << endl;
		  }

		  NetLatch*latch = new NetLatch(scope(), scope()->local_symbol(),
						nex_set[idx].wid);
		  des->add_node(latch);
		  latch->set_line(*this);

		  NetNet*tmp = nex_out.pin(idx).nexus()->pick_any_net();
		  tmp->set_line(*this);
		  assert(tmp);

		  tmp = crop_to_width(des, tmp, latch->width());

		  connect(nex_set[idx].lnk, latch->pin_Q());
		  connect(tmp->pin(0), latch->pin_Data());

		  bool is_linked_tmp = enables.pin(idx).is_linked();
		  assert (is_linked_tmp);
		  connect(enables.pin(idx), latch->pin_Enable());
	    }
      }

      claim_synthesized_process_outputs(
	    des, *this, nex_set, process_write_masks);
      synthesized_design_ = des;
      return true;
}


bool NetProc::synth_sync(Design*des, NetScope*scope,
			 bool& /* ff_negedge */,
			 NetNet* /* ff_clk */, NetBus&ff_ce,
			 NetBus& /* ff_aclr*/, NetBus& /* ff_aset*/,
			 vector<verinum>& /*ff_aset_value*/,
			 NexusSet&nex_map, NetBus&nex_out,
			 vector<mask_t>&bitmasks,
			 const vector<NetEvProbe*>&events)
{
      if (events.size() > 0) {
	    cerr << get_fileline() << ": error: Events are unaccounted"
		 << " for in process synthesis." << endl;
	    des->errors += 1;
      }

      if (debug_synth2) {
	    cerr << get_fileline() << ": NetProc::synth_sync: "
		 << "This statement is an async input to a sync process." << endl;
      }

	/* Synthesize the input to the DFF. */
      return synth_async(des, scope, nex_map, nex_out, ff_ce, bitmasks);
}

/*
 * This method is called when a block is encountered near the surface
 * of a synchronous always statement. For example, this code will be
 * invoked for input like this:
 *
 *     always @(posedge clk...) begin
 *	     <statement1>
 *	     <statement2>
 *	     ...
 *     end
 *
 * This needs to be split into a DFF bank for each statement, because
 * the statements may each infer different reset and enables signals.
 */
bool NetBlock::synth_sync(Design*des, NetScope*scope,
			  bool&ff_negedge,
			  NetNet*ff_clk, NetBus&ff_ce,
			  NetBus&ff_aclr,NetBus&ff_aset,
			  vector<verinum>&ff_aset_value,
			  NexusSet&nex_map, NetBus&nex_out,
			  vector<mask_t>&bitmasks,
			  const vector<NetEvProbe*>&events_in)
{
      if (debug_synth2) {
	    cerr << get_fileline() << ": NetBlock::synth_sync: "
		 << "Examine this block for synchronous logic." << endl;
      }

      if (last_ == 0) {
	    return true;
      }

      bool flag = true;

      NetProc*cur = last_;
      do {
	    cur = cur->next_;

	      // Create a temporary nex_map for the substatement.
	    NexusSet tmp_map;
	    cur->nex_output(tmp_map);

	      // Create temporary variables to collect the output from the synthesis.
	    NetBus tmp_out (scope, tmp_map.size());
	    NetBus tmp_ce  (scope, tmp_map.size());
	    vector<mask_t> tmp_masks (tmp_map.size());

	      // Map (and move) the accumulated nex_out for this block
	      // to the version that we can pass to the next statement.
	      // We will move the result back later.
	    for (unsigned idx = 0 ; idx < tmp_out.pin_count() ; idx += 1) {
		  unsigned ptr = nex_map.find_nexus(tmp_map[idx]);
		  ivl_assert(*this, ptr < nex_out.pin_count());
		  connect(tmp_out.pin(idx), nex_out.pin(ptr));
		  nex_out.pin(ptr).unlink();
	    }

	      /* Now go on with the synchronous synthesis for this
		 subset of the statement. The tmp_map is the output
		 nexa that we expect, and the tmp_out is where we want
		 those outputs connected. */
	    bool ok_flag = cur->synth_sync(des, scope,
					   ff_negedge, ff_clk, tmp_ce,
					   ff_aclr, ff_aset, ff_aset_value,
					   tmp_map, tmp_out, tmp_masks,
					   events_in);
	    flag = flag && ok_flag;

	    if (ok_flag == false)
		  continue;

	      // Now map the output from the substatement back to the
	      // outputs for this block.
	    for (unsigned idx = 0 ;  idx < tmp_out.pin_count() ; idx += 1) {
		  unsigned ptr = nex_map.find_nexus(tmp_map[idx]);
		  ivl_assert(*this, ptr < nex_out.pin_count());
		  connect(nex_out.pin(ptr), tmp_out.pin(idx));

		  merge_sequential_masks(scope, ff_ce.pin(ptr), tmp_ce.pin(idx),
					 bitmasks[ptr], tmp_masks[idx]);
		  merge_sequential_enables(
			des, scope, ff_ce.pin(ptr), tmp_ce.pin(idx));
	    }

      } while (cur != last_);

      if (debug_synth2) {
	    cerr << get_fileline() << ": NetBlock::synth_sync: "
		 << "Done Examining this block for synchronous logic." << endl;
      }

      return flag;
}

/*
 * This method handles the case where I find a conditional near the
 * surface of a synchronous thread. This conditional can be a CE or an
 * asynchronous set/reset, depending on whether the pin of the
 * expression is connected to an event, or not.
 */
bool NetCondit::synth_sync(Design*des, NetScope*scope,
			   bool&ff_negedge,
			   NetNet*ff_clk, NetBus&ff_ce,
			   NetBus&ff_aclr,NetBus&ff_aset,
			   vector<verinum>&ff_aset_value,
			   NexusSet&nex_map, NetBus&nex_out,
			   vector<mask_t>&bitmasks,
			   const vector<NetEvProbe*>&events_in)
{
	/* First try to turn the condition expression into an
	   asynchronous set/reset. If the condition expression has
	   inputs that are included in the sensitivity list, then it
	   is likely intended as an asynchronous input. */

      NexusSet*expr_input = expr_->nex_input();
      assert(expr_input);
      for (unsigned idx = 0 ;  idx < events_in.size() ;  idx += 1) {

	    NetEvProbe*ev = events_in[idx];
	    NexusSet pin_set;
	    pin_set.add(ev->pin(0).nexus(), 0, 0);

	    if (! expr_input->contains(pin_set))
		  continue;

	      // Synthesize the set/reset input expression.
	    NetNet*rst = expr_->synthesize(des, scope, expr_);
	    ivl_assert(*this, rst->pin_count() == 1);

	      // Check that the edge used on the set/reset input is correct.
	    switch (ev->edge()) {
	      case NetEvProbe::POSEDGE:
		  if (ev->pin(0).nexus() != rst->pin(0).nexus()) {
			cerr << get_fileline() << ": error: "
			     << "Condition for posedge asynchronous set/reset "
			     << "must exactly match the event expression." << endl;
			des->errors += 1;
			return false;
		  }
		  break;
	      case NetEvProbe::NEGEDGE: {
		  bool is_inverter = false;
		  NetNode*node = rst->pin(0).nexus()->pick_any_node();
		  if (const NetLogic*gate = dynamic_cast<NetLogic*>(node)) {
			if (gate->type() == NetLogic::NOT)
				is_inverter = true;
		  }
		  if (const NetUReduce*gate = dynamic_cast<NetUReduce*>(node)) {
			if (gate->type() == NetUReduce::NOR)
				is_inverter = true;
		  }
		  if (!is_inverter || ev->pin(0).nexus() != node->pin(1).nexus()) {
			cerr << get_fileline() << ": error: "
			     << "Condition for negedge asynchronous set/reset must be "
			     << "a simple inversion of the event expression." << endl;
			des->errors += 1;
			return false;
		  }
		  break;
	      }
	      default:
		  cerr << get_fileline() << ": error: "
		       << "Asynchronous set/reset event must be "
		       << "edge triggered." << endl;
		  des->errors += 1;
		  return false;
	    }

	      // Synthesize the true clause to figure out what kind of
	      // set/reset we have. This should synthesize down to a
	      // constant. If not, we have an asynchronous LOAD, a
	      // very different beast.
	    ivl_assert(*this, if_);
	    NetBus tmp_out(scope, nex_out.pin_count());
	    NetBus tmp_ena(scope, nex_out.pin_count());
	    NetBus tmp_in(scope, nex_out.pin_count());
	    for (unsigned pin = 0; pin < tmp_in.pin_count(); pin += 1)
		  connect(tmp_in.pin(pin), tmp_out.pin(pin));
	    vector<mask_t> tmp_masks (nex_out.pin_count());
	    bool flag = if_->synth_async(des, scope, nex_map, tmp_out, tmp_ena, tmp_masks);
	    if (!flag) return false;
	    vector<mask_t> conditional_write_masks(nex_map.size());
	    collect_process_write_masks(this, nex_map,
				    conditional_write_masks);

	    ivl_assert(*this, tmp_out.pin_count() == ff_aclr.pin_count());
	    ivl_assert(*this, tmp_out.pin_count() == ff_aset.pin_count());
	    vector<bool> unreset_outputs(tmp_out.pin_count(), false);

	    for (unsigned pin = 0 ; pin < tmp_out.pin_count() ; pin += 1) {
		  const Nexus*rst_nex = tmp_out.pin(pin).nexus();
		  if (!any_bits_driven(tmp_masks[pin])) {
			unreset_outputs[pin] = true;
			continue;
		  }

		  if (!all_process_writes_are_driven(
			tmp_masks[pin], conditional_write_masks[pin])) {
			cerr << get_fileline() << ": sorry: Not all bits written "
			     << "by this process to '"
			     << nex_map[pin].lnk.nexus()->pick_any_net()->name()
			     << "' are asynchronously set or reset. This is "
			     << "not currently supported in synthesis." << endl;
			des->errors += 1;
			return false;
		  }

		    // A partial packed write is represented by a substitute node
		    // whose untouched input starts floating. Tie that input low so
		    // the complete reset vector is constant; the process-output mask
		    // later hides these non-owned bits from the shared variable.
		  if (!all_bits_driven(tmp_masks[pin])
		      && tmp_in.pin(pin).nexus()->has_floating_input()) {
			NetNet*zero = make_const_0(des, scope, nex_map[pin].wid);
			connect(tmp_in.pin(pin), zero->pin(0));
		  }

		  if (! rst_nex->drivers_constant() ||
		      ! tmp_ena.pin(pin).is_linked(scope->tie_hi()) ) {
			cerr << get_fileline() << ": sorry: Asynchronous load "
			     << "is not currently supported in synthesis." << endl;
			des->errors += 1;
			return false;
		  }

		  if (ff_aclr.pin(pin).is_linked() ||
		      ff_aset.pin(pin).is_linked()) {
			cerr << get_fileline() << ": sorry: More than "
				"one asynchronous set/reset clause is "
				"not currently supported in synthesis." << endl;
			des->errors += 1;
			return false;
		  }

		  verinum rst_drv = rst_nex->driven_vector();

		  verinum zero (verinum::V0, rst_drv.len());
		  verinum ones (verinum::V1, rst_drv.len());

		  if (rst_drv==zero) {
			  // Don't yet support multiple asynchronous reset inputs.
			ivl_assert(*this, ! ff_aclr.pin(pin).is_linked());

			ivl_assert(*this, rst->pin_count()==1);
			connect(ff_aclr.pin(pin), rst->pin(0));

		  } else {
			  // Don't yet support multiple asynchronous set inputs.
			ivl_assert(*this, ! ff_aset.pin(pin).is_linked());

			ivl_assert(*this, rst->pin_count()==1);
			connect(ff_aset.pin(pin), rst->pin(0));
			if (rst_drv!=ones)
			      ff_aset_value[pin] = rst_drv;
		  }
	    }

	    if (else_ == 0)
		  return true;

	    vector<NetEvProbe*> events;
	    for (unsigned jdx = 0 ;  jdx < events_in.size() ;  jdx += 1) {
		  if (jdx != idx)
			events.push_back(events_in[jdx]);
	    }
	    bool else_flag = else_->synth_sync(des, scope,
					 ff_negedge, ff_clk, ff_ce,
					 ff_aclr, ff_aset, ff_aset_value,
					 nex_map, nex_out, bitmasks, events);
	    if (!else_flag)
		  return false;

	      // An output omitted from the asynchronous branch is an ordinary
	      // unreset flip-flop in the same process. It may update only while
	      // the reset condition is false, including clocks that occur while
	      // reset remains asserted.
	    NetBus qualified_ce(scope, ff_ce.pin_count());
	    for (unsigned pin = 0; pin < ff_ce.pin_count(); pin += 1) {
		  if (!unreset_outputs[pin] || !ff_ce.pin(pin).is_linked())
			continue;
		  qualify_enable(des, scope, rst, false, NetLogic::AND,
				 ff_ce.pin(pin), qualified_ce.pin(pin));
		  ff_ce.pin(pin).unlink();
		  connect(ff_ce.pin(pin), qualified_ce.pin(pin));
	    }
	    return true;
      }

      delete expr_input;

#if 0
	/* Detect the case that this is a *synchronous* set/reset. It
	   is not asynchronous because we know the condition is not
	   included in the sensitivity list, but if the if_ case is
	   constant (has no inputs) then we can model this as a
	   synchronous set/reset.

	   This is only synchronous set/reset if there is a true and a
	   false clause, and no inputs. The "no inputs" requirement is
	   met if the assignments are of all constant values. */
      assert(if_ != 0);
      NexusSet*a_set = if_->nex_input();

      if ((a_set->count() == 0) && if_ && else_) {

	    NetNet*rst = expr_->synthesize(des);
	    assert(rst->pin_count() == 1);

	      /* Synthesize the true clause to figure out what
		 kind of set/reset we have. */
	    NetNet*asig = new NetNet(scope, scope->local_symbol(),
				     NetNet::WIRE, nex_map->pin_count());
	    asig->local_flag(true);
	    bool flag = if_->synth_async(des, scope, nex_map, asig);

	    if (!flag) {
		  /* This path leads nowhere */
		  delete asig;
	    } else {
		  assert(asig->pin_count() == ff->width());

		    /* Collect the set/reset value into a verinum. If
		       this turns out to be entirely 0 values, then
		       use the Sclr input. Otherwise, use the Aset
		       input and save the set value. */
		  verinum tmp (verinum::V0, ff->width());
		  for (unsigned bit = 0 ;  bit < ff->width() ;	bit += 1) {

			assert(asig->pin(bit).nexus()->drivers_constant());
			tmp.set(bit, asig->pin(bit).nexus()->driven_value());
		  }

		  assert(tmp.is_defined());
		  if (tmp.is_zero()) {
			connect(ff->pin_Sclr(), rst->pin(0));

		  } else {
			connect(ff->pin_Sset(), rst->pin(0));
			ff->sset_value(tmp);
		  }

		  delete a_set;

		  assert(else_ != 0);
		  flag = else_->synth_sync(des, scope, ff, nex_map,
					   nex_out, std::vector<NetEvProbe*>())
			&& flag;
		  DEBUG_SYNTH2_EXIT("NetCondit",flag)
		  return flag;
	    }
      }

      delete a_set;
#endif

#if 0
	/* This gives a false positive for strange coding styles,
	   such as ivltests/conditsynth3.v. */

	/* Failed to find an asynchronous set/reset, so any events
	   input are probably in error. */
      if (events_in.size() > 0) {
	    cerr << get_fileline() << ": error: Events are unaccounted"
		 << " for in process synthesis." << endl;
	    des->errors += 1;
      }
#endif

      return synth_async(des, scope, nex_map, nex_out, ff_ce, bitmasks);
}

bool NetEvWait::synth_sync(Design*des, NetScope*scope,
			   bool&ff_negedge,
			   NetNet*ff_clk, NetBus&ff_ce,
			   NetBus&ff_aclr,NetBus&ff_aset,
			   vector<verinum>&ff_aset_value,
			   NexusSet&nex_map, NetBus&nex_out,
			   vector<mask_t>&bitmasks,
			   const vector<NetEvProbe*>&events_in)
{
      if (debug_synth2) {
	    cerr << get_fileline() << ": NetEvWait::synth_sync: "
		 << "Synchronous process an event statement." << endl;
      }

      if (events_in.size() > 0) {
	    cerr << get_fileline() << ": error: Events are unaccounted"
		 << " for in process synthesis." << endl;
	    des->errors += 1;
      }

      assert(events_in.size() == 0);

	/* This can't be other than one unless there are named events,
	   which I cannot synthesize. */
      ivl_assert(*this, events_.size() == 1);
      NetEvent*ev = events_[0];

      assert(ev->nprobe() >= 1);
      vector<NetEvProbe*>events (ev->nprobe() - 1);

	/* Get the input set from the substatement. This will be used
	   to figure out which of the probes is the clock. */
      const NexusSet*statement_input = statement_ -> nex_input();

	/* Search for a clock input. The clock input is the edge event
	   that is not also an input to the substatement. */
      NetEvProbe*pclk = 0;
      unsigned event_idx = 0;
      for (unsigned idx = 0 ;  idx < ev->nprobe() ;  idx += 1) {
	    NetEvProbe*tmp = ev->probe(idx);
	    assert(tmp->pin_count() == 1);

	    NexusSet tmp_nex;
	    tmp_nex .add( tmp->pin(0).nexus(), 0, 0 );

	    if (! statement_input ->contains(tmp_nex)) {
		  if (pclk != 0) {
			cerr << get_fileline() << ": error: Too many "
			     << "clocks for synchronous logic." << endl;
			cerr << get_fileline() << ":	  : Perhaps an"
			     << " asynchronous set/reset is misused?" << endl;
			des->errors += 1;
		  }
		  pclk = tmp;

	    } else {
		  events[event_idx++] = tmp;
	    }
      }

      if (pclk == 0) {
	    cerr << get_fileline() << ": error: None of the edges"
		 << " are valid clock inputs." << endl;
	    cerr << get_fileline() << ":      : Perhaps the clock"
		 << " is read by a statement or expression?" << endl;
	    des->errors += 1;
	    return false;
      }

      if (debug_synth2) {
	    cerr << get_fileline() << ": NetEvWait::synth_sync: "
		 << "Found and synthesized the FF clock." << endl;
      }

      connect(ff_clk->pin(0), pclk->pin(0));
      if (pclk->edge() == NetEvProbe::NEGEDGE) {
	    ff_negedge = true;

	    if (debug_synth2) {
		  cerr << get_fileline() << ": debug: "
		       << "Detected a NEGEDGE clock for the synthesized ff."
		       << endl;
	    }
      }

	/* Synthesize the input to the DFF. */
      return statement_->synth_sync(des, scope,
				    ff_negedge, ff_clk, ff_ce,
				    ff_aclr, ff_aset, ff_aset_value,
				    nex_map, nex_out, bitmasks, events);
}

/*
 * This method is called for a process that is determined to be
 * synchronous. Create a NetFF device to hold the output from the
 * statement, and synthesize that statement in place.
 */
bool NetProcTop::synth_sync(Design*des)
{
      if (debug_synth2) {
	    cerr << get_fileline() << ": NetProcTop::synth_sync: "
		 << "Process is apparently synchronous. Making NetFFs."
		 << endl;
      }

      NexusSet nex_set;
      statement_->nex_output(nex_set);
      vector<verinum> aset_value(nex_set.size());
      vector<NetProc::mask_t> process_write_masks(nex_set.size());
      for (unsigned idx = 0; idx < nex_set.size(); idx += 1)
	    process_write_masks[idx].resize(nex_set[idx].wid, false);

	/* Make a model FF that will connect to the first item in the
	   set, and will also take the initial connection of clocks
	   and resets. */

	// Create a net to carry the clock for the synthesized FFs.
      NetNet*clock = new NetNet(scope(), scope()->local_symbol(),
				NetNet::TRI, &netvector_t::scalar_logic);
      clock->local_flag(true);
      clock->set_line(*this);

      NetBus ce    (scope(), nex_set.size());
      NetBus nex_d (scope(), nex_set.size());
      NetBus nex_q (scope(), nex_set.size());
      NetBus aclr  (scope(), nex_set.size());
      NetBus aset  (scope(), nex_set.size());
      vector<NetProc::mask_t> bitmasks (nex_set.size());

	// Save links to the initial nex_d. These will be used later
	// to detect floating part-substitute and mux inputs that need
	// to be tied off.
      NetBus nex_in (scope(), nex_d.pin_count());
      for (unsigned idx = 0 ; idx < nex_in.pin_count() ; idx += 1)
	    connect(nex_in.pin(idx), nex_d.pin(idx));

	// The Q of the NetFF devices is connected to the output that
	// we are. The nex_q is a bundle of the outputs.
      for (unsigned idx = 0 ; idx < nex_q.pin_count() ; idx += 1)
	    connect(nex_q.pin(idx), nex_set[idx].lnk);

	// Connect the D of the NetFF devices later.

      /* Synthesize the input to the DFF. */
      bool negedge = false;
      bool flag = false;
      {
	    synth_write_mask_context_t context = {
		  &nex_set, &process_write_masks
	    };
	    synth_write_mask_guard_t guard(&context);
	    flag = statement_->synth_sync(des, scope(),
					    negedge, clock, ce,
					    aclr, aset, aset_value,
					    nex_set, nex_d, bitmasks,
					    vector<NetEvProbe*>());
      }
      if (! flag) {
	    delete clock;
	    return false;
      }

      flag = tie_off_floating_inputs_(des, nex_set, nex_in, bitmasks, true,
				      0, &process_write_masks);
      if (!flag) return false;

      for (unsigned idx = 0 ;  idx < nex_set.size() ;  idx += 1) {
	    if (!any_bits_driven(process_write_masks[idx]))
		  continue;

	      //ivl_assert(*this, nex_set[idx].nex);
	    if (debug_synth2) {
		  cerr << get_fileline() << ": debug: "
		       << "Top level making a "
		       << nex_set[idx].wid << "-wide "
		       << "NetFF device." << endl;
	    }

	    NetFF*ff2 = new NetFF(scope(), scope()->local_symbol(),
				  negedge, nex_set[idx].wid);
	    des->add_node(ff2);
	    ff2->set_line(*this);
	    ff2->aset_value(aset_value[idx]);

	    NetNet*tmp = nex_d.pin(idx).nexus()->pick_any_net();
	    tmp->set_line(*this);
	    assert(tmp);

	    tmp = crop_to_width(des, tmp, ff2->width());

	    const netvector_t*q_type = new netvector_t(
		  nex_set[idx].lnk.nexus()->pick_any_net()->data_type(),
		  ff2->width()-1, 0);
	    NetNet*q_value = new NetNet(scope(), scope()->local_symbol(),
				   NetNet::WIRE, q_type);
	    q_value->local_flag(true);
	    q_value->set_line(*this);
	    connect(q_value->pin(0), ff2->pin_Q());
	    NetNet*process_output = mask_synthesized_process_output(
		  des, scope(), *this, q_value, process_write_masks[idx]);
	    connect(nex_q.pin(idx), process_output->pin(0));
	    connect(tmp->pin(0),    ff2->pin_Data());

	    connect(clock->pin(0),  ff2->pin_Clock());
	    if (ce.pin(idx).is_linked())
		  connect(ce.pin(idx),	  ff2->pin_Enable());
	    if (aclr.pin(idx).is_linked())
		  connect(aclr.pin(idx),  ff2->pin_Aclr());
	    if (aset.pin(idx).is_linked())
		  connect(aset.pin(idx),  ff2->pin_Aset());
#if 0
	    if (ff->pin_Sset().is_linked())
		  connect(ff->pin_Sset(), ff2->pin_Sset());
	    if (ff->pin_Sclr().is_linked())
		  connect(ff->pin_Sclr(), ff2->pin_Sclr());
#endif
      }

	// The "clock" net was just to carry the connection back
	// to the flip-flop. Delete it now. The connection will
	// persist.
      delete clock;

      claim_synthesized_process_outputs(
	    des, *this, nex_set, process_write_masks);
      synthesized_design_ = des;
      return true;
}

class synth2_f	: public functor_t {

    public:
      void process(Design*, NetProcTop*) override;

    private:
};

class synth2_validate_f : public functor_t {

    public:
      void signal(Design*, NetNet*) override;

    private:
      set<Nexus*> reported_nexuses_;
};

static bool synth_constant_boolean(const NetExpr*expr, bool&value)
{
      verinum constant;
      if (const NetEConst*number = dynamic_cast<const NetEConst*>(expr)) {
	    constant = number->value();
      } else if (const NetESignal*signal =
		       dynamic_cast<const NetESignal*>(expr)) {
	    if (signal->word_index() || signal->sig()->pin_count() != 1)
		  return false;
	    const Nexus*nexus = signal->sig()->pin(0).nexus();
	    if (!nexus->drivers_constant())
		  return false;
	    constant = nexus->driven_vector();
      } else {
	    return false;
      }

      if (!constant.is_defined())
	    return false;
      value = !constant.is_zero();
      return true;
}

static bool process_is_statically_inert(const NetProc*statement)
{
      if (!statement)
	    return true;

      if (const NetBlock*block = dynamic_cast<const NetBlock*>(statement)) {
	    for (const NetProc*cur = block->proc_first(); cur;
		 cur = block->proc_next(cur)) {
		  if (!process_is_statically_inert(cur))
			return false;
	    }
	    return true;
      }

      if (const NetCondit*condition =
		       dynamic_cast<const NetCondit*>(statement)) {
	    bool take_true = false;
	    if (!synth_constant_boolean(condition->expr(), take_true))
		  return false;
	    return process_is_statically_inert(
		  take_true ? condition->if_clause() : condition->else_clause());
      }

      return false;
}


/*
 * Look at a process. If it is asynchronous, then synthesize it as an
 * asynchronous process and delete the process itself for its gates.
 */
void synth2_f::process(Design*des, NetProcTop*top)
{
      if (top->attribute(perm_string::literal("ivl_synthesis_off")).as_ulong() != 0)
	    return;

	// A generate/preprocessor-surviving initial block can become an empty
	// hardware process after parameter folding, as in OpenTitan's optional
	// memory preload helper when MemInitFile is empty. Drop only a process
	// whose statically chosen path contains no statement; a live initial
	// block (including a nonempty $readmemh path) remains diagnosed.
      if (top->type() == IVL_PR_INITIAL
	  && process_is_statically_inert(top->statement())) {
	    des->delete_process(top);
	    return;
      }

	/* If the scope that contains this process as a cell attribute
	   attached to it, then skip synthesis. */
      if (top->scope()->attribute(perm_string::literal("ivl_synthesis_cell")).len() > 0)
	    return;

	/* Create shared pullup and pulldown nodes (if they don't already
	   exist) for use when creating clock/gate enables. */
      top->scope()->add_tie_hi(des);
      top->scope()->add_tie_lo(des);

      if (top->is_synchronous()) {
	    bool flag = top->synth_sync(des);
	    if (! flag) {
		  cerr << top->get_fileline() << ": error: "
		       << "Unable to synthesize synchronous process."
		       << endl;
		  des->errors += 1;
		  return;
	    }
	    des->delete_process(top);
	    return;
      }

      if (! top->is_asynchronous()) {
	    bool synth_error_flag = false;
	    if (top->attribute(perm_string::literal("ivl_combinational")).as_ulong() != 0) {
		  cerr << top->get_fileline() << ": error: "
		       << "Process is marked combinational,"
		       << " but isn't really." << endl;
		  des->errors += 1;
		  synth_error_flag = true;
	    }

	    if (top->attribute(perm_string::literal("ivl_synthesis_on")).as_ulong() != 0) {
		  cerr << top->get_fileline() << ": error: "
		       << "Process is marked for synthesis,"
		       << " but I can't do it." << endl;
		  des->errors += 1;
		  synth_error_flag = true;
	    }

	    if (! synth_error_flag)
		  cerr << top->get_fileline() << ": warning: "
		       << "Process not synthesized." << endl;

	    return;
      }

      if (! top->synth_async(des)) {
	    cerr << top->get_fileline() << ": error: "
		 << "Unable to synthesize asynchronous process."
		 << endl;
	    des->errors += 1;
	    return;
      }

      des->delete_process(top);
}

void synth2_validate_f::signal(Design*des, NetNet*net)
{
        // Process destructors release their procedural l-value references.
        // Wait until the complete synthesis walk has finished so other
        // synthesizable disjoint writers have also been removed. A remaining
        // l-value reference belongs to a behavioral process that cannot share
        // this packed variable with a synthesized structural driver.
      if (net->peek_lref() == 0)
	    return;

      for (unsigned pin = 0; pin < net->pin_count(); pin += 1) {
	    Nexus*nexus = net->pin(pin).nexus();
	    if (!nexus->has_synthesized_process_driver())
		  continue;
	    if (!reported_nexuses_.insert(nexus).second)
		  continue;

	    cerr << net->get_fileline() << ": warning: '" << net->name()
		 << "' retains a behavioral procedural driver after synthesis."
		 << endl;
	    cerr << net->get_fileline() << ": sorry: Cannot combine behavioral "
		    "and synthesized process drivers on one packed signal."
		 << endl;
	    des->errors += 1;
      }
}

void synth2(Design*des)
{
      synth2_f synth_obj;
      des->functor(&synth_obj);

      synth2_validate_f validate_obj;
      des->functor(&validate_obj);
}

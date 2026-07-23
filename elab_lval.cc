/*
 * Copyright (c) 2000-2025 Stephen Williams (steve@icarus.com)
 * Copyright CERN 2012-2013 / Stephen Williams (steve@icarus.com)
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
# include  <algorithm>
# include  <cstdlib>

# include  "PExpr.h"
# include  "PPackage.h"
# include  "PClass.h"
# include  "netlist.h"
# include  "netmisc.h"
# include  "netstruct.h"
# include  "netclass.h"
# include  "Module.h"
# include  "PModport.h"
# include  "parse_api.h"
# include  "netdarray.h"
# include  "netparray.h"
# include  "netqueue.h"
# include  "netvector.h"
# include  "netenum.h"
# include  "compiler.h"
# include  <cstdlib>
# include  <iostream>
# include  <climits>
# include  "ivl_assert.h"

using namespace std;

/* Clocking-block member path rewrites are shared with expression
   elaboration — see rewrite_*_clocking_member_path* in netmisc.cc. */

/*
 * These methods generate a NetAssign_ object for the l-value of the
 * assignment. This is common code for the = and <= statements.
 *
 * What gets generated depends on the structure of the l-value. If the
 * l-value is a simple name (i.e., foo <= <value>) then the NetAssign_
 * is created the width of the foo reg and connected to all the
 * bits.
 *
 * If there is a part select (i.e., foo[3:1] <= <value>) the NetAssign_
 * is made only as wide as it needs to be (3 bits in this example) and
 * connected to the correct bits of foo. A constant bit select is a
 * special case of the part select.
 *
 * If the bit-select is non-constant (i.e., foo[<expr>] = <value>) the
 * NetAssign_ is made wide enough to connect to all the bits of foo,
 * then the mux expression is elaborated and attached to the
 * NetAssign_ node as a b_mux value. The target must interpret the
 * presence of a bmux value as taking a single bit and assigning it to
 * the bit selected by the bmux expression.
 *
 * If the l-value expression is non-trivial, but can be fully
 * evaluated at compile time (meaning any bit selects are constant)
 * then elaboration will make a single NetAssign_ that connects to a
 * synthetic reg that in turn connects to all the proper pins of the
 * l-value.
 *
 * This last case can turn up in statements like: {a, b[1]} = c;
 * rather than create a NetAssign_ for each item in the concatenation,
 * elaboration makes a single NetAssign_ and connects it up properly.
 */

void PEIdent::report_mixed_assignment_conflict_(const char*category) const
{
      cerr << get_fileline() << ": error: Cannot perform procedural "
              "assignment to " << category << " '" << path_
           << "' because it is also continuously assigned." << endl;
}

/*
 * The default interpretation of an l-value to a procedural assignment
 * is to try to make a net elaboration, and see if the result is
 * suitable for assignment.
 */
NetAssign_* PExpr::elaborate_lval(Design*, NetScope*, bool, bool, bool) const
{
      cerr << get_fileline() << ": Assignment l-value too complex." << endl;
      return 0;
}

/*
 * Concatenation expressions can appear as l-values. Handle them here.
 *
 * If adjacent l-values in the concatenation are not bit selects, then
 * merge them into a single NetAssign_ object. This can happen is code
 * like ``{ ...a, b, ...}''. As long as "a" and "b" do not have bit
 * selects (or the bit selects are constant) we can merge the
 * NetAssign_ objects.
 *
 * Be careful to get the bit order right. In the expression ``{a, b}''
 * a is the MSB and b the LSB. Connect the LSB to the low pins of the
 * NetAssign_ object.
 */
NetAssign_* PEConcat::elaborate_lval(Design*des,
				     NetScope*scope,
				     bool is_cassign,
				     bool is_force,
				     bool is_init) const
{
      if (repeat_) {
	    cerr << get_fileline() << ": error: Repeat concatenations make "
		  "no sense in l-value expressions. I refuse." << endl;
	    des->errors += 1;
	    return 0;
      }

      NetAssign_*res = 0;

      for (unsigned idx = 0 ;  idx < parms_.size() ;  idx += 1) {

	    if (parms_[idx] == 0) {
		  cerr << get_fileline() << ": error: Empty expressions "
		       << "not allowed in concatenations." << endl;
		  des->errors += 1;
		  continue;
	    }

	    NetAssign_*tmp = parms_[idx]->elaborate_lval(des, scope,
							 is_cassign, is_force, is_init);

	      /* If the l-value doesn't elaborate, the error was
		 already detected and printed. We just skip it and let
		 the compiler catch more errors. */
	    if (tmp == 0) continue;

	    if (tmp->expr_type() == IVL_VT_REAL) {
		  cerr << parms_[idx]->get_fileline() << ": error: "
		       << "concatenation operand can not be real: "
		       << *parms_[idx] << endl;
		  des->errors += 1;
		  continue;
	    }

	      /* A concatenation is always unsigned. */
	    tmp->set_signed(false);

	      /* Link the new l-value to the previous one. */
	    NetAssign_*last = tmp;
	    while (last->more)
		  last = last->more;

	    last->more = res;
	    res = tmp;
      }

      return res;
}


/*
 * Handle the ident as an l-value. This includes bit and part selects
 * of that ident.
 */
NetAssign_* PEIdent::elaborate_lval(Design*des,
				    NetScope*scope,
				    bool is_cassign,
				    bool is_force,
				    bool is_init) const
{

      if (debug_elaborate) {
	    cerr << get_fileline() << ": PEIdent::elaborate_lval: "
		 << "Elaborate l-value ident expression: " << *this << endl;
      }

      symbol_search_results sr;
      symbol_search(this, des, scope, path_, lexical_pos_, &sr);

      NetNet *reg = sr.net;
      const pform_name_t &member_path = sr.path_tail;

      pform_name_t rewritten_path;
      bool clk_input_write = false;
      if ((reg && rewrite_class_clocking_member_path(this, sr, rewritten_path,
						     true, &clk_input_write))
	  || rewrite_clocking_member_path_via_scope(this, sr, rewritten_path,
						    true, &clk_input_write)
	  || (!reg && rewrite_enclosing_scope_clocking_member_path(this, scope, rewritten_path,
								   true, &clk_input_write))) {
	    if (clk_input_write)
		  des->errors += 1;
	    if (path_.package) {
		  PEIdent mapped_ident(path_.package, rewritten_path, lexical_pos_);
		  return mapped_ident.elaborate_lval(des, scope, is_cassign,
						    is_force, is_init);
	    }
	    PEIdent mapped_ident(rewritten_path, lexical_pos_);
	    return mapped_ident.elaborate_lval(des, scope, is_cassign,
					      is_force, is_init);
      }

	/* The l-value must be a variable. If not, then give up and
	   print a useful error message. */
      if (reg == 0) {
	    if (scope->type()==NetScope::FUNC
		&& scope->func_def()->is_void()
		&& scope->basename()==peek_tail_name(path_)) {
		  cerr << get_fileline() << ": error: "
		       << "Cannot assign to " << path_
		       << " because function " << scope_path(scope)
		       << " is void." << endl;
		  des->errors += 1;
	    } else if (gn_system_verilog()) {
		  // Compile-progress: covergroup handles, unresolved class properties,
		  // and other SV constructs may not be found as l-value variables.
		  cerr << get_fileline() << ": warning: Could not find variable ``"
		       << path_ << "'' in ``" << scope_path(scope) << "''"
		       << " (compile-progress: assignment ignored)." << endl;
	    } else {
		  cerr << get_fileline() << ": error: Could not find variable ``"
		       << path_ << "'' in ``" << scope_path(scope) <<
			"''" << endl;
		  if (sr.decl_after_use) {
			cerr << sr.decl_after_use->get_fileline() << ":      : "
				"A symbol with that name was declared here. "
				"Check for declaration after use." << endl;
		  }
		  des->errors += 1;
	    }
	    return 0;
      }

      ivl_assert(*this, reg);

      if (debug_elaborate) {
	    cerr << get_fileline() << ": " << __func__ << ": "
		 << "Found l-value path_=" << path_
		 << " as reg=" << reg->name() << endl;
	    cerr << get_fileline() << ": " << __func__ << ": "
		 << "reg->type()=" << reg->type()
		 << ", reg->unpacked_dimensions()=" << reg->unpacked_dimensions()
		 << endl;
	    if (reg->net_type())
		  cerr << get_fileline() << ": " << __func__ << ": "
		       << "reg->net_type()=" << *reg->net_type() << endl;
	    else
		  cerr << get_fileline() << ": " << __func__ << ": "
		       << "reg->net_type()=<nil>" << endl;
	    const pform_name_t &base_path = sr.path_head;
	    cerr << get_fileline() << ": " << __func__ << ": "
		 << " base_path=" << base_path
		 << ", member_path=" << member_path
		 << endl;
      }

      if (reg->get_const() && !is_init) {
	    cerr << get_fileline() << ": error: Assignment to const signal `"
	         << reg->name() << "` is not allowed." << endl;
	    des->errors++;
	    return nullptr;
      }

	/* We are elaborating procedural assignments. Wires are not allowed
	   unless this is the l-value of a force. */
      if ((reg->type() != NetNet::REG)
	  && ((reg->type() != NetNet::UNRESOLVED_WIRE) || !reg->coerced_to_uwire())
	  && !is_force) {
	    cerr << get_fileline() << ": error: '" << path_
		 << "' is not a valid l-value for a procedural assignment."
		 << endl;
	    cerr << reg->get_fileline() << ":      : '" << path_ <<
		  "' is declared here as a " << reg->type() << "." << endl;
	    des->errors += 1;
	    return 0;
      }

      ivl_assert(*this, !sr.path_head.empty());
      return elaborate_lval_var_(des, scope, is_force, is_cassign, reg,
			         sr.type, member_path,
			         sr.path_head.back().index);
}

NetAssign_*PEIdent::elaborate_lval_var_(Design *des, NetScope *scope,
				        bool is_force, bool is_cassign,
					NetNet *reg, ivl_type_t data_type,
					const pform_name_t tail_path,
					const list<index_component_t>&base_index) const
{
	// We are processing the tail of a string of names. For
	// example, the Verilog may be "a.b.c", so we are processing
	// "c" at this point.
      const name_component_t&name_tail = path_.back();

	// Use the last index to determine what kind of select
	// (bit/part/etc) we are processing. For example, the Verilog
	// may be "a.b.c[1][2][<index>]". All but the last index must
	// be simple expressions, only the <index> may be a part
	// select etc., so look at it to determine how we will be
	// proceeding.
      index_component_t::ctype_t use_sel = index_component_t::SEL_NONE;
      if (!name_tail.index.empty())
	    use_sel = name_tail.index.back().sel;

	// Special case: The l-value is an entire memory, or array
	// slice. Detect the situation by noting if the index count
	// is less than the array dimensions (unpacked).
	//
	// This must not fire for a member access on an array element
	// (`arr[i].prop = ...`): there the array index sits on the base
	// component (base_index), while name_tail is the member and
	// carries no index, so name_tail.index.size() is 0. Guard on an
	// empty tail_path so such references fall through to the
	// class/struct member l-value path below.
      if (tail_path.empty()
	  && reg->unpacked_dimensions() > name_tail.index.size()) {
	    return elaborate_lval_array_(des, scope, is_force, reg);
      }

	// If we find that the matched variable is a packed struct,
	// then we can handled it with the net_packed_member_ method.
      if (reg->struct_type() && reg->struct_type()->packed() && !tail_path.empty()) {
	    NetAssign_*lv = new NetAssign_(reg);
	    elaborate_lval_net_packed_member_(des, scope, lv, tail_path, is_force);
	    return lv;
      }

	// Class objects and unpacked structs use nested property l-values.
	// If the root expression is indexed (e.g. queue[idx].member), then
	// walk through the indexed container type to get the element type
	// before deciding whether the remaining tail is a member l-value.
      ivl_type_t member_root_type = data_type;
      if (!member_root_type && !base_index.empty())
	    member_root_type = reg->array_type();
      for (size_t depth = base_index.size()
		 ; member_root_type && depth > 0 ; depth -= 1) {
	    if (const netdarray_t*darray =
			dynamic_cast<const netdarray_t*>(member_root_type)) {
		  member_root_type = darray->element_type();
	    } else if (const netuarray_t*uarray =
			dynamic_cast<const netuarray_t*>(member_root_type)) {
		  member_root_type = uarray->element_type();
	    } else if (const netarray_t*array =
			dynamic_cast<const netarray_t*>(member_root_type)) {
		  member_root_type = array->element_type();
	    } else {
		  break;
	    }
      }
      if (!tail_path.empty() && gn_system_verilog()) {
	    const netclass_t *class_type =
		  dynamic_cast<const netclass_t *>(member_root_type);
	    const netstruct_t *struct_type =
		  dynamic_cast<const netstruct_t *>(member_root_type);
	      // Member access on an element of an unpacked-struct
	      // container -- a static array (netuarray_t), a dynamic
	      // array (netdarray_t), a queue, or an associative array --
	      // is object-backed: each element is stored as an object and
	      // lazily default-constructed at run time, so
	      // container[i].field = ... addresses the right element
	      // (IEEE 1800-2017 7.2.1).
	    if (class_type || (struct_type && !struct_type->packed()))
		  return elaborate_lval_net_class_member_(des, scope, member_root_type,
							  reg, tail_path, base_index);
      }


	// Past this point, we should have taken care of the cases
	// where the name is a member/method of a struct/class.
	// XXXX ivl_assert(*this, method_name.nil());
      ivl_assert(*this, tail_path.empty());

      bool need_const_idx = is_cassign || is_force;

      if (reg->unpacked_dimensions() > 0)
	    return elaborate_lval_net_word_(des, scope, reg, need_const_idx, is_force);

	// This must be after the array word elaboration above!
      if (reg->get_scalar() &&
          use_sel != index_component_t::SEL_NONE) {
	    cerr << get_fileline() << ": error: can not select part of ";
	    if (reg->data_type() == IVL_VT_REAL) cerr << "real: ";
	    else cerr << "scalar: ";
	    cerr << reg->name() << endl;
	    des->errors += 1;
	    return 0;
      }

      if (use_sel == index_component_t::SEL_PART ||
          use_sel == index_component_t::SEL_PART_LAST) {
	    NetAssign_*lv = new NetAssign_(reg);
	    if (reg->darray_type())
		  elaborate_lval_darray_part_(des, scope, lv, is_force);
	    else
		  elaborate_lval_net_part_(des, scope, lv, is_force);
	    return lv;
      }

      if (use_sel == index_component_t::SEL_IDX_UP ||
          use_sel == index_component_t::SEL_IDX_DO) {
	    if (reg->darray_type()) {
		    // `d[i][base+:w]`/`[base-:w]` into a darray element is not
		    // yet lowered; a loud sorry beats the backend assert.
		  cerr << get_fileline() << ": sorry: assignment to an indexed "
		          "part-select of a dynamic-array element is not yet "
		          "supported." << endl;
		  des->errors += 1;
		  return 0;
	    }
	    NetAssign_*lv = new NetAssign_(reg);
	    elaborate_lval_net_idx_(des, scope, lv, use_sel, need_const_idx, is_force);
	    return lv;
      }


      if (use_sel == index_component_t::SEL_BIT) {
	    if (reg->darray_type()) {
		  NetAssign_*lv = new NetAssign_(reg);
		  elaborate_lval_darray_bit_(des, scope, lv, is_force);
		  return lv;
	    } else {
		  NetAssign_*lv = new NetAssign_(reg);
		  elaborate_lval_net_bit_(des, scope, lv, need_const_idx, is_force);
		  return lv;
	    }
      }

      ivl_assert(*this, use_sel == index_component_t::SEL_NONE);

      if (reg->type()==NetNet::UNRESOLVED_WIRE && !is_force) {
	    ivl_assert(*this, reg->coerced_to_uwire());
	    report_mixed_assignment_conflict_("variable");
	    des->errors += 1;
	    return 0;
      }

	/* No select expressions. */

      NetAssign_*lv = new NetAssign_(reg);
      lv->set_signed(reg->get_signed());

      return lv;
}

NetAssign_*PEIdent::elaborate_lval_array_(Design *des, NetScope *scope,
				          bool is_force, NetNet *reg) const
{
      if (!gn_system_verilog()) {
	    cerr << get_fileline() << ": error: Assignment to an entire"
		  " array or to an array slice requires SystemVerilog."
		 << endl;
	    des->errors += 1;
	    return 0;
      }

      const name_component_t&name_tail = path_.back();
      if (name_tail.index.empty()) {
	    if ((reg->type()==NetNet::UNRESOLVED_WIRE) && !is_force) {
		  ivl_assert(*this, reg->coerced_to_uwire());
		  report_mixed_assignment_conflict_("array");
		  des->errors += 1;
		  return 0;
	    }
	    NetAssign_*lv = new NetAssign_(reg);
	    return lv;
      }

	// A partial index into a multi-dimensional unpacked array selects a
	// sub-array — an array slice, e.g. `m[i]` where m is int[2][3] picks
	// the int[3] row. Support this as the target of an assignment pattern
	// (`m[i] = '{...}`, IEEE 1800-2017 7.6 / 10.9.1): build a slice
	// l-value carrying the flat base word index and the sub-array type.
	// The pattern's element count drives how many words are written, so
	// no separate slice length has to be threaded to the code generator.
      const netsarray_t*full_arr =
	    dynamic_cast<const netsarray_t*>(reg->array_type());
      unsigned nidx = name_tail.index.size();
      if (full_arr && nidx < full_arr->static_dimensions().size()) {
	    const netranges_t&dims = full_arr->static_dimensions();

	    list<NetExpr*> idx_exprs;
	    list<long> idx_consts;
	    indices_flags flags;
	    indices_to_expressions(des, scope, this, name_tail.index, nidx,
				   false, flags, idx_exprs, idx_consts);

	    if (flags.variable || flags.undefined || flags.invalid) {
		  cerr << get_fileline() << ": sorry: assignment to an unpacked"
			  " array slice with a non-constant index is not yet"
			  " supported." << endl;
		  des->errors += 1;
		  return 0;
	    }

	    NetExpr*base = normalize_variable_unpacked(reg, idx_consts);
	    if (base == 0) {
		  cerr << get_fileline() << ": warning: ignoring out of bounds"
			  " l-value array slice access " << reg->name()
			 << "." << endl;
		  base = new NetEConst(verinum(verinum::Vx));
	    }
	    base->set_line(*this);

	      // The slice presents the remaining dimensions as its type.
	    netranges_t sub_dims;
	    for (size_t d = nidx ; d < dims.size() ; d += 1)
		  sub_dims.push_back(dims[d]);
	    ivl_type_t slice_type =
		  new netuarray_t(sub_dims, full_arr->element_type());

	    NetAssign_*lv = new NetAssign_(reg);
	    lv->set_array_slice(base, slice_type);
	    return lv;
      }

      cerr << get_fileline() << ": sorry: Assignment to an "
	    " array slice is not yet supported."
	   << endl;
      des->errors += 1;
      return 0;
}

NetAssign_* PEIdent::elaborate_lval_net_word_(Design*des,
					      NetScope*scope,
					      NetNet*reg,
					      bool need_const_idx,
					      bool is_force) const
{
      const name_component_t&name_tail = path_.back();
      ivl_assert(*this, !name_tail.index.empty());

      if (debug_elaborate) {
	    cerr << get_fileline() << ": PEIdent::elaborate_lval_net_word_: "
		 << "Handle as n-dimensional array." << endl;
      }

      if (name_tail.index.size() < reg->unpacked_dimensions()) {
	    cerr << get_fileline() << ": error: Array " << reg->name()
		 << " needs " << reg->unpacked_dimensions() << " indices,"
		 << " but got only " << name_tail.index.size() << "." << endl;
	    des->errors += 1;
	    return 0;
      }

	// Make sure there are enough indices to address an array element.
      const index_component_t&index_head = name_tail.index.front();
      if (index_head.sel == index_component_t::SEL_PART) {
	    cerr << get_fileline() << ": error: cannot perform a part "
	         << "select on array " << reg->name() << "." << endl;
	    des->errors += 1;
	    return 0;
      }


	// Evaluate all the index expressions into an
	// "unpacked_indices" array.
      list<NetExpr*>unpacked_indices;
      list<long> unpacked_indices_const;
      indices_flags flags;
      indices_to_expressions(des, scope, this,
			     name_tail.index, reg->unpacked_dimensions(),
			     false,
			     flags,
			     unpacked_indices,
			     unpacked_indices_const);

      NetExpr*canon_index = 0;
      if (flags.invalid) {
	    // Nothing to do.

      } else if (flags.undefined) {
	    cerr << get_fileline() << ": warning: "
		 << "ignoring undefined l-value array access "
		 << reg->name() << as_indices(unpacked_indices)
		 << "." << endl;

      } else if (flags.variable) {
	    if (need_const_idx) {
		  cerr << get_fileline() << ": error: array '" << reg->name()
		       << "' index must be a constant in this context." << endl;
		  des->errors += 1;
		  return 0;
	    }
	    ivl_assert(*this, unpacked_indices.size() == reg->unpacked_dimensions());
	    canon_index = normalize_variable_unpacked(reg, unpacked_indices);

      } else {
	    ivl_assert(*this, unpacked_indices_const.size() == reg->unpacked_dimensions());
	    canon_index = normalize_variable_unpacked(reg, unpacked_indices_const);

	    if (canon_index == 0) {
		  cerr << get_fileline() << ": warning: "
		       << "ignoring out of bounds l-value array access "
		       << reg->name() << as_indices(unpacked_indices_const)
		       << "." << endl;
	    }
      }

	// Ensure invalid array accesses are ignored.
      if (canon_index == 0)
	    canon_index = new NetEConst(verinum(verinum::Vx));
      canon_index->set_line(*this);

      if (debug_elaborate) {
	    cerr << get_fileline() << ": PEIdent::elaborate_lval_net_word_: "
		 << "canon_index=" << *canon_index << endl;
      }

      if ((reg->type()==NetNet::UNRESOLVED_WIRE) && !is_force) {
	    ivl_assert(*this, reg->coerced_to_uwire());
	    const NetEConst*canon_const = dynamic_cast<NetEConst*>(canon_index);
	    if (!canon_const || reg->test_part_driven(reg->vector_width() - 1, 0,
						      canon_const->value().as_long())) {
		  report_mixed_assignment_conflict_("array word");
		  des->errors += 1;
		  return 0;
	     }
      }

      NetAssign_*lv = new NetAssign_(reg);
      lv->set_word(canon_index);

      if (debug_elaborate)
	    cerr << get_fileline() << ": debug: Set array word=" << *canon_index << endl;


	/* An array word may also have part selects applied to them. */

      index_component_t::ctype_t use_sel = index_component_t::SEL_NONE;
      if (name_tail.index.size() > reg->unpacked_dimensions())
	    use_sel = name_tail.index.back().sel;

      if (reg->get_scalar() &&
          use_sel != index_component_t::SEL_NONE) {
	    cerr << get_fileline() << ": error: can not select part of ";
	    if (reg->data_type() == IVL_VT_REAL) cerr << "real";
	    else cerr << "scalar";
	    cerr << " array word: " << reg->name()
	         << as_indices(unpacked_indices) << endl;
	    des->errors += 1;
	    return 0;
      }

      if (use_sel == index_component_t::SEL_BIT)
	    elaborate_lval_net_bit_(des, scope, lv, need_const_idx, is_force);

      if (use_sel == index_component_t::SEL_PART)
	    elaborate_lval_net_part_(des, scope, lv, is_force);

      if (use_sel == index_component_t::SEL_IDX_UP ||
          use_sel == index_component_t::SEL_IDX_DO)
	    elaborate_lval_net_idx_(des, scope, lv, use_sel,
				    need_const_idx, is_force);

      return lv;
}

bool PEIdent::elaborate_lval_net_bit_(Design*des,
				      NetScope*scope,
				      NetAssign_*lv,
				      bool need_const_idx,
				      bool is_force) const
{
      list<long>prefix_indices;
      bool rc = calculate_packed_indices_(des, scope, lv->sig(), prefix_indices);
      if (!rc) return false;

      const name_component_t&name_tail = path_.back();
      ivl_assert(*this, !name_tail.index.empty());

      const index_component_t&index_tail = name_tail.index.back();
      ivl_assert(*this, index_tail.msb != 0);
      ivl_assert(*this, index_tail.lsb == 0);

      NetNet*reg = lv->sig();
      ivl_assert(*this, reg);

	// Bit selects have a single select expression. Evaluate the
	// constant value and treat it as a part select with a bit
	// width of 1.
      NetExpr*mux = elab_and_eval(des, scope, index_tail.msb, -1);
      long lsb = 0;

      if (mux && mux->expr_type() == IVL_VT_REAL) {
           cerr << get_fileline() << ": error: Index expression for "
                << reg->name() << "[" << *mux
                << "] cannot be a real value." << endl;
           des->errors += 1;
           return false;
      }

      if (const NetEConst*index_con = dynamic_cast<NetEConst*> (mux)) {
	      // The index has a constant defined value.
	    if (index_con->value().is_defined()) {
		  lsb = index_con->value().as_long();
		  mux = 0;
	      // The index is undefined and this is a packed array.
	    } else if (prefix_indices.size()+2 <= reg->packed_dims().size()) {
		  long loff;
		  unsigned long lwid;
		  bool rcl = reg->sb_to_slice(prefix_indices, lsb, loff, lwid);
		  ivl_assert(*this, rcl);
		  if (warn_ob_select) {
			cerr << get_fileline()
			     << ": warning: L-value packed array select of "
			     << reg->name();
			if (reg->unpacked_dimensions() > 0) cerr << "[]";
			cerr << " has an undefined index." << endl;
		  }
		  lv->set_part(new NetEConst(verinum(verinum::Vx)), lwid);
		  return true;
	      // The index is undefined and this is a bit select.
	    } else {
		  if (warn_ob_select) {
			cerr << get_fileline()
			     << ": warning: L-value bit select of "
			     << reg->name();
			if (reg->unpacked_dimensions() > 0) cerr << "[]";
			cerr << " has an undefined index." << endl;
		  }
		  lv->set_part(new NetEConst(verinum(verinum::Vx)), 1);
		  return true;
	    }
      }

      if (debug_elaborate && (reg->type()==NetNet::UNRESOLVED_WIRE)) {
	    cerr << get_fileline() << ": PEIdent::elaborate_lval_net_bit_: "
		 << "Try to assign bits of variable which is also continuously assigned."
		 << endl;
      }

      if (prefix_indices.size()+2 <= reg->packed_dims().size()) {
	      // Special case: this is a slice of a multi-dimensional
	      // packed array. For example:
	      //   reg [3:0][7:0] x;
	      //   x[2] = ...
	      // This shows up as the prefix_indices being too short
	      // for the packed dimensions of the vector. What we do
	      // here is convert to a "slice" of the vector.
	    if (mux == 0) {
		  long loff;
		  unsigned long lwid;
		  bool rcl = reg->sb_to_slice(prefix_indices, lsb, loff, lwid);
		  ivl_assert(*this, rcl);

		  if ((reg->type()==NetNet::UNRESOLVED_WIRE) && !is_force) {
			ivl_assert(*this, reg->coerced_to_uwire());
			if (reg->test_part_driven(loff+lwid-1, loff)) {
			      report_mixed_assignment_conflict_("slice");
			      des->errors += 1;
			      return false;
			}
		  }

		  lv->set_part(new NetEConst(verinum(loff)), lwid);

	    } else {
		  unsigned long lwid;
		  mux = normalize_variable_slice_base(prefix_indices, mux,
						      reg, lwid);

		  if ((reg->type()==NetNet::UNRESOLVED_WIRE) && !is_force) {
			ivl_assert(*this, reg->coerced_to_uwire());
			report_mixed_assignment_conflict_("slice");
			des->errors += 1;
			return false;
		  }

		  lv->set_part(mux, lwid);
	    }

      } else if (reg->data_type() == IVL_VT_STRING) {
	    ivl_assert(*this, reg->type()!=NetNet::UNRESOLVED_WIRE);
	      // Special case: This is a select of a string
	      // variable. The target of the assignment is a character
	      // select of a string. Force the r-value to be an 8bit
	      // vector and set the "part" to be the character select
	      // expression. The code generator knows what to do with
	      // this.
	    if (debug_elaborate) {
		  cerr << get_fileline() << ": debug: "
		       << "Bit select of string becomes character select." << endl;
	    }
	    if (!mux)
		  mux = new NetEConst(verinum(lsb));
	    lv->set_part(mux, &netvector_t::atom2s8);

      } else if (mux) {
	      // Non-constant bit mux. Correct the mux for the range
	      // of the vector, then set the l-value part select
	      // expression.
	    if (need_const_idx) {
		  cerr << get_fileline() << ": error: '" << reg->name()
		       << "' bit select must be a constant in this context."
		       << endl;
		  des->errors += 1;
		  return false;
	    }
	    mux = normalize_variable_bit_base(prefix_indices, mux, reg);

	    if ((reg->type()==NetNet::UNRESOLVED_WIRE) && !is_force) {
		  ivl_assert(*this, reg->coerced_to_uwire());
		  report_mixed_assignment_conflict_("bit select");
		  des->errors += 1;
		  return false;
	    }

	    lv->set_part(mux, 1);

      } else if (reg->vector_width() == 1 && reg->sb_is_valid(prefix_indices,lsb)) {
	      // Constant bit mux that happens to select the only bit
	      // of the l-value. Don't bother with any select at all.
	      // If there's a continuous assignment, it must be a conflict.
	    if ((reg->type()==NetNet::UNRESOLVED_WIRE) && !is_force) {
		  ivl_assert(*this, reg->coerced_to_uwire());
		  report_mixed_assignment_conflict_("bit select");
		  des->errors += 1;
		  return false;
	    }

      } else {
	      // Constant bit select that does something useful.
	    long loff = reg->sb_to_idx(prefix_indices,lsb);

	    if (warn_ob_select && (loff < 0 || loff >= (long)reg->vector_width())) {
		  cerr << get_fileline() << ": warning: bit select "
		       << reg->name() << "[" <<lsb<<"]"
		       << " is out of range." << endl;
	    }

	    if ((reg->type()==NetNet::UNRESOLVED_WIRE) && !is_force) {
		  ivl_assert(*this, reg->coerced_to_uwire());
		  if (reg->test_part_driven(loff, loff)) {
			report_mixed_assignment_conflict_("bit select");
			des->errors += 1;
			return false;
		  }
	    }

	    lv->set_part(new NetEConst(verinum(loff)), 1);
      }

      return true;
}

/*
 * Compute the element-relative bit offset for a constant index into a
 * dynamic-array (or queue) element that is a simple (single packed
 * dimension) vector, e.g. `d[i][idx]` where the element is `bit[msb:lsb]`.
 * Returns true and sets `off` (normalized, 0 == the lsb bit) on success;
 * false if the element is not a single-dimension vector, in which case the
 * caller emits a loud sorry rather than a silent wrong store.
 */
static bool darray_elem_bit_offset(const netdarray_t*da, long index, long&off)
{
      ivl_type_t et = da->element_type();
      const netvector_t*ev = dynamic_cast<const netvector_t*>(et);
      if (ev == 0)
	    return false;
      const netranges_t&dims = ev->packed_dims();
      if (dims.size() != 1)
	    return false;
      long msb = dims[0].get_msb();
      long lsb = dims[0].get_lsb();
      if (msb >= lsb)
	    off = index - lsb;
      else
	    off = lsb - index;
      return true;
}

/*
 * Fetch the single packed-dimension range [msb:lsb] of a dynamic-array
 * element that is a simple vector. Returns false (caller emits a loud
 * sorry) if the element is not a single-dimension vector.
 */
static bool darray_elem_vector_range(const netdarray_t*da, long&msb, long&lsb)
{
      const netvector_t*ev = dynamic_cast<const netvector_t*>(da->element_type());
      if (ev == 0)
	    return false;
      const netranges_t&dims = ev->packed_dims();
      if (dims.size() != 1)
	    return false;
      msb = dims[0].get_msb();
      lsb = dims[0].get_lsb();
      return true;
}

bool PEIdent::elaborate_lval_darray_bit_(Design*des,
					 NetScope*scope,
					 NetAssign_*lv,
					 bool is_force) const
{
      const name_component_t&name_tail = path_.back();
      ivl_assert(*this, !name_tail.index.empty());

      const index_component_t&word_index = name_tail.index.front();
      ivl_assert(*this, word_index.msb != 0);
      ivl_assert(*this, word_index.lsb == 0);

      if ((lv->sig()->type()==NetNet::UNRESOLVED_WIRE) && !is_force) {
	    ivl_assert(*this, lv->sig()->coerced_to_uwire());
	    report_mixed_assignment_conflict_("darray word");
	    des->errors += 1;
	    return false;
      }

	// First index always selects the darray word.
      NetExpr*mux = elab_and_eval(des, scope, word_index.msb, -1);

      lv->set_word(mux);

	// A trailing bit-select on the darray element, `d[i][bit] = v`.
	// Lower it as an element part-select: keep the word select and add a
	// constant part offset of width 1, which the vvp backend turns into a
	// read-modify-write (%store/dar/vec4/off). Previously the bit index
	// was silently dropped, writing the whole element.
      if (name_tail.index.size() == 2) {
	    const index_component_t&elem_index = name_tail.index.back();
	    if (elem_index.sel == index_component_t::SEL_BIT) {
		    // The bit index may be a run-time expression (UVM's
		    // uvm_packer does `value[i/8][i%8] = ...`). Normalize it
		    // to an element-relative offset; the backend evaluates it
		    // into a register for the read-modify-write.
		  NetExpr*bexpr = elab_and_eval(des, scope, elem_index.msb, -1);
		  long emsb = 0, elsb = 0;
		  const netdarray_t*da = lv->sig()->darray_type();
		  if (bexpr && da && darray_elem_vector_range(da, emsb, elsb)) {
			NetExpr*off = normalize_variable_base(bexpr, emsb, elsb,
							      1, true, 0);
			lv->set_part(off, 1);
			return true;
		  }
		  delete bexpr;
		  cerr << get_fileline() << ": sorry: assignment to a "
		          "dynamic-array element bit-select requires a simple "
		          "vector element." << endl;
		  des->errors += 1;
		  return false;
	    }
      }

      if (name_tail.index.size() != 1) {
	    cerr << get_fileline() << ": sorry: Only single-dimension darray "
	            "index selects are supported in this l-value form." << endl;
	    des->errors += 1;
	    return false;
      }

      return true;
}

/*
 * Assignment to a part-select of a dynamic-array (or queue) element:
 * `d[i][msb:lsb] = v`. Keep the word select and add a constant,
 * element-relative part offset; the vvp backend does a read-modify-write.
 */
bool PEIdent::elaborate_lval_darray_part_(Design*des,
					  NetScope*scope,
					  NetAssign_*lv,
					  bool is_force) const
{
      const name_component_t&name_tail = path_.back();
      ivl_assert(*this, !name_tail.index.empty());

      const index_component_t&word_index = name_tail.index.front();
      ivl_assert(*this, word_index.msb != 0);

      if ((lv->sig()->type()==NetNet::UNRESOLVED_WIRE) && !is_force) {
	    ivl_assert(*this, lv->sig()->coerced_to_uwire());
	    report_mixed_assignment_conflict_("darray word");
	    des->errors += 1;
	    return false;
      }

	// First index selects the darray word.
      NetExpr*mux = elab_and_eval(des, scope, word_index.msb, -1);
      lv->set_word(mux);

      if (name_tail.index.size() != 2) {
	    cerr << get_fileline() << ": sorry: only a single word index "
	            "with a part-select is supported for a dynamic-array "
	            "element l-value." << endl;
	    des->errors += 1;
	    return false;
      }

      const index_component_t&pindex = name_tail.index.back();
      NetExpr*me = elab_and_eval(des, scope, pindex.msb, -1, true);
      NetExpr*le = elab_and_eval(des, scope, pindex.lsb, -1, true);
      long msb = 0, lsb = 0;
      long moff = 0, loff = 0;
      const netdarray_t*da = lv->sig()->darray_type();
      if (me && le && eval_as_long(msb, me) && eval_as_long(lsb, le) && da
	  && darray_elem_bit_offset(da, msb, moff)
	  && darray_elem_bit_offset(da, lsb, loff)) {
	    delete me;
	    delete le;
	    long base = moff < loff ? moff : loff;
	    long span = moff < loff ? (loff - moff) : (moff - loff);
	    lv->set_part(new NetEConst(verinum(base)), (unsigned long)(span + 1));
	    return true;
      }
      delete me;
      delete le;
      cerr << get_fileline() << ": sorry: assignment to a dynamic-array "
              "element part-select requires constant bounds into a simple "
              "vector element." << endl;
      des->errors += 1;
      return false;
}

bool PEIdent::elaborate_lval_net_part_(Design*des,
				       NetScope*scope,
				       NetAssign_*lv,
				       bool is_force) const
{
      if (lv->sig()->data_type() == IVL_VT_STRING) {
           cerr << get_fileline() << ": error: Cannot part select assign to a string ('"
                << lv->sig()->name() << "')." << endl;
           des->errors += 1;
           return false;
      }

      list<long> prefix_indices;
      bool rc = calculate_packed_indices_(des, scope, lv->sig(), prefix_indices);
      ivl_assert(*this, rc);

	// The range expressions of a part select must be
	// constant. The calculate_parts_ function calculates the
	// values into msb and lsb.
      long msb, lsb;
      bool parts_defined_flag;
      calculate_parts_(des, scope, msb, lsb, parts_defined_flag);

      NetNet*reg = lv->sig();
      ivl_assert(*this, reg);

      if (! parts_defined_flag) {
	    if (warn_ob_select) {
		  cerr << get_fileline()
		       << ": warning: L-value part select of "
		       << reg->name();
		  if (reg->unpacked_dimensions() > 0) cerr << "[]";
		  cerr << " has an undefined index." << endl;
	    }
	      // Use a width of two here so we can distinguish between an
	      // undefined bit or part select.
	    lv->set_part(new NetEConst(verinum(verinum::Vx)), 2);
	    return true;
      }

      if ((reg->type()==NetNet::UNRESOLVED_WIRE) && !is_force) {
	    ivl_assert(*this, reg->coerced_to_uwire());
	    if (reg->test_part_driven(msb, lsb)) {
		  report_mixed_assignment_conflict_("part select");
		  des->errors += 1;
		  return false;
	    }
      }

      const netranges_t&packed = reg->packed_dims();

      long loff, moff;
      if (prefix_indices.size()+1 < packed.size()) {
	      // If there are fewer indices then there are packed
	      // dimensions, then this is a range of slices. Calculate
	      // it into a big slice.
	    bool lrc, mrc;
	    unsigned long lwid, mwid;
	    lrc = reg->sb_to_slice(prefix_indices, lsb, loff, lwid);
	    mrc = reg->sb_to_slice(prefix_indices, msb, moff, mwid);
	    if (!mrc || !lrc) {
		  cerr << get_fileline() << ": error: ";
		  cerr << "Part-select [" << msb << ":" << lsb;
		  cerr << "] exceeds the declared bounds for ";
		  cerr << reg->name();
		  if (reg->unpacked_dimensions() > 0) cerr << "[]";
		  cerr << "." << endl;
		  des->errors += 1;
		  return 0;
	    }
	    assert(lwid == mwid);
	    moff += mwid - 1;
      } else {
	    loff = reg->sb_to_idx(prefix_indices,lsb);
	    moff = reg->sb_to_idx(prefix_indices,msb);
      }

      if (moff < loff) {
	    cerr << get_fileline() << ": error: part select "
		 << reg->name() << "[" << msb<<":"<<lsb<<"]"
		 << " is reversed." << endl;
	    des->errors += 1;
	    return false;
      }

      unsigned long wid = moff - loff + 1;

	// Special case: The range winds up selecting the entire
	// vector. Treat this as no part select at all.
      if (loff == 0 && wid == reg->vector_width()) {
	    return true;
      }

	/* If the part select extends beyond the extremes of the
	   variable, then output a warning. Note that loff is
	   converted to normalized form so is relative the
	   variable pins. */

      if (warn_ob_select && (loff < 0 || moff >= (long)reg->vector_width())) {
	    cerr << get_fileline() << ": warning: Part select "
		 << reg->name() << "[" << msb<<":"<<lsb<<"]"
		 << " is out of range." << endl;
      }

      lv->set_part(new NetEConst(verinum(loff)), wid);

      return true;
}

bool PEIdent::elaborate_lval_net_idx_(Design*des,
				      NetScope*scope,
				      NetAssign_*lv,
				      index_component_t::ctype_t use_sel,
				      bool need_const_idx,
				      bool is_force) const
{
      if (lv->sig()->data_type() == IVL_VT_STRING) {
           cerr << get_fileline() << ": error: Cannot index part select assign to a string ('"
                << lv->sig()->name() << "')." << endl;
           des->errors += 1;
           return false;
      }

      list<long>prefix_indices;
      bool rc = calculate_packed_indices_(des, scope, lv->sig(), prefix_indices);
      ivl_assert(*this, rc);

      const name_component_t&name_tail = path_.back();;
      ivl_assert(*this, !name_tail.index.empty());

      const index_component_t&index_tail = name_tail.index.back();
      ivl_assert(*this, index_tail.msb != 0);
      ivl_assert(*this, index_tail.lsb != 0);

      NetNet*reg = lv->sig();
      ivl_assert(*this, reg);

      unsigned long wid;
      calculate_up_do_width_(des, scope, wid);

      NetExpr*base = elab_and_eval(des, scope, index_tail.msb, -1);

      if (base && base->expr_type() == IVL_VT_REAL) {
	    cerr << get_fileline() << ": error: Indexed part select base "
	            "expression for ";
	    cerr << lv->sig()->name() << "[" << *base;
	    if (index_tail.sel == index_component_t::SEL_IDX_UP) {
		  cerr << "+:";
	    } else {
		  cerr << "-:";
	    }
	    cerr << wid << "] cannot be a real value." << endl;
	    des->errors += 1;
	    return 0;
      }

      ivl_select_type_t sel_type = IVL_SEL_OTHER;

	// Handle the special case that the base is constant. For this
	// case we can reduce the expression.
      if (const NetEConst*base_c = dynamic_cast<NetEConst*> (base)) {
	      // For the undefined case just let the constant pass and
	      // we will handle it in the code generator.
	    if (base_c->value().is_defined()) {
		  long lsv = base_c->value().as_long();
		  long rel_base = 0;

		    // Check whether an unsigned base fits in a 32 bit int.
		    // This ensures correct results for the vlog95 target, and
		    // for the vvp target on LLP64 platforms (Microsoft Windows).
		  if (!base_c->has_sign() && (int32_t)lsv < 0) {
		          // The base is wrapped around.
			delete base;
			if (warn_ob_select) {
			      cerr << get_fileline() << ": warning: " << lv->name();
			      if (lv->word()) cerr << "[]";
			      cerr << "[" << (unsigned long)lsv
				   << (index_tail.sel == index_component_t::SEL_IDX_UP ? "+:" : "-:")
				   << wid << "] is always outside vector." << endl;
			}
			return false;
		  }

		    // Get the signal range.
		  const netranges_t&packed = reg->packed_dims();
		  if (prefix_indices.size()+1 < reg->packed_dims().size()) {
			  // Here we are selecting one or more sub-arrays.
			  // Make this work by finding the indexed sub-arrays and
			  // creating a generated slice that spans the whole range.
			long loff, moff;
			unsigned long lwid, mwid;
			bool lrc, mrc;
			mrc = reg->sb_to_slice(prefix_indices, lsv, moff, mwid);
			if (use_sel == index_component_t::SEL_IDX_UP)
			      lrc = reg->sb_to_slice(prefix_indices, lsv+wid-1, loff, lwid);
			else
			      lrc = reg->sb_to_slice(prefix_indices, lsv-wid+1, loff, lwid);
			if (!mrc || !lrc) {
			      cerr << get_fileline() << ": error: ";
			      cerr << "Part-select [" << lsv;
			      if (index_tail.sel == index_component_t::SEL_IDX_UP) {
				    cerr << "+:";
			      } else {
				    cerr << "-:";
			      }
			      cerr << wid << "] exceeds the declared bounds for ";
			      cerr << reg->name();
			      if (reg->unpacked_dimensions() > 0) cerr << "[]";
			      cerr << "." << endl;
			      des->errors += 1;
			      return 0;
			}
			ivl_assert(*this, lwid == mwid);

			if (moff > loff) {
			      rel_base = loff;
			      wid = moff + mwid - loff;
			} else {
			      rel_base = moff;
			      wid = loff + lwid - moff;
			}
		  } else {
			long offset = 0;
			  // We want the last range, which is where we work.
			const netrange_t&rng = packed.back();
			if (((rng.get_msb() < rng.get_lsb()) &&
			     use_sel == index_component_t::SEL_IDX_UP) ||
			    ((rng.get_msb() > rng.get_lsb()) &&
			     use_sel == index_component_t::SEL_IDX_DO)) {
			      offset = -wid + 1;
			}
			rel_base = reg->sb_to_idx(prefix_indices,lsv) + offset;
		  }
		  delete base;
		  if ((reg->type()==NetNet::UNRESOLVED_WIRE) && !is_force) {
			ivl_assert(*this, reg->coerced_to_uwire());
			if (reg->test_part_driven(rel_base+wid-1, rel_base)) {
			      report_mixed_assignment_conflict_("part select");
			      des->errors += 1;
			      return false;
			}
		  }
		    /* If we cover the entire lvalue just skip the select. */
		  if (rel_base == 0 && wid == reg->vector_width()) return true;
		  base = new NetEConst(verinum(rel_base));
		  if (warn_ob_select) {
			if (rel_base < 0) {
			      cerr << get_fileline() << ": warning: " << reg->name();
			      if (reg->unpacked_dimensions() > 0) cerr << "[]";
			      cerr << "[" << lsv;
			      if (use_sel == index_component_t::SEL_IDX_UP) {
				    cerr << "+:";
			      } else {
				    cerr << "-:";
			      }
			      cerr << wid << "] is selecting before vector." << endl;
			}
			if (rel_base + wid > reg->vector_width()) {
			      cerr << get_fileline() << ": warning: " << reg->name();
			      if (reg->unpacked_dimensions() > 0) cerr << "[]";
			      cerr << "[" << lsv;
			      if (use_sel == index_component_t::SEL_IDX_UP) {
				    cerr << "+:";
			      } else {
				    cerr << "-:";
			      }
			      cerr << wid << "] is selecting after vector." << endl;
			}
		  }
	    } else if (warn_ob_select) {
		  cerr << get_fileline() << ": warning: L-value indexed part "
		       << "select of " << reg->name();
		  if (reg->unpacked_dimensions() > 0) cerr << "[]";
		  cerr << " has an undefined base." << endl;
	    }
      } else {
	    if (need_const_idx) {
		  cerr << get_fileline() << ": error: '" << reg->name()
		       << "' base index must be a constant in this context."
		       << endl;
		  des->errors += 1;
		  return false;
	    }
	    if ((reg->type()==NetNet::UNRESOLVED_WIRE) && !is_force) {
		  ivl_assert(*this, reg->coerced_to_uwire());
		  report_mixed_assignment_conflict_("part select");
		  des->errors += 1;
		  return false;
	    }
	    ivl_assert(*this, prefix_indices.size()+1 == reg->packed_dims().size());
	      /* Correct the mux for the range of the vector. */
	    if (use_sel == index_component_t::SEL_IDX_UP) {
		  base = normalize_variable_part_base(prefix_indices, base,
						      reg, wid, true);
		  sel_type = IVL_SEL_IDX_UP;
	    } else {
		    // This is assumed to be a SEL_IDX_DO.
		  base = normalize_variable_part_base(prefix_indices, base,
						      reg, wid, false);
		  sel_type = IVL_SEL_IDX_DOWN;
	    }
      }

      if (debug_elaborate)
	    cerr << get_fileline() << ": debug: Set part select width="
		 << wid << ", base=" << *base << endl;

      lv->set_part(base, wid, sel_type);

      return true;
}

/*
 * When the l-value turns out to be a class object, this method is
 * called with the bound variable, and the method path. For example,
 * if path_=a.b.c and a.b binds to the variable, then sig is b, and
 * member_path=c. if path_=obj.base.x, and base_path=obj, then sig is
 * obj, and member_path=base.x.
 */
NetAssign_* PEIdent::elaborate_lval_net_class_member_(Design*des, NetScope*scope,
				    ivl_type_t root_type, NetNet*sig,
				    pform_name_t member_path,
				    const list<index_component_t>&base_index) const
{
      if (debug_elaborate) {
	    cerr << get_fileline() << ": PEIdent::elaborate_lval_net_class_member_: "
		 << "l-value is property " << member_path
		 << " of " << sig->name() << "." << endl;
      }

	      ivl_assert(*this, root_type);

	// Modport direction enforcement (IEEE 1800-2017 25.5): an
	// interface port declared with a modport may not WRITE a
	// member the modport lists as input. The port variable
	// carries its modport name in the ivl_modport attribute.
      if (!member_path.empty()) {
	    verinum mp_attr = sig->attribute(perm_string::literal("ivl_modport"));
	    const netclass_t*ifc =
		  dynamic_cast<const netclass_t*>(sig->net_type());
	    if (mp_attr != verinum() && ifc && ifc->is_interface()) {
		  std::string mp_name = mp_attr.as_string();
		  auto im = pform_modules.find(ifc->get_name());
		  if (im != pform_modules.end()) {
			auto mit = im->second->modports.find(
			      lex_strings.make(mp_name.c_str()));
			if (mit != im->second->modports.end()) {
			      perm_string member = member_path.front().name;
			      auto sp = mit->second->simple_ports.find(member);
			      if (sp != mit->second->simple_ports.end()
				  && sp->second.first == NetNet::PINPUT) {
				    cerr << get_fileline() << ": error: "
					 << "cannot write to '" << member
					 << "' through modport '" << mp_name
					 << "' of interface '"
					 << ifc->get_name()
					 << "' — it is an input in that"
					 << " modport (IEEE 1800-2017 25.5)."
					 << endl;
				    des->errors += 1;
				    return 0;
			      }
				// Modport member visibility (IEEE
				// 1800-2017 25.5): only members the
				// modport lists (as ports or via
				// import/export) are accessible
				// through it. A write to any other
				// interface member used to compile
				// silently.
			      if (sp == mit->second->simple_ports.end()
				  && mit->second->import_ports.count(member) == 0
				  && mit->second->export_ports.count(member) == 0
				  && ifc->property_idx_from_name(member) >= 0) {
				    cerr << get_fileline() << ": error: "
					 << "cannot access '" << member
					 << "' through modport '" << mp_name
					 << "' of interface '"
					 << ifc->get_name()
					 << "' — it is not listed in that"
					 << " modport (IEEE 1800-2017 25.5)."
					 << endl;
				    des->errors += 1;
				    return 0;
			      }
			}
		  }
	    }
      }

	      NetAssign_*lv = 0;
	      if (!base_index.empty() && sig->darray_type()) {
		    if (base_index.size() != 1) {
			  cerr << get_fileline() << ": sorry: "
			       << "Only single-dimension index of dynamic/queue class l-value roots is supported."
			       << endl;
			  des->errors += 1;
			  return 0;
		    }

		    const index_component_t&root_index = base_index.back();
		    if (root_index.sel == index_component_t::SEL_BIT_LAST) {
			  cerr << get_fileline() << ": sorry: "
			       << "Last element select of dynamic/queue class l-value roots is not supported."
			       << endl;
			  des->errors += 1;
			  return 0;
		    }
		    if (root_index.msb == 0 || root_index.lsb != 0
			|| root_index.sel != index_component_t::SEL_BIT) {
			  cerr << get_fileline() << ": sorry: "
			       << "Only simple index selects of dynamic/queue class l-value roots are supported."
			       << endl;
			  des->errors += 1;
			  return 0;
		    }

		    NetExpr*root_word_index = elab_and_eval(des, scope, root_index.msb, -1);
		    if (!root_word_index)
			  return 0;

		    lv = new NetAssign_(sig);
		    lv->set_word(root_word_index);
		    root_type = lv->net_type();
	      } else if (!base_index.empty() && sig->unpacked_dimensions() > 0) {
		      // Static unpacked array of class handles, e.g.
		      // `c arr[N]; arr[i].prop = ...`. Convert the element
		      // index to canonical form (accounting for the array's
		      // declared range) exactly as elaborate_lval_net_word_
		      // does, then address the element. Previously only the
		      // dynamic-array case above was handled, so the index was
		      // silently dropped and the l-value referenced the whole
		      // array -- a null word index then crashed tgt-vvp.
		    std::list<NetExpr*> unpacked_indices;
		    std::list<long> unpacked_indices_const;
		    indices_flags flags;
		    indices_to_expressions(des, scope, this,
					   base_index, sig->unpacked_dimensions(),
					   false, flags,
					   unpacked_indices, unpacked_indices_const);

		    NetExpr*canon_index = 0;
		    if (flags.invalid || flags.undefined) {
			  // leave canon_index null -> ignored below
		    } else if (flags.variable) {
			  canon_index = normalize_variable_unpacked(sig, unpacked_indices);
		    } else {
			  canon_index = normalize_variable_unpacked(sig, unpacked_indices_const);
		    }
		    if (canon_index == 0)
			  canon_index = new NetEConst(verinum(verinum::Vx));
		    canon_index->set_line(*this);

		    lv = new NetAssign_(sig);
		    lv->set_word(canon_index);
		    root_type = lv->net_type();
	      }

	// Iterate over the member_path. This handles nested class
	// object, by generating nested NetAssign_ object. We start
	// with lv==0, so the front of the member_path is the member
	// of the outermost class. This generates an lv from sig. Then
	// iterate over the remaining of the member_path, replacing
	// the outer lv with an lv that nests the lv from the previous
	// iteration.
	      do {
		      ivl_type_t owner_type = lv ? lv->net_type() : root_type;
		      const netclass_t*owner_class = dynamic_cast<const netclass_t*>(owner_type);
		      const netstruct_t*owner_struct = dynamic_cast<const netstruct_t*>(owner_type);
		      // Packed struct field access within a VIF/class property: compute
	      // the bit offset of the named field within the packed struct and
	      // encode as a part-select on the current lv (read-modify-write at
	      // runtime via %store/prop/v/bits).
	      if (!owner_class && owner_struct && owner_struct->packed()) {
		    const name_component_t&field_comp = member_path.front();
		    perm_string field_name = field_comp.name;
		    unsigned long member_off = 0;
		    const netstruct_t::member_t*mbr =
			  owner_struct->packed_member(field_name, member_off);
		    if (!mbr) {
			  cerr << get_fileline() << ": error: Packed struct "
			       << "does not have member " << field_name << "." << endl;
			  des->errors += 1;
			  return 0;
		    }
		    long field_wid = mbr->net_type->packed_width();
		    if (field_wid <= 0) {
			  cerr << get_fileline() << ": sorry: packed struct field "
			       << field_name << " has non-positive width." << endl;
			  return 0;
		    }
		    /* Cast disambiguates `verinum(uint64_t, unsigned)` from the
		       `verinum(V, unsigned, bool)` constructor — older gcc/clang
		       on macOS/MinGW reject the implicit conversion. */
		    // Pass the field's own type (not just the width) so
		    // NetAssign_::net_type()/expr_type() report the field's
		    // packed type. Otherwise net_type() is null and expr_type()
		    // falls back to the class handle's IVL_VT_CLASS, which
		    // corrupts r-value elaboration (the assigned value comes out
		    // as a null-handle test) and crashes the runtime.
		    // A bit/part-select ON the field (e.g. `.b[3:0]`) narrows
		    // the write to a sub-range: compose the field base offset
		    // within the struct with the canonical offset of the
		    // sub-select so only those bits are written (else the whole
		    // field is clobbered).
		    long sub_off = 0;
		    unsigned sub_wid = (unsigned)field_wid;
		    ivl_type_t part_type = mbr->net_type;
		    if (!field_comp.index.empty()) {
			  const netvector_t*fvec =
				dynamic_cast<const netvector_t*>(mbr->net_type);
			  const index_component_t&fs = field_comp.index.front();
			  bool ok = false;
			  if (fvec && field_comp.index.size() == 1
			      && fvec->packed_dims().size() == 1
			      && fvec->packed_dims()[0].defined()) {
				long bmsb = fvec->packed_dims()[0].get_msb();
				long blsb = fvec->packed_dims()[0].get_lsb();
				bool desc = bmsb >= blsb;
				auto canon = [&](long i)->long {
				      return desc ? (i-blsb) : (blsb-i); };
				if (fs.sel == index_component_t::SEL_BIT
				    && fs.msb && !fs.lsb) {
				      NetExpr*ie = elab_and_eval(des, scope, fs.msb, -1);
				      NetEConst*iec = dynamic_cast<NetEConst*>(ie);
				      if (iec && iec->value().is_defined()) {
					    sub_off = canon(iec->value().as_long());
					    sub_wid = 1;
					    part_type = new netvector_t(
						  fvec->base_type(), 0, 0);
					    ok = true;
				      }
				} else if (fs.sel == index_component_t::SEL_PART
					   && fs.msb && fs.lsb) {
				      NetExpr*me = elab_and_eval(des, scope, fs.msb, -1);
				      NetExpr*le = elab_and_eval(des, scope, fs.lsb, -1);
				      NetEConst*mec = dynamic_cast<NetEConst*>(me);
				      NetEConst*lec = dynamic_cast<NetEConst*>(le);
				      if (mec && lec && mec->value().is_defined()
					  && lec->value().is_defined()) {
					    long mv = mec->value().as_long();
					    long lvv = lec->value().as_long();
					    long ca = canon(mv), cb = canon(lvv);
					    sub_off = ca < cb ? ca : cb;
					    sub_wid = (unsigned)
						  ((mv >= lvv ? mv-lvv : lvv-mv) + 1);
					    part_type = new netvector_t(
						  fvec->base_type(),
						  (long)sub_wid - 1, 0);
					    ok = true;
				      }
				}
			  }
			  if (!ok) {
				cerr << get_fileline() << ": sorry: this form of "
				     << "select on packed-struct field " << field_name
				     << " (variable/indexed/nested) is not yet"
				     << " supported." << endl;
				des->errors += 1;
				return 0;
			  }
		    }
		    member_path.pop_front();

		    /* Cast disambiguates `verinum(uint64_t, unsigned)` from the
		       `verinum(V, unsigned, bool)` constructor. Pass the (sub-)
		       field's own packed type so NetAssign_::net_type()/
		       expr_type() report it (else expr_type() falls back to the
		       handle's IVL_VT_CLASS and corrupts r-value elaboration). */
		    lv->set_part(new NetEConst(
				   verinum((uint64_t)(member_off + sub_off), 64u)),
				 part_type);
		    if (!member_path.empty()) {
			  cerr << get_fileline() << ": warning: "
			       << "Deeply nested packed struct field in VIF property "
			       << "(compile-progress: only outermost field written)." << endl;
		    }
		    break;
	      }

	      if (!owner_class && !(gn_system_verilog() && owner_struct && !owner_struct->packed())) {
			    if (const char*trace = getenv("IVL_NESTED_PATH_TRACE")) {
				  cerr << get_fileline() << ": debug: "
				       << "nested l-value tail rejected"
				       << " trace=" << trace
				       << " member=" << member_path.front().name
				       << " owner_type=";
				  if (owner_type)
					owner_type->debug_dump(cerr);
				  else
					cerr << "<null>";
				  cerr << endl;
			    }
			    // Compile-progress: assoc-array element property assignment
			    // such as assoc[key].prop = val is not yet fully supported
			    // as an l-value. Downgrade to warning and ignore.
			    cerr << get_fileline() << ": warning: "
			         << "Nested member path is not a class/struct l-value in this context"
			         << " (compile-progress: assignment ignored)."
			         << endl;
			    return 0;
		      }

		      // Start with the first component of the member path...
		    perm_string method_name = peek_head_name(member_path);
	      // Pull that component from the member_path. We need to
	      // know the current member being worked on, and will
	      // need to know if there are more members to be worked on.
	    name_component_t member_cur = member_path.front();
	    member_path.pop_front();

	    if (debug_elaborate) {
		  cerr << get_fileline() << ": PEIdent::elaborate_lval_net_class_member_: "
		       << "Processing member_cur=" << member_cur
		       << endl;
	    }

	      // Make sure the property/member is really present. If not,
	      // then generate an error message and return an error.
	    int pidx = -1;
	    ivl_type_t ptype = nullptr;
	    if (owner_class) {
		  pidx = const_cast<netclass_t*>(owner_class)->ensure_property_decl(des, method_name);
		  if (pidx < 0) {
			if (gn_system_verilog()) {
			      /* Compile-progress fallback: tolerate unknown members
			         (including UVM iteration helpers). Ignore the l-value. */
			      if (method_name != perm_string::literal("for_each_idx")) {
				    cerr << get_fileline() << ": warning: Class " << owner_class->get_name()
					 << " does not have a property " << method_name
					 << " (compile-progress fallback, ignoring l-value)." << endl;
			      }
			      return 0;
			}
			cerr << get_fileline() << ": error: Class " << owner_class->get_name()
			     << " does not have a property " << method_name << "." << endl;
			des->errors += 1;
			return 0;
		  }

		  property_qualifier_t qual = owner_class->get_prop_qual(pidx);
		  if (qual.test_local() && ! owner_class->test_scope_is_method(scope)) {
			cerr << get_fileline() << ": error: "
			     << "Local property " << owner_class->get_prop_name(pidx)
			     << " is not accessible (l-value) in this context."
			     << " (scope=" << scope_path(scope) << ")" << endl;
			des->errors += 1;

		  } else if (qual.test_static()) {

			  // Special case: this is a static property. Ignore the
			  // "this" sig and use the property itself, which is not
			  // part of the sig, as the l-value.
			NetNet*psig = owner_class->find_static_property(method_name);
			ivl_assert(*this, psig);

			lv = new NetAssign_(psig);
			return lv;

		  } else if (qual.test_const()) {
		       if (owner_class->get_prop_initialized(pidx)) {
			      cerr << get_fileline() << ": error: "
				   << "Property " << owner_class->get_prop_name(pidx)
				   << " is constant in this method."
				   << " (scope=" << scope_path(scope) << ")" << endl;
			      des->errors++;
		       } else if (scope->basename() != "new" && scope->basename() != "new@") {
			      cerr << get_fileline() << ": error: "
				   << "Property " << owner_class->get_prop_name(pidx)
				   << " is constant in this method."
				   << " (scope=" << scope_path(scope) << ")" << endl;
			      des->errors++;
		       } else {
			      owner_class->set_prop_initialized(pidx);

			      if (debug_elaborate) {
				    cerr << get_fileline() << ": PEIdent::elaborate_lval_method_class_member_: "
					 << "Found initializers for property " << owner_class->get_prop_name(pidx) << endl;
			      }
		       }
		  }

		  ptype = owner_class->get_prop_type(pidx);

		  // If ptype is not a class type (e.g. it was stored as an
		  // integer-handle fallback due to a circular-elaboration race),
		  // try to recover the real class type directly from the scope
		  // hierarchy, bypassing the elaborate_type cache entirely.
		  if (!dynamic_cast<const netclass_t*>(ptype)) {
			const NetScope*cls_scope = owner_class->class_scope();
			const PClass*pclass = cls_scope ? cls_scope->class_pform() : nullptr;
			if (pclass && pclass->type) {
			      perm_string pname = perm_string::literal(owner_class->get_prop_name(pidx));
			      auto pit = pclass->type->properties.find(pname);
			      if (pit != pclass->type->properties.end() && pit->second.type) {
				    perm_string resolved_name;
				    if (const typeref_t*tref =
					  dynamic_cast<const typeref_t*>(pit->second.type.get())) {
					  if (tref->typedef_ref())
						resolved_name = tref->typedef_ref()->name;
				    } else if (const class_type_t*ct =
					  dynamic_cast<const class_type_t*>(pit->second.type.get())) {
					  resolved_name = ct->name;
				    }
				    if (!resolved_name.nil()) {
					  NetScope*search_scope =
						cls_scope ? const_cast<NetScope*>(cls_scope) : scope;
					  if (netclass_t*resolved =
						ensure_visible_class_type(des, search_scope, resolved_name)) {
						const_cast<netclass_t*>(owner_class)->repair_property_type(
							pname, resolved);
						ptype = resolved;
					  }
				    }
			      }
			}
		  }
	    } else {
		  unsigned long member_off = 0;
		  const netstruct_t::member_t*member =
			owner_struct->packed_member(method_name, member_off);
		  if (!member) {
			cerr << get_fileline() << ": error: Struct "
			     << *owner_struct << " does not have a member "
			     << method_name << "." << endl;
			des->errors += 1;
			return 0;
		  }
		  const auto&members = owner_struct->members();
		  pidx = member - &members.front();
		  ptype = member->net_type;
	    }

	    lv = lv? new NetAssign_(lv) : new NetAssign_(sig);
	    lv->set_property(method_name, pidx);

	    NetExpr *word_index = nullptr;
	    bool applied_multi_dyn_word_index = false;
	    if (!member_cur.index.empty()) {
		  if (const netsarray_t *stype = dynamic_cast<const netsarray_t*>(ptype)) {
			word_index = make_canonical_index(des, scope, this,
							  member_cur.index, stype, false);

		  } else if (dynamic_cast<const netdarray_t*>(ptype)) {
			size_t idx_pos = 0;
			const size_t idx_count = member_cur.index.size();
			for (const auto&index_tail : member_cur.index) {
			      if (index_tail.sel == index_component_t::SEL_BIT_LAST) {
				    cerr << get_fileline() << ": sorry: "
				         << "Last-element select of dynamic/queue class properties is not supported."
				         << endl;
				    des->errors += 1;
				    break;
			      }
			      if (index_tail.msb == 0 || index_tail.lsb != 0
				  || index_tail.sel != index_component_t::SEL_BIT) {
				    cerr << get_fileline() << ": sorry: "
				         << "Part-select of dynamic/queue class properties is not supported."
				         << endl;
				    des->errors += 1;
				    break;
			      }

			      NetExpr*idx_expr = elab_and_eval(des, scope, index_tail.msb, -1);
			      if (!idx_expr)
				    break;

			      if (applied_multi_dyn_word_index)
				    lv = new NetAssign_(lv);
			      lv->set_word(idx_expr);
			      applied_multi_dyn_word_index = true;

			      ptype = lv->net_type();
			      idx_pos += 1;
			      if (idx_pos < idx_count) {
				    if (!dynamic_cast<const netarray_t*>(ptype)) {
					  // Compile-progress: part-select on a dynamic/assoc array
					  // element after the first index is applied (e.g.
					  // assoc[key][1:0] = 0) is not yet fully supported as an
					  // l-value. Silently ignore the remaining indices.
					  cerr << get_fileline() << ": warning: "
					       << "Index expressions don't apply to this type of property"
					       << " (compile-progress: assignment ignored)."
					       << endl;
					  break;
				    }
			      }
			}

		  } else if (const netvector_t*pvec =
			     dynamic_cast<const netvector_t*>(ptype)) {
			// A bit- or part-select of a packed-vector member is a
			// PARTIAL WRITE. This applies both to a class-OBJECT
			// property (owner_class) and to a member of a plain
			// UNPACKED struct (owner_struct): both are cobject-backed
			// and expose the same vec4 property API, so both must
			// read-modify-write (set_part) the vector rather than
			// store the whole property (which silently clobbers the
			// untouched bits) or set a word index (which mis-treats
			// the vector as an unpacked array and crashes the
			// runtime). Constant offsets fold to a NetEConst; run-time
			// offsets flow to the %store/prop/v/bits/x codegen path.
			const netranges_t&dims = pvec->packed_dims();
			const index_component_t&sel = member_cur.index.front();

			{
			      bool handled = false;

			      if (member_cur.index.size() == 1 && dims.size() == 1
				  && dims[0].defined()) {
				    const long base_msb = dims[0].get_msb();
				    const long base_lsb = dims[0].get_lsb();
				    const bool descending = base_msb >= base_lsb;
				      // Build the part's own packed data type so
				      // NetAssign_::net_type()/expr_type() report
				      // the selected sub-vector (logic/bit) rather
				      // than falling back to the class-handle's
				      // IVL_VT_CLASS, which corrupts r-value
				      // elaboration.
				    auto make_part_type = [&](unsigned w)->ivl_type_t {
					  return new netvector_t(pvec->base_type(),
								 (long)w - 1, 0);
				    };
				      // Canonicalize a (possibly non-constant)
				      // source-space index to an LSB-0 bit offset.
				      // Constant offsets fold to NetEConst so the
				      // constant %store/prop/v/bits path is used;
				      // variable offsets flow to the /x path. Only
				      // the descending (msb>=lsb) direction is
				      // handled for variable offsets; ascending
				      // packed vectors fall through to the sorry.
				    auto canon_expr =
					  [&](NetExpr*e)->NetExpr* {
					  if (NetEConst*ec =
						dynamic_cast<NetEConst*>(e)) {
						if (!ec->value().is_defined())
						      return nullptr;
						long i = ec->value().as_long();
						long off = descending
							 ? (i - base_lsb)
							 : (base_lsb - i);
						return new NetEConst(
						      verinum((int64_t)off));
					  }
					  if (!descending)
						return nullptr;
					  if (base_lsb == 0)
						return e;
					  return new NetEBAdd('-', e,
						new NetEConst(verinum(
						  (int64_t)base_lsb)), 32, true);
				    };

				    NetExpr*off_expr = nullptr;
				    unsigned wid = 0;

				    if (sel.sel == index_component_t::SEL_BIT
					&& sel.msb && !sel.lsb) {
					  NetExpr*ie = elab_and_eval(des, scope,
								     sel.msb, -1);
					  if (ie) {
						off_expr = canon_expr(ie);
						wid = 1;
					  }
				    } else if ((sel.sel == index_component_t::SEL_IDX_UP
						|| sel.sel == index_component_t::SEL_IDX_DO)
					       && sel.msb && sel.lsb) {
					  NetExpr*be = elab_and_eval(des, scope,
								     sel.msb, -1);
					  NetExpr*we = elab_and_eval(des, scope,
								     sel.lsb, -1);
					  NetEConst*wec =
						dynamic_cast<NetEConst*>(we);
					  if (be && wec
					      && wec->value().is_defined()
					      && wec->value().as_long() > 0) {
						long w = wec->value().as_long();
						off_expr = canon_expr(be);
						  // [b -: w] addresses down from
						  // b, so its LSB is b-(w-1).
						if (off_expr
						    && sel.sel == index_component_t::SEL_IDX_DO
						    && w > 1)
						      off_expr = new NetEBAdd('-',
							off_expr,
							new NetEConst(verinum(
							  (int64_t)(w-1))),
							32, true);
						wid = (unsigned)w;
					  }
				    } else if (sel.sel == index_component_t::SEL_PART
					       && sel.msb && sel.lsb) {
					  NetExpr*me = elab_and_eval(des, scope,
								     sel.msb, -1);
					  NetExpr*le = elab_and_eval(des, scope,
								     sel.lsb, -1);
					  NetEConst*mec =
						dynamic_cast<NetEConst*>(me);
					  NetEConst*lec =
						dynamic_cast<NetEConst*>(le);
					  if (mec && lec
					      && mec->value().is_defined()
					      && lec->value().is_defined()) {
						long mv = mec->value().as_long();
						long lv_ = lec->value().as_long();
						long ca = descending
							? (mv-base_lsb)
							: (base_lsb-mv);
						long cb = descending
							? (lv_-base_lsb)
							: (base_lsb-lv_);
						long off = ca < cb ? ca : cb;
						off_expr = new NetEConst(
						      verinum((int64_t)off));
						wid = (unsigned)
						      ((mv >= lv_ ? mv-lv_
								  : lv_-mv) + 1);
					  }
				    }

				    if (off_expr && wid > 0) {
					  lv->set_part(off_expr,
						       make_part_type(wid));
					  handled = true;
				    }
			      }

			      // Multi-dimensional packed vector (e.g. `logic [3:0][7:0]`):
			      // a slice/element write `m[i]`, a full bit select `m[i][j]`,
			      // or an element then part-select `m[i][3:0]`, for CONSTANT
			      // indices. Reuse prefix_to_slice to map the leading bit indices
			      // to a canonical (LSB-0) offset and slice width, then narrow by
			      // an optional trailing part-select on the innermost dimension.
			      // (IEEE 1800-2017 7.4.) Variable multi-dim indices remain a
			      // loud sorry below.
			      if (!handled && !member_cur.index.empty() && dims.size() > 1) {
			            bool all_def = true;
			            for (size_t di = 0; di < dims.size(); di += 1)
			      	    if (!dims[di].defined()) all_def = false;

			            std::list<long> bit_ix;
			            bool ok = all_def;
			            bool has_part = false;
			            long part_msb = 0, part_lsb = 0;
			            unsigned n_comp = member_cur.index.size();
			            unsigned ci = 0;
			            for (const index_component_t&ic : member_cur.index) {
			      	    ci += 1;
			      	    if (ic.sel == index_component_t::SEL_BIT
			      		&& ic.msb && !ic.lsb) {
			      		  NetExpr*e = elab_and_eval(des, scope, ic.msb, -1);
			      		  NetEConst*ec = dynamic_cast<NetEConst*>(e);
			      		  if (ec && ec->value().is_defined())
			      			bit_ix.push_back(ec->value().as_long());
			      		  else ok = false;
			      	    } else if (ic.sel == index_component_t::SEL_PART
			      		       && ic.msb && ic.lsb && ci == n_comp) {
			      		  has_part = true;
			      		  NetExpr*me = elab_and_eval(des, scope, ic.msb, -1);
			      		  NetExpr*le = elab_and_eval(des, scope, ic.lsb, -1);
			      		  NetEConst*mec = dynamic_cast<NetEConst*>(me);
			      		  NetEConst*lec = dynamic_cast<NetEConst*>(le);
			      		  if (mec && lec && mec->value().is_defined()
			      		      && lec->value().is_defined()) {
			      			part_msb = mec->value().as_long();
			      			part_lsb = lec->value().as_long();
			      		  } else ok = false;
			      	    } else {
			      		  ok = false;
			      	    }
			            }

			            if (ok && !bit_ix.empty() && bit_ix.size() <= dims.size()) {
			      	    long loff = 0; unsigned long lwid = 0;
			      	    std::list<long> prefix = bit_ix;
			      	    long sb = prefix.back(); prefix.pop_back();
			      	    if (prefix_to_slice(dims, prefix, sb, loff, lwid)) {
			      		  long foff = loff;
			      		  unsigned fwid = (unsigned)lwid;
			      		  bool part_ok = true;
			      		  if (has_part) {
			      			const netrange_t&inr = dims.back();
			      			bool idesc = inr.get_msb() >= inr.get_lsb();
			      			long ca = idesc ? part_msb-inr.get_lsb()
			      					: inr.get_lsb()-part_msb;
			      			long cb = idesc ? part_lsb-inr.get_lsb()
			      					: inr.get_lsb()-part_lsb;
			      			long lo = ca < cb ? ca : cb;
			      			unsigned pw = (unsigned)((part_msb>=part_lsb
			      				? part_msb-part_lsb : part_lsb-part_msb)+1);
			      			if (lo < 0 || lo + (long)pw > (long)lwid)
			      			      part_ok = false;
			      			else { foff = loff + lo; fwid = pw; }
			      		  }
			      		  if (part_ok && fwid > 0) {
			      			lv->set_part(new NetEConst(verinum((int64_t)foff)),
			      				     new netvector_t(pvec->base_type(),
			      						     (long)fwid - 1, 0));
			      			handled = true;
			      		  }
			      	    }
			            }
			      }

			      if (!handled) {
				    cerr << get_fileline() << ": sorry: "
					 << "This form of partial write to packed "
					 << "vector member " << method_name
					 << " (unsupported select form) is not"
					 << " yet supported." << endl;
				    des->errors += 1;
			      }
			}
		  } else {
			cerr << get_fileline() << ": warning: "
			     << "Index expressions on this property type used as "
			     << "compile-progress fallback." << endl;
		  }
	    }

	    if (const netuarray_t *tmp_ua = dynamic_cast<const netuarray_t*>(ptype)) {
		  const auto &dims = tmp_ua->static_dimensions();

		  if (debug_elaborate) {
			cerr << get_fileline() << ": PEIdent::elaborate_lval_method_class_member_: "
			     << "Property " << method_name
			     << " has " << dims.size() << " dimensions, "
			     << " got " << member_cur.index.size() << " indices." << endl;
			if (word_index) {
			      cerr << get_fileline() << ": PEIdent::elaborate_lval_method_class_member_: "
				   << "Canonical index is:" << *word_index << endl;
			}
		  }

		  if (!member_cur.index.empty() && dims.size() != member_cur.index.size()) {
			cerr << get_fileline() << ": error: "
			     << "Got " << member_cur.index.size() << " indices, "
			     << "expecting " << dims.size()
			     << " to index the property " << method_name << "." << endl;
			des->errors++;
		  }
	    }

	    if (word_index)
		  lv->set_word(word_index);

	      // The next-step type must come from the l-value node after any
	      // property and index selections are applied (e.g. m_events[obj]
	      // should yield the element type, not the container property type).
	    ivl_type_t next_type = lv->net_type();

      } while (!member_path.empty());


      return lv;
}

/*
 * This method is caled to handle l-value identifiers that are packed
 * structs. The lv is already attached to the variable, so this method
 * calculates the part select that is defined by the member_path. For
 * example, if the path_ is main.sub.sub_local, and the variable is
 * main, then we know at this point that main is a packed struct, and
 * lv contains the reference to the bound variable (main). In this
 * case member_path==sub.sub_local, and it is up to this method to
 * work out the part select that the member_path represents.
 */
bool PEIdent::elaborate_lval_net_packed_member_(Design*des, NetScope*scope,
						NetAssign_*lv,
						pform_name_t member_path,
						bool is_force) const
{
      if (debug_elaborate) {
	    cerr << get_fileline() << ": PEIdent::elaborate_lval_net_packed_member_: "
		 << "path_=" << path_
		 << " member_path=" << member_path
		 << endl;
      }

      NetNet*reg = lv->sig();
      ivl_assert(*this, reg);

      const netstruct_t*struct_type = reg->struct_type();
      ivl_assert(*this, struct_type);
      if (debug_elaborate) {
	    cerr << get_fileline() << ": PEIdent::elaborate_lval_net_packed_member_: "
		 << "Type=" << *struct_type
		 << endl;
      }

      if (! struct_type->packed()) {
	      // SV compile-progress fallback: unpacked struct l-value
	      // member access is not fully implemented yet.  Instead of
	      // rejecting the entire statement, walk the member path to
	      // find the leaf member type and create a simplified l-value
	      // that allows elaboration to continue.
	    const netstruct_t*cur_stype = struct_type;
	    ivl_type_t leaf_type = nullptr;
	    pform_name_t mp_copy = member_path;
	    while (!mp_copy.empty() && cur_stype) {
		  const name_component_t& mc = mp_copy.front();
		  unsigned long dummy_off;
		  const netstruct_t::member_t* mbr =
			cur_stype->packed_member(mc.name, dummy_off);
		  if (!mbr) break;
		  leaf_type = mbr->net_type;
		  mp_copy.pop_front();
		  cur_stype = dynamic_cast<const netstruct_t*>(leaf_type);
	    }
	    if (leaf_type) {
		  long pw = leaf_type->packed_width();
		  if (pw > 0) {
			lv->set_part(new NetEConst(verinum((uint64_t)0, 32)),
				     (unsigned)pw);
		  }
	    }
	    return true;
      }

	// Looking for the base name. We need that to know about
	// indices we may need to apply. This is to handle the case
	// that the base is an array of structs, and not just a
	// struct.
      pform_name_t::const_reverse_iterator name_idx = path_.name.rbegin();
      for (size_t idx = 1 ; idx < member_path.size() ; idx += 1)
	    ++ name_idx;
      if (name_idx->name != peek_head_name(member_path)) {
	    cerr << get_fileline() << ": internal error: "
		 << "name_idx=" << name_idx->name
		 << ", expecting member_name=" << peek_head_name(member_path)
		 << endl;
	    des->errors += 1;
	    return false;
      }
      ivl_assert(*this, name_idx->name == peek_head_name(member_path));
      ++ name_idx;
      const name_component_t&name_base = *name_idx;

	// An UNPACKED array of a PACKED struct (`pair_t arr[N]; arr[i].m =`)
	// indexes the unpacked element with name_base.index and then
	// part-selects the member off the element vector. Set the array
	// word index on the l-value here; the member part-select (off /
	// use_width computed below) is relative to the element.
      bool ua_of_packed = reg->unpacked_dimensions() > 0
	    && struct_type->packed()
	    && !name_base.index.empty()
	    && name_base.index.size() == reg->unpacked_dimensions();
      if (ua_of_packed) {
	    std::list<NetExpr*> ua_idx;
	    std::list<long> ua_idx_const;
	    indices_flags ua_flags;
	    indices_to_expressions(des, scope, this, name_base.index,
				   reg->unpacked_dimensions(), false, ua_flags,
				   ua_idx, ua_idx_const);
	    NetExpr*ua_canon = 0;
	    if (!ua_flags.invalid && !ua_flags.undefined)
		  ua_canon = ua_flags.variable
			? normalize_variable_unpacked(reg, ua_idx)
			: normalize_variable_unpacked(reg, ua_idx_const);
	    if (!ua_canon)
		  return false;
	    ua_canon->set_line(*this);
	    lv->set_word(ua_canon);
      } else {
	      // Shouldn't be seeing unpacked arrays of packed structs...
	    ivl_assert(*this, reg->unpacked_dimensions() == 0);
      }

	// These make up the "part" select that is the equivilent of
	// following the member path through the nested structs. To
	// start with, the off[set] is zero, and use_width is the
	// width of the entire variable. The first member_comp is at
	// some offset within the variable, and will have a reduced
	// width. As we step through the member_path the off
	// increases, and use_width shrinks.
      unsigned long off = 0;
      unsigned long use_width = struct_type->packed_width();
      ivl_type_t member_type;

      pform_name_t completed_path;
      do {
	    const name_component_t member_comp = member_path.front();
	    const perm_string&member_name = member_comp.name;

	    if (debug_elaborate) {
		  cerr << get_fileline() << ": PEIdent::elaborate_lval_net_packed_member_: "
		       << "Processing member_comp=" << member_comp
		       << " (completed_path=" << completed_path << ")"
		       << endl;
	    }

	      // This is a packed member, so the name is of the form
	      // "a.b[...].c[...]" which means that the path_ must have at
	      // least 2 components. We are processing "c[...]" at that
	      // point (otherwise known as member_name) and we have a
	      // reference to it in member_comp.

	      // The member_path is the members we want to follow for the
	      // variable. For example, main[N].a.b may have main[N] as the
	      // base_name, and member_path=a.b. The member_name is the
	      // start of the member_path, and is "a". The member_name
	      // should be a member of the struct_type type.

	      // Calculate the offset within the packed structure of the
	      // member, and any indices. We will add in the offset of the
	      // struct into the packed array later. Note that this works
	      // for packed unions as well (although the offset will be 0
	      // for union members).
	    unsigned long tmp_off;
	    const netstruct_t::member_t* member = struct_type->packed_member(member_name, tmp_off);

	    if (member == 0) {
		  cerr << get_fileline() << ": error: Member " << member_name
		       << " is not a member of struct type of "
		       << reg->name()
		       << "." << completed_path << endl;
		  des->errors += 1;
		  return false;
	    }
	    if (debug_elaborate) {
		  cerr << get_fileline() << ": PEIdent::elaborate_lval_net_packed_member_: "
		       << "Member type: " << *(member->net_type)
		       << endl;
	    }

	    off += tmp_off;
	    ivl_assert(*this, use_width >= (unsigned long)member->net_type->packed_width());
	    use_width = member->net_type->packed_width();

	      // At this point, off and use_width are the part select
	      // expressed by the member_comp, which is a member of the
	      // struct. We can further refine the part select with any
	      // indices that might be present.

	      // Get the index component type. At this point, we only
	      // support bit select or none.
	    index_component_t::ctype_t use_sel = index_component_t::SEL_NONE;
	    if (!member_comp.index.empty())
		  use_sel = member_comp.index.back().sel;

	    if (use_sel != index_component_t::SEL_NONE
		&& use_sel != index_component_t::SEL_BIT
		&& use_sel != index_component_t::SEL_PART) {
		  cerr << get_fileline() << ": sorry: Assignments to part selects of "
			"a struct member are not yet supported." << endl;
		  des->errors += 1;
		  return false;
	    }

	    member_type = member->net_type;

	    if (const netvector_t*mem_vec = dynamic_cast<const netvector_t*>(member->net_type)) {
		    // If the member type is a netvector_t, then it is a
		    // vector of atom or scaler objects. For example, if the
		    // l-value expression is "foo.member[1][2]",
		    // then the member should be something like:
		    //    ... logic [h:l][m:n] member;
		    // There should be index expressions index the vector
		    // down, but there doesn't need to be all of them. We
		    // can, for example, be selecting a part of the vector.

		    // We only need to process this if there are any
		    // index expressions. If not, then the packed
		    // vector can be handled atomically.

		    // In any case, this should be the tail of the
		    // member_path, because the array element of this
		    // kind of array cannot be a struct.
		  if (!member_comp.index.empty()) {
			  // These are the dimensions defined by the type
			const netranges_t&mem_packed_dims = mem_vec->packed_dims();

			if (member_comp.index.size() > mem_packed_dims.size()) {
			      cerr << get_fileline() << ": error: "
				   << "Too many index expressions for member." << endl;
			      des->errors += 1;
			      return false;
			}

			  // Evaluate all but the last index expression, into prefix_indices.
			list<long>prefix_indices;
			bool rc = evaluate_index_prefix(des, scope, prefix_indices, member_comp.index);
			ivl_assert(*this, rc);

			if (debug_elaborate) {
			      cerr << get_fileline() << ": PEIdent::elaborate_lval_net_packed_member_: "
				   << "prefix_indices.size()==" << prefix_indices.size()
				   << ", mem_packed_dims.size()==" << mem_packed_dims.size()
				   << " (netvector_t context)"
				   << endl;
			}

			long tail_off = 0;
			unsigned long tail_wid = 0;
			rc = calculate_part(this, des, scope, member_comp.index.back(), tail_off, tail_wid);
			ivl_assert(*this, rc);

			if (debug_elaborate) {
			      cerr << get_fileline() << ": PEIdent::elaborate_lval_net_packed_member_: "
				   << "calculate_part for tail returns tail_off=" << tail_off
				   << ", tail_wid=" << tail_wid
				   << endl;
			}

			  // Now use the prefix_to_slice function to calculate the
			  // offset and width of the addressed slice of the member.
			long loff;
			unsigned long lwid;
			prefix_to_slice(mem_packed_dims, prefix_indices, tail_off, loff, lwid);

			if (debug_elaborate) {
			      cerr << get_fileline() << ": PEIdent::elaborate_lval_net_packed_member_: "
				   << "Calculate loff=" << loff << " lwid=" << lwid
				   << " tail_off=" << tail_off << " tail_wid=" << tail_wid
				   << " off=" << off << " use_width=" << use_width
				   << endl;
			}

			off += loff;
			use_width = lwid * tail_wid;
			member_type = nullptr;
		  }

		    // The netvector_t only has atom elements, to
		    // there is no next struct type.
		  struct_type = 0;

	    } else if (const netparray_t*array = dynamic_cast<const netparray_t*> (member->net_type)) {
		    // If the member is a parray, then the elements
		    // are themselves packed object, including
		    // possibly a struct. Handle this by taking the
		    // part select of the current part of the
		    // variable, then stepping to the element type to
		    // possibly iterate through more of the member_path.

		  ivl_assert(*this, array->packed());

		  if (member_comp.index.empty()) {
			struct_type = 0;
			continue;
		  }

		    // These are the dimensions defined by the type
		  const netranges_t&mem_packed_dims = array->static_dimensions();

		  if (member_comp.index.size() > mem_packed_dims.size()) {
			cerr << get_fileline() << ": error: "
			     << "Too many index expressions for member "
			     << member_name << "." << endl;
			des->errors += 1;
			return false;
		  }

		    // Evaluate all but the last index expression, into prefix_indices.
		  list<long>prefix_indices;
		  bool rc = evaluate_index_prefix(des, scope, prefix_indices, member_comp.index);
		  ivl_assert(*this, rc);

		  if (debug_elaborate) {
			cerr << get_fileline() << ": PEIdent::elaborate_lval_net_packed_member_: "
			     << "prefix_indices.size()==" << prefix_indices.size()
			     << ", mem_packed_dims.size()==" << mem_packed_dims.size()
			     << " (netparray_t context)"
			     << endl;
		  }

		    // Evaluate the last index expression into a constant long.
		  NetExpr*texpr = elab_and_eval(des, scope, member_comp.index.back().msb, -1, true);
		  long tmp;
		  if (texpr == 0 || !eval_as_long(tmp, texpr)) {
			cerr << get_fileline() << ": error: "
			     << "Array index expressions for member " << member_name
			     << " must be constant here." << endl;
			des->errors += 1;
			return false;
		  }

		  delete texpr;

		    // Now use the prefix_to_slice function to calculate the
		    // offset and width of the addressed slice of the member.
		  long loff;
		  unsigned long lwid;
		  prefix_to_slice(mem_packed_dims, prefix_indices, tmp, loff, lwid);

		  ivl_type_t element_type = array->element_type();
		  long element_width = element_type->packed_width();
		  if (debug_elaborate) {
			cerr << get_fileline() << ": PEIdent::elaborate_lval_net_packed_member_: "
			     << "parray subselection loff=" << loff
			     << ", lwid=" << lwid
			     << ", element_width=" << element_width
			     << endl;
		  }

		    // The width and offset calculated from the
		    // indices is actually in elements, and not
		    // bits.
		  off += loff * element_width;
		  use_width = lwid * element_width;

		    // To move on to the next component in the member
		    // path, get the element type. For example, for
		    // the path a.b[1].c, we are processing b[1] here,
		    // and the element type should be a netstruct_t
		    // that will wind up containing the member c.
		  struct_type = dynamic_cast<const netstruct_t*> (element_type);

	    } else if (const netstruct_t*tmp_struct = dynamic_cast<const netstruct_t*> (member->net_type)) {
		    // If the member is itself a struct, then get
		    // ready to go on to the next iteration.
		  struct_type = tmp_struct;

	    } else if (const netenum_t*tmp_enum = dynamic_cast<const netenum_t*> (member->net_type)) {
		    // If the element is an enum, then we don't have
		    // anything special to do.
		  if (debug_elaborate) {
			cerr << get_fileline() << ": PEIdent::elaborate_lval_net_packed_member_: "
			     << "Tail element is an enum: " << *tmp_enum
			     << endl;
		  }
		  struct_type = 0;

	    } else {
		    // Unknown type?
		  cerr << get_fileline() << ": internal error: "
		       << "Unexpected member type? " << *(member->net_type)
		       << endl;
		  des->errors += 1;
		  return false;
	    }

	      // Complete this component of the path, mark it
	      // completed, and set up for the next component.
	    completed_path .push_back(member_comp);
	    member_path.pop_front();

      } while (!member_path.empty() && struct_type != 0);

      if (debug_elaborate) {
	    cerr << get_fileline() << ": PEIdent::elaborate_lval_net_packed_member_: "
		 << "After processing member_path, "
		 << "off=" << off
		 << ", use_width=" << use_width
		 << ", completed_path=" << completed_path
		 << ", member_path=" << member_path
		 << endl;
      }

	// The dimensions in the expression must match the packed
	// dimensions that are declared for the variable. For example,
	// if foo is a packed array of struct, then this expression
	// must be "b[n][m]" with the right number of dimensions to
	// match the declaration of "b".
	// Note that one of the packed dimensions is the packed struct
	// itself.
      if (!ua_of_packed)
	    ivl_assert(*this, name_base.index.size()+1 == reg->packed_dimensions());

	// Generate an expression that takes the input array of
	// expressions and generates a canonical offset into the
	// packed array.
      NetExpr*packed_base = 0;
      if (!ua_of_packed && reg->packed_dimensions() > 1) {
	    list<index_component_t>tmp_index = name_base.index;
	    index_component_t member_select;
	    member_select.sel = index_component_t::SEL_BIT;
	    member_select.msb = new PENumber(new verinum(off));
	    tmp_index.push_back(member_select);
	    packed_base = collapse_array_indices(des, scope, reg, tmp_index);
      }

      long tmp;
      if (packed_base && eval_as_long(tmp, packed_base)) {
	    off = tmp;
	    delete packed_base;
	    packed_base = 0;
      }

      if ((reg->type()==NetNet::UNRESOLVED_WIRE) && !is_force) {
	    ivl_assert(*this, reg->coerced_to_uwire());
	    report_mixed_assignment_conflict_("variable");
	    des->errors += 1;
	    return false;
      }

      if (packed_base == 0) {
	    NetExpr *base = new NetEConst(verinum(off));
	    if (member_type)
		  lv->set_part(base, member_type);
	    else
		  lv->set_part(base, use_width);
	    return true;
      }

	// Oops, packed_base is not fully evaluated, so I don't know
	// yet what to do with it.
      cerr << get_fileline() << ": internal error: "
	   << "I don't know how to handle this index expression? " << *packed_base << endl;
      ivl_assert(*this, 0);
      return false;
}

NetAssign_* PENumber::elaborate_lval(Design*des, NetScope*, bool, bool, bool) const
{
      cerr << get_fileline() << ": error: Constant values not allowed "
	   << "in l-value expressions." << endl;
      des->errors += 1;
      return 0;
}

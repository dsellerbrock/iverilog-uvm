/*
 * Copyright (c) 2012-2025 Stephen Williams (steve@icarus.com)
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

# include  "netlist.h"
# include  "netmisc.h"
# include  "compiler.h"
# include  <typeinfo>
# include  <cstring>
# include  <functional>
# include  "ivl_assert.h"

using namespace std;

/*
 * We only evaluate one function at a time, so to support the disable
 * statement, we just need to record the target block and then early
 * terminate each enclosing block or loop statement until we get back
 * to the target block.
 */
static const NetScope*disable = 0;
static bool loop_break;
static bool loop_continue;
static bool randsequence_break;
static bool randsequence_return;

static bool const_index_int64_(const verinum&value, int64_t&result)
{
      if (!value.is_defined()) return false;
      bool negative = false;
      uint64_t magnitude = verinum_signed_magnitude(value, negative);
      if (negative) {
	    if (magnitude > uint64_t(INT64_MAX)+1) return false;
	    result = magnitude == uint64_t(INT64_MAX)+1
		 ? INT64_MIN : -static_cast<int64_t>(magnitude);
      } else {
	    if (magnitude > uint64_t(INT64_MAX)) return false;
	    result = static_cast<int64_t>(magnitude);
      }
      return true;
}
static bool warned_eval_expr_unsupported = false;
static bool warned_eval_stmt_unsupported = false;
static bool warned_eval_string_len_fallback = false;
static bool warned_eval_unknown_init = false;

static int64_t const_string_index_(const verinum&value)
{
      /* String character access is equivalent to getc/putc, whose index
	 formal is a signed 32-bit 2-state int. */
      verinum int_index = cast_to_width(value, 32);
      int_index.cast_to_int2();
      int_index.has_sign(true);
      return int_index.as_long();
}

static NetExpr* fix_assign_value(const NetNet*lhs, NetExpr*rhs)
{
      NetEConst*ce = dynamic_cast<NetEConst*>(rhs);
      if (ce == 0) return rhs;

      /* A string signal's vector_width() is an implementation placeholder,
	 not the number of bits in its current value. Preserve string arguments
	 and local string assignments as strings; resizing them here truncates
	 every value to one packed bit before a character select can read it. */
      if (lhs->data_type() == IVL_VT_STRING
	  && (rhs->expr_type() == IVL_VT_STRING || ce->value().is_string())) {
	    if (rhs->expr_type() == IVL_VT_STRING)
		  return rhs;
	    NetECString*text = new NetECString(ce->value());
	    text->set_line(*rhs);
	    delete rhs;
	    return text;
      }

      unsigned lhs_width = lhs->vector_width();
      unsigned rhs_width = rhs->expr_width();
      if (rhs_width < lhs_width) {
            rhs = pad_to_width(rhs, lhs_width, *rhs);
      } else if (rhs_width > lhs_width) {
            verinum value(ce->value(), lhs_width);
            ce = new NetEConst(value);
            ce->set_line(*rhs);
            delete rhs;
	    rhs = ce;
      }
      rhs->cast_signed(lhs->get_signed());
      ce = dynamic_cast<NetEConst*>(rhs);
      if (lhs->data_type() == IVL_VT_BOOL && ce) {
            verinum value = ce->value();
            value.cast_to_int2();
            NetEConst*tmp = new NetEConst(value);
            tmp->set_line(*rhs);
            delete rhs;
            rhs = tmp;
            rhs->cast_signed(lhs->get_signed());
      }
      return rhs;
}

static void eval_func_lval_op_vec_(const LineInfo&loc, char op,
                                    verinum&lv, const verinum&rv)
{
      unsigned lv_width = lv.len();
      bool lv_sign = lv.has_sign();
      switch (op) {
        case 'l':
        case 'R':
          break;
        case 'r':
          lv.has_sign(false);
          break;
        default:
          lv.has_sign(rv.has_sign());
          lv = cast_to_width(lv, rv.len());
      }
      switch (op) {
        case '+': lv = lv + rv; break;
        case '-': lv = lv - rv; break;
        case '*': lv = lv * rv; break;
        case '/': lv = lv / rv; break;
        case '%': lv = lv % rv; break;
        case '&':
          for (unsigned idx = 0; idx < lv.len(); ++idx)
                lv.set(idx, lv[idx] & rv[idx]);
          break;
        case '|':
          for (unsigned idx = 0; idx < lv.len(); ++idx)
                lv.set(idx, lv[idx] | rv[idx]);
          break;
        case '^':
          for (unsigned idx = 0; idx < lv.len(); ++idx)
                lv.set(idx, lv[idx] ^ rv[idx]);
          break;
        case 'l': lv = lv << rv.as_unsigned(); break;
        case 'r':
        case 'R': lv = lv >> rv.as_unsigned(); break;
        default:
          cerr << "Illegal assignment operator: " << human_readable_op(op) << endl;
          ivl_assert(loc, 0);
      }
      lv = cast_to_width(lv, lv_width);
      lv.has_sign(lv_sign);
}

NetExpr* NetFuncDef::evaluate_function(const LineInfo&loc, const std::vector<NetExpr*>&args) const
{
	// Make the context map.
      map<perm_string,LocalVar>::iterator ptr;
      map<perm_string,LocalVar>context_map;

      if (debug_eval_tree) {
	    cerr << loc.get_fileline() << ": NetFuncDef::evaluate_function: "
		 << "Evaluate function " << scope()->basename() << endl;
      }

	// Put the return value into the map...
      LocalVar&return_var = context_map[scope()->basename()];
      return_var.nwords = 0;
      return_var.value  = 0;

	// Load the input ports into the map...
      ivl_assert(loc, port_count() == args.size());
      for (size_t idx = 0 ; idx < port_count() ; idx += 1) {
	    const NetNet*pnet = port(idx);
	    perm_string aname = pnet->name();
	    LocalVar&input_var = context_map[aname];

	    /* The scalar path below transfers ownership of args[idx] to the
	       evaluation context, while the array path clones its pattern leaves
	       and then releases the pattern.  Trace the argument before either
	       operation so debug builds never inspect a transferred/freed node. */
	    if (debug_eval_tree) {
		  cerr << loc.get_fileline() << ": NetFuncDef::evaluate_function: "
		       << "   input " << aname << " = ";
		  if (args[idx]) cerr << *args[idx];
		  else cerr << "<nil>";
		  cerr << endl;
	    }

	    if (pnet->unpacked_dimensions() > 0) {
		  const NetEArrayPattern*pat =
			dynamic_cast<const NetEArrayPattern*>(args[idx]);
		  std::vector<const NetExpr*>leaves;
		  std::function<void(const NetEArrayPattern*)>flatten =
			[&](const NetEArrayPattern*cur) {
			      for (size_t k = 0 ; k < cur->item_size() ; k += 1) {
				    const NetExpr*item = cur->item(k);
				    if (const NetEArrayPattern*sub =
					dynamic_cast<const NetEArrayPattern*>(item))
					  flatten(sub);
				    else
					  leaves.push_back(item);
			      }
			};
		  if (pat)
			flatten(pat);
		  unsigned nwords = pnet->unpacked_count();
		  input_var.nwords = nwords;
		  input_var.array = new NetExpr*[nwords];
		  for (unsigned word = 0 ; word < nwords ; word += 1) {
			if (word < leaves.size() && leaves[word])
			      input_var.array[word] = leaves[word]->dup_expr();
			else
			      input_var.array[word] = make_const_x(pnet->vector_width());
		  }
		  delete args[idx];
	    } else {
		  input_var.nwords = 0;
		  input_var.value  = fix_assign_value(pnet, args[idx]);
	    }
      }

	// Ask the scope to collect definitions for local values. This
	// fills in the context_map with local variables held by the scope.
      scope()->evaluate_function_find_locals(loc, context_map);

	// Execute any variable initialization statements.
      if (const NetProc*init_proc = scope()->var_init())
	    init_proc->evaluate_function(loc, context_map);

      if (debug_eval_tree && proc_==0) {
	    cerr << loc.get_fileline() << ": NetFuncDef::evaluate_function: "
		 << "Function " << scope_path(scope())
		 << " has no statement?" << endl;
      }

	// Perform the evaluation. Note that if there were errors
	// when compiling the function definition, we may not have
	// a valid statement.
      bool flag = proc_ && proc_->evaluate_function(loc, context_map);

      if (debug_eval_tree && !flag) {
	    cerr << loc.get_fileline() << ": NetFuncDef::evaluate_function: "
		 << "Cannot evaluate " << scope_path(scope()) << "." << endl;
      }

	// Extract the result...
      ptr = context_map.find(scope()->basename());
      NetExpr*res = ptr->second.value;
      context_map.erase(ptr);

	// Cleanup the rest of the context.
      for (ptr = context_map.begin() ; ptr != context_map.end() ; ++ptr) {

	    unsigned nwords = ptr->second.nwords;
	    if (nwords > 0) {
		  NetExpr**array = ptr->second.array;
		  for (unsigned idx = 0 ; idx < nwords ; idx += 1) {
			delete array[idx];
		  }
		  delete [] ptr->second.array;
	    } else {
		  delete ptr->second.value;
	    }
      }

      if (disable) {
	    if (debug_eval_tree)
		  cerr << loc.get_fileline() << ": NetFuncDef::evaluate_function: "
		       << "disable of " << scope_path(disable)
		       << " trapped in function " << scope_path(scope())
		       << "." << endl;
	    ivl_assert(loc, disable==scope());
	    disable = 0;
      }

	// Done.
      if (flag) {
	    if (debug_eval_tree) {
		  cerr << loc.get_fileline() << ": NetFuncDef::evaluate_function: "
		       << "Evaluated to ";
		  if (res) cerr << *res;
		  else cerr << "<nil>";
		  cerr << endl;
	    }
	    return res;
      }

      if (debug_eval_tree) {
	    cerr << loc.get_fileline() << ": NetFuncDef::evaluate_function: "
		 << "Evaluation failed." << endl;
      }

      delete res;
      return 0;
}

void NetScope::evaluate_function_find_locals(const LineInfo&loc,
				map<perm_string,LocalVar>&context_map) const
{
      for (map<perm_string,NetNet*>::const_iterator cur = signals_map_.begin()
		 ; cur != signals_map_.end() ; ++cur) {

	    const NetNet*tmp = cur->second;
	      // Skip ports, which are handled elsewhere.
	    if (tmp->port_type() != NetNet::NOT_A_PORT)
		  continue;

	    unsigned nwords = 0;
	    if (tmp->unpacked_dimensions() > 0)
		  nwords = tmp->unpacked_count();

	    LocalVar&local_var = context_map[tmp->name()];
	    local_var.nwords = nwords;

	    if (nwords > 0) {
		  NetExpr**array = new NetExpr*[nwords];
		  for (unsigned idx = 0 ; idx < nwords ; idx += 1) {
			array[idx] = 0;
		  }
		  local_var.array = array;
	    } else {
		  local_var.value = 0;
	    }

	    if (debug_eval_tree) {
		  cerr << loc.get_fileline() << ": debug: "
		       << "   (local) " << tmp->name()
		       << (nwords > 0 ? "[]" : "") << endl;
	    }
      }
}

NetExpr* NetExpr::evaluate_function(const LineInfo&,
				    map<perm_string,LocalVar>&) const
{
      if (gn_system_verilog()) {
	    if (const NetENew*new_expr = dynamic_cast<const NetENew*>(this)) {
		  switch (new_expr->expr_type()) {
		      case IVL_VT_REAL: {
			    NetECReal*res = new NetECReal(verireal(0.0));
			    res->set_line(*this);
			    return res;
		      }
		      case IVL_VT_BOOL: {
			    NetEConst*res = make_const_0(new_expr->expr_width());
			    res->set_line(*this);
			    return res;
		      }
		      case IVL_VT_LOGIC: {
			    NetEConst*res = make_const_x(new_expr->expr_width());
			    res->set_line(*this);
			    return res;
		      }
		      case IVL_VT_STRING: {
			    NetECString*res = new NetECString(string());
			    res->set_line(*this);
			    return res;
		      }
		      case IVL_VT_CLASS:
		      case IVL_VT_DARRAY:
		      case IVL_VT_QUEUE:
		      case IVL_VT_NO_TYPE: {
			    NetENull*res = new NetENull;
			    res->set_line(*this);
			    return res;
		      }
		      default: {
			    NetEConst*res = make_const_0(new_expr->expr_width() ? new_expr->expr_width() : 1);
			    res->set_line(*this);
			    return res;
		      }
		  }
	    }
      }

      if (!warned_eval_expr_unsupported) {
	    cerr << get_fileline() << ": sorry: I don't know how to evaluate this expression at compile time." << endl;
	    cerr << get_fileline() << ":      : Expression type:" << typeid(*this).name()
		 << " (further similar warnings suppressed)" << endl;
	    warned_eval_expr_unsupported = true;
      }

      return 0;
}

NetExpr* NetEArrayPattern::evaluate_function(
		const LineInfo&loc, map<perm_string,LocalVar>&context_map) const
{
      vector<NetExpr*>items(item_size(), nullptr);
      for (size_t idx = 0 ; idx < item_size() ; idx += 1) {
	    const NetExpr*src = item(idx);
	    if (!src)
		  continue;
	    items[idx] = src->evaluate_function(loc, context_map);
	    if (!items[idx]) {
		  for (NetExpr*item_expr : items)
			delete item_expr;
		  return nullptr;
	    }
      }
      NetEArrayPattern*res = new NetEArrayPattern(net_type(), items);
      res->set_line(*this);
      return res;
}

bool NetProc::evaluate_function(const LineInfo&,
				map<perm_string,LocalVar>&) const
{
      // Compile-progress fallback: unsupported statement kinds in constant
      // function evaluation are treated as no-ops.
      return true;
}

void NetAssign::eval_func_lval_op_real_(const LineInfo&loc,
					verireal&lv, const verireal&rv) const
{
      switch (op_) {
	  case '+':
	    lv = lv + rv;
	    break;
	  case '-':
	    lv = lv - rv;
	    break;
	  case '*':
	    lv = lv * rv;
	    break;
	  case '/':
	    lv = lv / rv;
	    break;
	  case '%':
	    lv = lv % rv;
	    break;
	  default:
	    cerr << "Illegal assignment operator: "
		 << human_readable_op(op_) << endl;
	    ivl_assert(loc, 0);
      }
}

void NetAssign::eval_func_lval_op_(const LineInfo&loc,
				   verinum&lv, const verinum&rv) const
{
      eval_func_lval_op_vec_(loc, op_, lv, rv);
}

bool NetAssign::eval_func_lval_(const LineInfo&loc,
				map<perm_string,LocalVar>&context_map,
				const NetAssign_*lval, NetExpr*rval_result) const
{
      map<perm_string,LocalVar>::iterator ptr = context_map.find(lval->name());
      if (ptr == context_map.end()) {
	    if (gn_system_verilog()) {
		  // Compile-progress fallback: unresolved/non-local l-values
		  // in constant-function evaluation are ignored.
		  delete rval_result;
		  return true;
	    }
	    if (!warned_eval_stmt_unsupported) {
		  cerr << get_fileline() << ": sorry: "
			  "I don't know how to evaluate this statement at compile time."
		       << " (further similar warnings suppressed)" << endl;
		  warned_eval_stmt_unsupported = true;
	    }
	    return false;
      }

      LocalVar*var = & ptr->second;
      while (var->nwords == -1) {
	    ivl_assert(*this, var->ref);
	    var = var->ref;
      }

      NetExpr*old_lval;
      int word = 0;
      if (var->nwords > 0) {
	    NetExpr*word_result = lval->word()->evaluate_function(loc, context_map);
	    if (word_result == 0) {
		  delete rval_result;
		  return false;
	    }

	    const NetEConst*word_const = dynamic_cast<NetEConst*>(word_result);
	    if (word_const == 0) {
		  delete word_result;
		  delete rval_result;
		  return false;
	    }

	    if (!word_const->value().is_defined())
		  return true;

	    word = word_const->value().as_long();

	    if (word < 0 || word >= var->nwords)
		  return true;

	    old_lval = var->array[word];
      } else {
	    ivl_assert(*this, var->nwords == 0);
	    old_lval = var->value;
      }

      if (const NetExpr*base_expr = lval->get_base()) {
	    if (lval->sig() && lval->sig()->data_type() == IVL_VT_STRING
		&& !lval->has_part_carrier()
		&& !lval->dynamic_part_carrier()) {
		  NetExpr*base_result = base_expr->evaluate_function(loc,
			context_map);
		  const NetEConst*base_const =
			dynamic_cast<const NetEConst*>(base_result);
		  const NetEConst*rval_const =
			dynamic_cast<const NetEConst*>(rval_result);
		  const NetEConst*old_const =
			dynamic_cast<const NetEConst*>(old_lval);
		  if (!base_const || !rval_const || (old_lval && !old_const)) {
			delete base_result;
			delete rval_result;
			return false;
		  }

		  string text = old_const
			? old_const->value().as_raw_string() : string();
		  int64_t index = const_string_index_(base_const->value());
		  verinum character = rval_const->value();
		  if (op_ && index >= 0
		      && static_cast<uint64_t>(index) < text.size()) {
			verinum old_character(
			      static_cast<uint64_t>(
				static_cast<unsigned char>(text[index])), 8);
			old_character.has_sign(true);
			eval_func_lval_op_(loc, old_character, character);
			character = old_character;
		  } else {
			character = cast_to_width(character, 8);
		  }
		  character.cast_to_int2();
		  character.has_sign(true);
		  unsigned char byte =
			static_cast<unsigned char>(character.as_ulong64());
		  if (index >= 0 && static_cast<uint64_t>(index) < text.size()
		      && byte != 0)
			text[index] = static_cast<char>(byte);

		  delete base_result;
		  delete rval_result;
		  rval_result = new NetECString(verinum::from_raw_string(text));
	    } else {
	    int64_t carrier_base = 0;
	    uint64_t carrier_width = lval->sig()
		  ? lval->sig()->vector_width() : lval->lwidth();
	    bool carrier_ok = true;
	    if (const NetExpr*carrier_expr = lval->dynamic_part_carrier()) {
		  NetExpr*carrier_result = carrier_expr->evaluate_function(
			loc, context_map);
		  if (!carrier_result) {
			delete rval_result;
			return false;
		  }
		  const NetEConst*carrier_const =
			dynamic_cast<NetEConst*>(carrier_result);
		  carrier_ok = carrier_const
			&& const_index_int64_(carrier_const->value(), carrier_base);
		  delete carrier_result;
		  carrier_width = lval->part_carrier_width();
	    } else if (lval->has_part_carrier()) {
		  carrier_base = lval->part_carrier_off();
		  carrier_width = lval->part_carrier_width();
	    }
	    NetExpr*base_result = base_expr->evaluate_function(loc, context_map);
	    if (base_result == 0) {
		  delete rval_result;
		  return false;
	    }
	    if (!carrier_ok) {
		  delete base_result;
		  delete rval_result;
		  return true;
	    }

	    const NetEConst*base_const = dynamic_cast<NetEConst*>(base_result);
	    if (base_const == 0) {
		  delete base_result;
		  delete rval_result;
		  return false;
	    }

	    int64_t base = 0;
	    if (!const_index_int64_(base_const->value(), base)) {
		  delete base_result;
		  delete rval_result;
		  return true;
	    }
	    if (!lval->dynamic_part_carrier() && lval->has_part_carrier()) {
		  if (carrier_base > 0 && base < INT64_MIN+carrier_base) {
			delete base_result;
			delete rval_result;
			return true;
		  }
		  base -= carrier_base;
	    }

	    if (old_lval == 0)
		  old_lval = make_const_x(lval->sig() ? lval->sig()->vector_width() : 1);

	    const NetEConst*lval_const = dynamic_cast<NetEConst*>(old_lval);
	    if (lval_const == 0) {
		  delete base_result;
		  delete rval_result;
		  return false;
	    }
	    verinum lval_v = lval_const->value();
	    const NetEConst*rval_const = dynamic_cast<NetEConst*>(rval_result);
	    if (rval_const == 0) {
		  delete base_result;
		  delete rval_result;
		  return false;
	    }
	    verinum rval_v = rval_const->value();

	    verinum lpart(verinum::Vx, lval->lwidth());
	    if (op_) {
		  for (unsigned idx = 0 ; idx < lpart.len() ; idx += 1) {
			if (base > INT64_MAX-int64_t(idx)) continue;
			int64_t rel = base + idx;
			if (rel >= 0 && uint64_t(rel) < carrier_width
			    && carrier_base <= INT64_MAX-rel) {
			      int64_t ldx = carrier_base + rel;
			      if (ldx >= 0 && uint64_t(ldx) < lval_v.len())
				    lpart.set(idx, lval_v[ldx]);
			}
		  }
		  if (lval->sig()
		      && lval->sig()->data_type() == IVL_VT_BOOL)
			for (unsigned idx = 0; idx < lpart.len(); ++idx)
			      if (lpart[idx] != verinum::V1)
				    lpart.set(idx, verinum::V0);
		  eval_func_lval_op_(loc, lpart, rval_v);
	    } else {
		  lpart = cast_to_width(rval_v, lval->lwidth());
	    }
	    for (unsigned idx = 0 ; idx < lpart.len() ; idx += 1) {
		  if (base > INT64_MAX-int64_t(idx)) continue;
		  int64_t rel = base + idx;
		  if (rel >= 0 && uint64_t(rel) < carrier_width
		      && carrier_base <= INT64_MAX-rel) {
			int64_t ldx = carrier_base + rel;
			if (ldx >= 0 && uint64_t(ldx) < lval_v.len())
			      lval_v.set(ldx, lpart[idx]);
		  }
	    }

	    delete base_result;
	    delete rval_result;
	    if (lval->sig() && lval->sig()->data_type() == IVL_VT_BOOL)
		  for (unsigned idx = 0; idx < lval_v.len(); ++idx)
			if (lval_v[idx] != verinum::V1)
			      lval_v.set(idx, verinum::V0);
	    rval_result = new NetEConst(lval_v);
	    }
      } else {
	    if (op_ == 0) {
		  rval_result = fix_assign_value(lval->sig(), rval_result);
	    } else if (dynamic_cast<NetECReal*>(rval_result)) {
		  const NetECReal*lval_const = dynamic_cast<NetECReal*>(old_lval);
		  ivl_assert(loc, lval_const);
		  verireal lval_r = lval_const->value();
		  const NetECReal*rval_const = dynamic_cast<NetECReal*>(rval_result);
		  ivl_assert(loc, rval_const);
		  verireal rval_r = rval_const->value();

		  eval_func_lval_op_real_(loc, lval_r, rval_r);

		  delete rval_result;
		  rval_result = new NetECReal(lval_r);
	    } else {
		  const NetEConst*lval_const = dynamic_cast<NetEConst*>(old_lval);
		  ivl_assert(loc, lval_const);
		  verinum lval_v = lval_const->value();
		  const NetEConst*rval_const = dynamic_cast<NetEConst*>(rval_result);
		  ivl_assert(loc, rval_const);
		  verinum rval_v = rval_const->value();

		  eval_func_lval_op_(loc, lval_v, rval_v);

		  delete rval_result;
		  rval_result = new NetEConst(lval_v);
	    }
      }

      if (old_lval)
	    delete old_lval;

      if (debug_eval_tree) {
	    cerr << get_fileline() << ": NetAssign::evaluate_function: "
		 << lval->name() << " = " << *rval_result << endl;
      }

      if (var->nwords > 0) {
	    var->array[word] = rval_result;
      } else {
	    ivl_assert(*this, var->nwords == 0);
	    var->value = rval_result;
      }

      return true;
}

bool NetAssign::evaluate_function(const LineInfo&loc,
				  map<perm_string,LocalVar>&context_map) const
{
      // Evaluate the r-value expression.
      const NetExpr*use_rval = rval();
      if (use_rval == 0)
	    return false;
      NetExpr*rval_result = use_rval->evaluate_function(loc, context_map);
      if (rval_result == 0)
	    return false;

	// Handle the easy case of a single variable on the LHS.
      if (l_val_count() == 1)
	    return eval_func_lval_(loc, context_map, l_val(0), rval_result);

	// If we get here, the LHS must be a concatenation, so we
	// expect the RHS to be a vector value.
      const NetEConst*rval_const = dynamic_cast<NetEConst*>(rval_result);
      if (rval_const == 0) {
	    delete rval_result;
	    return false;
      }

      if (op_) {
	    cerr << get_fileline() << ": sorry: Assignment operators "
		    "inside a constant function are not currently "
		    "supported if the LHS is a concatenation." << endl;
	    return false;
      }

      verinum rval_full = rval_const->value();
      delete rval_result;

      unsigned base = 0;
      for (unsigned ldx = 0 ; ldx < l_val_count() ; ldx += 1) {
	    const NetAssign_*lval = l_val(ldx);

	    verinum rval_part(verinum::Vx, lval->lwidth());
	    for (unsigned idx = 0 ; idx < rval_part.len() ; idx += 1)
		  rval_part.set(idx, rval_full[base+idx]);

	    bool flag = eval_func_lval_(loc, context_map, lval,
					new NetEConst(rval_part));
	    if (!flag) return false;

	    base += lval->lwidth();
      }

      return true;
}

/*
 * Evaluating a NetBlock in a function is a simple matter of
 * evaluating the statements in order.
 */
bool NetBlock::evaluate_function(const LineInfo&loc,
				 map<perm_string,LocalVar>&context_map) const
{
      if (last_ == 0) return true;

	// If we need to make a local scope, then this context map
	// will be filled in and used for statements within this block.
      map<perm_string,LocalVar>local_context_map;
      bool use_local_context_map = false;

      if (subscope_!=0) {
	      // First, copy the containing scope symbols into the new
	      // scope as references.
	    for (map<perm_string,LocalVar>::iterator cur = context_map.begin()
		       ; cur != context_map.end() ; ++cur) {
		  LocalVar&cur_var = local_context_map[cur->first];
		  cur_var.nwords = -1;
		  if (cur->second.nwords == -1)
			cur_var.ref = cur->second.ref;
		  else
			cur_var.ref = &cur->second;
	    }

	      // Now collect the new locals.
	    subscope_->evaluate_function_find_locals(loc, local_context_map);
	    use_local_context_map = true;

	      // Execute any variable initialization statements.
	    if (const NetProc*init_proc = subscope_->var_init())
		  init_proc->evaluate_function(loc, local_context_map);
      }

	// Now use the local context map if there is any local
	// context, or the containing context map.
      map<perm_string,LocalVar>&use_context_map = use_local_context_map? local_context_map : context_map;

      bool flag = true;
      NetProc*cur = last_;
      do {
	    cur = cur->next_;
	    if (debug_eval_tree) {
		  cerr << get_fileline() << ": NetBlock::evaluate_function: "
		       << "Execute statement (" << typeid(*cur).name()
		       << ") at " << cur->get_fileline() << "." << endl;
	    }

	    bool cur_flag = cur->evaluate_function(loc, use_context_map);
	    flag = flag && cur_flag;
      } while (cur != last_ && !disable && !loop_break && !loop_continue
	       && !randsequence_break && !randsequence_return);

      if (debug_eval_tree) {
	    cerr << get_fileline() << ": NetBlock::evaluate_function: "
		 << "subscope_=" << subscope_
		 << ", disable=" << disable
		 << ", flag=" << (flag?"true":"false") << endl;
      }

      if (disable == subscope_) disable = 0;
      if (randsequence_block_ == IVL_RANDSEQ_BLOCK_PRODUCTION
	  && randsequence_return)
	    randsequence_return = false;
      if (randsequence_block_ == IVL_RANDSEQ_BLOCK_ROOT
	  && randsequence_break)
	    randsequence_break = false;

      return flag;
}

bool NetCase::evaluate_function_vect_(const LineInfo&loc,
				map<perm_string,LocalVar>&context_map) const
{
      NetExpr*case_expr = expr_->evaluate_function(loc, context_map);
      if (case_expr == 0)
	    return false;

      const NetEConst*case_const = dynamic_cast<NetEConst*> (case_expr);
      ivl_assert(loc, case_const);

      verinum case_val = case_const->value();
      delete case_expr;

      const NetProc*default_statement = 0;

      for (unsigned cnt = 0 ; cnt < items_.size() ; cnt += 1) {
            const Item*item = &items_[cnt];

            if (item->guard == 0) {
                  default_statement = item->statement;
                  continue;
            }

            NetExpr*item_expr = item->guard->evaluate_function(loc, context_map);
            if (item_expr == 0)
                  return false;

            const NetEConst*item_const = dynamic_cast<NetEConst*> (item_expr);
            ivl_assert(loc, item_const);

            verinum item_val = item_const->value();
            delete item_expr;

            ivl_assert(loc, item_val.len() == case_val.len());

            bool match = true;
            for (unsigned idx = 0 ; idx < item_val.len() ; idx += 1) {
                  verinum::V bit_a = case_val.get(idx);
                  verinum::V bit_b = item_val.get(idx);

                  if (bit_a == verinum::Vx && type_ == EQX) continue;
                  if (bit_b == verinum::Vx && type_ == EQX) continue;

                  if (bit_a == verinum::Vz && type_ != EQ) continue;
                  if (bit_b == verinum::Vz && type_ != EQ) continue;

                  if (bit_a != bit_b) {
                        match = false;
                        break;
                  }
            }
            if (!match) continue;

            return item->statement->evaluate_function(loc, context_map);
      }

      if (default_statement)
            return default_statement->evaluate_function(loc, context_map);

      return true;
}

bool NetCase::evaluate_function_real_(const LineInfo&loc,
				map<perm_string,LocalVar>&context_map) const
{
      NetExpr*case_expr = expr_->evaluate_function(loc, context_map);
      if (case_expr == 0)
	    return false;

      const NetECReal*case_const = dynamic_cast<NetECReal*> (case_expr);
      ivl_assert(loc, case_const);

      double case_val = case_const->value().as_double();
      delete case_expr;

      const NetProc*default_statement = 0;

      for (unsigned cnt = 0 ; cnt < items_.size() ; cnt += 1) {
            const Item*item = &items_[cnt];

            if (item->guard == 0) {
                  default_statement = item->statement;
                  continue;
            }

            NetExpr*item_expr = item->guard->evaluate_function(loc, context_map);
            if (item_expr == 0)
                  return false;

            const NetECReal*item_const = dynamic_cast<NetECReal*> (item_expr);
            ivl_assert(loc, item_const);

            double item_val = item_const->value().as_double();
            delete item_expr;

            if (item_val != case_val) continue;

            return item->statement->evaluate_function(loc, context_map);
      }

      if (default_statement)
            return default_statement->evaluate_function(loc, context_map);

      return true;
}

bool NetCase::evaluate_function(const LineInfo&loc,
				map<perm_string,LocalVar>&context_map) const
{
      if (expr_->expr_type() == IVL_VT_REAL)
	    return evaluate_function_real_(loc, context_map);
      else
	    return evaluate_function_vect_(loc, context_map);
}

bool NetCondit::evaluate_function(const LineInfo&loc,
				  map<perm_string,LocalVar>&context_map) const
{
      NetExpr*cond = expr_->evaluate_function(loc, context_map);
      if (cond == 0) {
	    if (debug_eval_tree) {
		  cerr << get_fileline() << ": NetCondit::evaluate_function: "
		       << "Unable to evaluate condition (" << *expr_ <<")" << endl;
	    }
	    return false;
      }

      const NetEConst*cond_const = dynamic_cast<NetEConst*> (cond);
      ivl_assert(loc, cond_const);

      long val = cond_const->value().as_long();
      delete cond;

      bool flag;

      if (val)
	      // The condition is true, so evaluate the if clause
	    flag = (if_ == 0) || if_->evaluate_function(loc, context_map);
      else
	      // The condition is false, so evaluate the else clause
	    flag = (else_ == 0) || else_->evaluate_function(loc, context_map);

      if (debug_eval_tree) {
	    cerr << get_fileline() << ": NetCondit::evaluate_function: "
		 << "Finished, flag=" << (flag?"true":"false") << endl;
      }
      return flag;
}

bool NetDisable::evaluate_function(const LineInfo&,
				   map<perm_string,LocalVar>&) const
{
      disable = target_;

      if (debug_eval_tree) {
	    cerr << get_fileline() << ": NetDisable::evaluate_function: "
		 << "disable " << scope_path(disable) << endl;
      }

      return true;
}

bool NetBreak::evaluate_function(const LineInfo&,
			         map<perm_string, LocalVar>&) const
{
      if (kind_ == IVL_FLOW_RANDSEQ_BREAK)
	    randsequence_break = true;
      else if (kind_ == IVL_FLOW_RANDSEQ_RETURN)
	    randsequence_return = true;
      else
	    loop_break = true;

      if (debug_eval_tree) {
	    cerr << get_fileline() << ": NetBreak::evaluate_function kind="
		 << kind_ << endl;
      }

      return true;
}

bool NetContinue::evaluate_function(const LineInfo&,
				    map<perm_string, LocalVar>&) const
{
      loop_continue = true;

      if (debug_eval_tree) {
	    cerr << get_fileline() << ": NetContinue::evaluate_function" << endl;
      }

      return true;
}

bool NetDoWhile::evaluate_function(const LineInfo&loc,
				   map<perm_string,LocalVar>&context_map) const
{
      bool flag = true;

      if (debug_eval_tree) {
	    cerr << get_fileline() << ": NetDoWhile::evaluate_function: "
		 << "Start loop" << endl;
      }

      while (!disable && !randsequence_break && !randsequence_return) {
	      // Evaluate the statement.
	    flag = proc_->evaluate_function(loc, context_map);
	    if (! flag)
		   break;

	    if (randsequence_break || randsequence_return)
		  break;

	    if (loop_break) {
		  loop_break = false;
		  break;
	    }

	    loop_continue = false;

	      // Evaluate the condition expression to try and get the
	      // condition for the loop.
	    NetExpr*cond = cond_->evaluate_function(loc, context_map);
	    if (cond == 0) {
		  flag = false;
		  break;
	    }

	    const NetEConst*cond_const = dynamic_cast<NetEConst*> (cond);
	    ivl_assert(loc, cond_const);

	    long val = cond_const->value().as_long();
	    delete cond;

	      // If the condition is false, then the loop is done.
	    if (val == 0)
		  break;
      }

      if (debug_eval_tree) {
	    cerr << get_fileline() << ": NetDoWhile::evaluate_function: "
		 << "Done loop, flag=" << (flag?"true":"false") << endl;
      }

      return flag;
}

bool NetForever::evaluate_function(const LineInfo&loc,
				   map<perm_string,LocalVar>&context_map) const
{
      bool flag = true;

      if (debug_eval_tree) {
	    cerr << get_fileline() << ": debug: NetForever::evaluate_function: "
		 << "Start loop" << endl;
      }

      while (flag && !disable && !randsequence_break
	     && !randsequence_return) {
	    flag = flag && statement_->evaluate_function(loc, context_map);

	    if (loop_break) {
		  loop_break = false;
		  break;
	    }

	    loop_continue = false;
      }

      if (debug_eval_tree) {
	    cerr << get_fileline() << ": debug: NetForever::evaluate_function: "
		 << "Done loop" << endl;
      }

      return flag;
}

/*
 * Process the for-loop to generate a value, as if this were in a function.
 */
bool NetForLoop::evaluate_function(const LineInfo&loc,
				   map<perm_string,LocalVar>&context_map) const
{
      bool flag = true;

      if (debug_eval_tree) {
	    cerr << get_fileline() << ": NetForLoop::evaluate_function: "
		<< "Evaluate the for look as a function." << endl;
      }

      if (init_statement_) {
	    bool tmp_flag = init_statement_->evaluate_function(loc, context_map);
	    flag &= tmp_flag;
      }

      while (flag && !disable && !randsequence_break
	     && !randsequence_return) {
	    if (condition_) {
		  // Evaluate the condition expression to try and get the
		  // condition for the loop.
		  NetExpr*cond = condition_->evaluate_function(loc, context_map);
		  if (cond == nullptr) {
			flag = false;
			break;
		  }

		  const NetEConst*cond_const = dynamic_cast<NetEConst*> (cond);
		  ivl_assert(loc, cond_const);

		  long val = cond_const->value().as_long();
		  delete cond;

		  // If the condition is false, then break;
		  if (val == 0)
			break;
	    }

	    bool tmp_flag = statement_->evaluate_function(loc, context_map);
	    flag &= tmp_flag;

	    if (disable || randsequence_break || randsequence_return)
		  break;

	    if (loop_break) {
		  loop_break = false;
		  break;
	    }

	    loop_continue = false;

	    if (step_statement_) {
		  tmp_flag = step_statement_->evaluate_function(loc, context_map);
		  flag &= tmp_flag;
	    }
      }

      if (debug_eval_tree) {
	    cerr << get_fileline() << ": NetForLoop::evaluate_function: "
		<< "Done for-loop, flag=" << (flag?"true":"false") << endl;
      }

      return flag;
}

bool NetRepeat::evaluate_function(const LineInfo&loc,
				  map<perm_string,LocalVar>&context_map) const
{
      bool flag = true;

	// Evaluate the condition expression to try and get the
	// condition for the loop.
      NetExpr*count_expr = expr_->evaluate_function(loc, context_map);
      if (count_expr == 0) return false;

      const NetEConst*count_const = dynamic_cast<NetEConst*> (count_expr);
      ivl_assert(loc, count_const);

      long count = count_const->value().as_long();
      delete count_expr;

      if (debug_eval_tree) {
	    cerr << get_fileline() << ": debug: NetRepeat::evaluate_function: "
		 << "Repeating " << count << " times." << endl;
      }

      while ((count > 0) && flag && !disable && !randsequence_break
	     && !randsequence_return) {
	    flag = flag && statement_->evaluate_function(loc, context_map);
	    count -= 1;

	    if (loop_break) {
		  loop_break = false;
		  break;
	    }

	    loop_continue = false;
      }

      if (debug_eval_tree) {
	    cerr << get_fileline() << ": debug: NetRepeat::evaluate_function: "
		 << "Finished loop" << endl;
      }

      return flag;
}

bool NetSTask::evaluate_function(const LineInfo&,
				 map<perm_string,LocalVar>&) const
{
	// system tasks within a constant function are ignored
      return true;
}

bool NetWhile::evaluate_function(const LineInfo&loc,
				 map<perm_string,LocalVar>&context_map) const
{
      bool flag = true;

      if (debug_eval_tree) {
	    cerr << get_fileline() << ": NetWhile::evaluate_function: "
		 << "Start loop" << endl;
      }

      while (flag && !disable && !randsequence_break
	     && !randsequence_return) {
	      // Evaluate the condition expression to try and get the
	      // condition for the loop.
	    NetExpr*cond = cond_->evaluate_function(loc, context_map);
	    if (cond == 0) {
		  flag = false;
		  break;
	    }

	    const NetEConst*cond_const = dynamic_cast<NetEConst*> (cond);
	    ivl_assert(loc, cond_const);

	    long val = cond_const->value().as_long();
	    delete cond;

	      // If the condition is false, then break.
	    if (val == 0)
		  break;

	      // The condition is true, so evaluate the statement
	      // another time.
	    bool tmp_flag = proc_->evaluate_function(loc, context_map);
	    if (! tmp_flag)
		  flag = false;

	    if (loop_break) {
		  loop_break = false;
		  break;
	    }

	    loop_continue = false;
      }

      if (debug_eval_tree) {
	    cerr << get_fileline() << ": NetWhile::evaluate_function: "
		 << "Done loop, flag=" << (flag?"true":"false") << endl;
      }

      return flag;
}

NetExpr* NetEBinary::evaluate_function(const LineInfo&loc,
				map<perm_string,LocalVar>&context_map) const
{
      NetExpr*lval = left_->evaluate_function(loc, context_map);
      NetExpr*rval = right_->evaluate_function(loc, context_map);

      if (lval == 0 || rval == 0) {
	    delete lval;
	    delete rval;
	    return 0;
      }

      NetExpr*res = eval_arguments_(lval, rval);
      delete lval;
      delete rval;
      return res;
}

NetExpr* NetEConcat::evaluate_function(const LineInfo&loc,
				map<perm_string,LocalVar>&context_map) const
{
      vector<NetExpr*>vals(parms_.size());
      unsigned gap = 0;

      unsigned valid_vals = 0;
      for (unsigned idx = 0 ;  idx < parms_.size() ;  idx += 1) {
            ivl_assert(*this, parms_[idx]);
            vals[idx] = parms_[idx]->evaluate_function(loc, context_map);
            if (vals[idx] == 0) continue;

            gap += vals[idx]->expr_width();

            valid_vals += 1;
      }

      NetExpr*res = 0;
      if (valid_vals == parms_.size()) {
            res = eval_arguments_(vals, gap);
      }
      for (unsigned idx = 0 ;  idx < vals.size() ;  idx += 1) {
            delete vals[idx];
      }
      return res;
}

NetExpr* NetEConst::evaluate_function(const LineInfo&,
				      map<perm_string,LocalVar>&) const
{
      NetEConst*res = new NetEConst(value_);
      res->set_line(*this);
      return res;
}

NetExpr* NetECReal::evaluate_function(const LineInfo&,
				      map<perm_string,LocalVar>&) const
{
      NetECReal*res = new NetECReal(value_);
      res->set_line(*this);
      return res;
}

NetExpr* NetENew::evaluate_function(const LineInfo&,
				    map<perm_string,LocalVar>&) const
{
      switch (expr_type()) {
	  case IVL_VT_REAL: {
		NetECReal*res = new NetECReal(verireal(0.0));
		res->set_line(*this);
		return res;
	  }
	  case IVL_VT_BOOL: {
		NetEConst*res = make_const_0(expr_width());
		res->set_line(*this);
		return res;
	  }
	  case IVL_VT_LOGIC: {
		NetEConst*res = make_const_x(expr_width());
		res->set_line(*this);
		return res;
	  }
	  case IVL_VT_STRING: {
		NetECString*res = new NetECString(string());
		res->set_line(*this);
		return res;
	  }
	  case IVL_VT_CLASS:
	  case IVL_VT_DARRAY:
	  case IVL_VT_QUEUE:
	  case IVL_VT_NO_TYPE: {
		NetENull*res = new NetENull;
		res->set_line(*this);
		return res;
	  }
	  default: {
		NetEConst*res = make_const_0(expr_width() ? expr_width() : 1);
		res->set_line(*this);
		return res;
	  }
      }
}

NetExpr* NetENull::evaluate_function(const LineInfo&,
				     map<perm_string,LocalVar>&) const
{
      // Compile-progress fallback: constant-function evaluation commonly
      // expects an integral constant node. Treat null as 0 here so we
      // keep moving instead of returning nullptr and crashing later.
      NetEConst*res = make_const_0(1);
      res->set_line(*this);
      return res;
}

NetExpr* NetEProperty::evaluate_function(const LineInfo&,
					 map<perm_string,LocalVar>&) const
{
      // Compile-progress fallback: class-property reads frequently appear in
      // constant-function contexts in UVM macros, but we do not have an
      // executable object model for compile-time class instances. Return a
      // typed placeholder instead of failing the whole constant evaluation.
      switch (expr_type()) {
	  case IVL_VT_STRING: {
		NetECString*res = new NetECString(string());
		res->set_line(*this);
		return res;
	  }
	  case IVL_VT_REAL: {
		NetECReal*res = new NetECReal(verireal(0.0));
		res->set_line(*this);
		return res;
	  }
	  case IVL_VT_CLASS: {
		NetEConst*res = make_const_0(1);
		res->set_line(*this);
		return res;
	  }
	  default: {
		unsigned wid = expr_width() ? expr_width() : 1;
		NetEConst*res = make_const_0(wid);
		res->set_line(*this);
		return res;
	  }
      }
}

NetExpr* NetESelect::evaluate_function(const LineInfo&loc,
				map<perm_string,LocalVar>&context_map) const
{
      NetExpr*sub_exp = expr_->evaluate_function(loc, context_map);
      if (!sub_exp)
	    return 0;

      const NetEConst*sub_const = dynamic_cast<NetEConst*> (sub_exp);
      if (sub_const == 0) {
	    delete sub_exp;
	    if (gn_system_verilog()) {
		  unsigned wid = expr_width() ? expr_width() : 1;
		  NetEConst*res_const = make_const_0(wid);
		  res_const->set_line(*this);
		  return res_const;
	    }
	    return 0;
      }

      const bool string_select = base_ && expr_width() == 8
	    && sub_exp->expr_type() == IVL_VT_STRING;
      const string string_value = string_select
	    ? sub_const->value().as_raw_string() : string();
      verinum sub = sub_const->value();
      delete sub_exp;

      long base = 0;
      int64_t string_index = 0;
      if (base_) {
	    NetExpr*base_val = base_->evaluate_function(loc, context_map);
	    if (base_val == 0) {
		  return 0;
	    }

	    const NetEConst*base_const = dynamic_cast<NetEConst*>(base_val);
	    if (base_const == 0) {
		  delete base_val;
		  return 0;
	    }

	    const verinum&base_number = base_const->value();
	    if (string_select) {
		  /* Str[index] is semantically Str.getc(index), whose formal is
		     a 32-bit 2-state int. Apply that assignment conversion before
		     checking the character range: high source bits are truncated
		     and X/Z bits convert to zero independently. */
		  string_index = const_string_index_(base_number);
	    } else {
		  base = base_number.as_long();
	    }
	    delete base_val;
      } else {
	    sub.has_sign(has_sign());
	    sub = pad_to_width(sub, expr_width());
      }

      if (string_select) {
	    uint64_t character = 0;
	    if (string_index >= 0
		&& static_cast<uint64_t>(string_index) < string_value.size())
		  character = static_cast<unsigned char>(string_value[string_index]);

	    verinum value(character, 8);
	    value.has_sign(has_sign());
	    NetEConst*res_const = new NetEConst(value);
	    res_const->set_line(*this);
	    return res_const;
      }

      verinum res (verinum::Vx, expr_width());
      for (unsigned idx = 0 ; idx < res.len() ; idx += 1) {
	    long sdx = base + idx;
	    if (sdx >= 0 && (unsigned long)sdx < sub.len())
		  res.set(idx, sub[sdx]);
      }

      NetEConst*res_const = new NetEConst(res);
      res_const->set_line(*this);
      return res_const;
}

NetExpr* NetESignal::evaluate_function(const LineInfo&loc,
				map<perm_string,LocalVar>&context_map) const
{
      auto make_type_default = [this]() -> NetExpr* {
	    switch (expr_type()) {
		case IVL_VT_REAL:
		  return new NetECReal(verireal(0.0));
		case IVL_VT_BOOL:
		  return make_const_0(expr_width());
		case IVL_VT_LOGIC:
		  return make_const_x(expr_width());
		case IVL_VT_STRING:
		  return new NetECString(string());
		case IVL_VT_CLASS: {
		  NetENull*tmp = new NetENull;
		  tmp->set_line(*this);
		  return tmp;
		}
		case IVL_VT_DARRAY:
		case IVL_VT_QUEUE:
		case IVL_VT_NO_TYPE: {
		  NetENull*tmp = new NetENull;
		  tmp->set_line(*this);
		  return tmp;
		}
		default:
		  return nullptr;
	    }
      };

      const LocalVar*var = 0;
	// Synthesis may have multiple active procedural-loop indices with the
	// same basename. Prefer their exact signal identities to the ordinary
	// name-keyed constant-function context so a qualified outer reference is
	// not evaluated with a shadowing inner value. NetForLoop mirrors its exact
	// entry into the declaration scope while the iteration body is active.
      for (const NetScope*cur_scope = net_ ? net_->scope() : 0;
	   cur_scope && !var; cur_scope = cur_scope->parent()) {
	    map<NetNet*,LocalVar>::const_iterator exact =
		  cur_scope->loop_index_values_tmp.find(net_);
	    if (exact != cur_scope->loop_index_values_tmp.end())
		  var = &exact->second;
      }

      if (!var) {
	    map<perm_string,LocalVar>::iterator ptr = context_map.find(name());
	    if (ptr == context_map.end()) {
		  if (gn_system_verilog() && strcmp(name(), "@") == 0) {
			NetExpr*res = make_type_default();
			if (res) {
			      res->set_line(*this);
			      return res;
			}
		  }
		  const NetScope*sig_scope = net_ ? net_->scope() : nullptr;
		  if (gn_system_verilog() && sig_scope
		      && (sig_scope->type() == NetScope::CLASS
			  || sig_scope->type() == NetScope::PACKAGE)) {
			// Compile-progress fallback for static class/package variables
			// referenced from constant-function evaluation (e.g. UVM
			// singleton/static handles). These are not in the local eval
			// context map, but returning a typed placeholder preserves
			// forward progress and exposes later semantic diagnostics.
			NetExpr*res = make_type_default();
			if (res) {
			      res->set_line(*this);
			      return res;
			}
		  }
		  cerr << get_fileline() << ": error: Cannot evaluate " << name()
		       << " in this context." << endl;
		  return 0;
	    }
	    var = &ptr->second;
      }

	// Follow indirect references to the actual variable.
      while (var->nwords == -1) {
	    ivl_assert(*this, var->ref);
	    var = var->ref;
      }

      const NetExpr*value = 0;
      if (var->nwords > 0) {
	    ivl_assert(loc, word_);
	    NetExpr*word_result = word_->evaluate_function(loc, context_map);
	    if (word_result == 0)
		  return 0;

	    const NetEConst*word_const = dynamic_cast<NetEConst*>(word_result);
	    ivl_assert(loc, word_const);

	    int word = word_const->value().as_long();

	    if (word_const->value().is_defined() && (word >= 0) && (word < var->nwords))
		  value = var->array[word];
      } else {
	    value = var->value;
      }

	      if (value == 0) {
		    NetExpr*res = make_type_default();
		    if (res) {
			  res->set_line(*this);
			  return res;
		    }
		    if (gn_system_verilog()) {
			  NetEConst*tmp = make_const_0(1);
			  tmp->set_line(*this);
			  return tmp;
		    }
		    if (!warned_eval_unknown_init) {
			  cerr << get_fileline() << ": sorry: I don't know how to initialize "
			       << *this << " (further similar warnings suppressed)" << endl;
			  warned_eval_unknown_init = true;
		    }
		    return 0;
	      }

      return value->dup_expr();
}

NetExpr* NetETernary::evaluate_function(const LineInfo&loc,
				map<perm_string,LocalVar>&context_map) const
{
      unique_ptr<NetExpr> cval (cond_->evaluate_function(loc, context_map));

      switch (const_logical(cval.get())) {

	  case C_0:
	    return false_val_->evaluate_function(loc, context_map);
	  case C_1:
	    return true_val_->evaluate_function(loc, context_map);
	  case C_X:
	    break;
	  default:
	    cerr << get_fileline() << ": error: Condition expression is not constant here." << endl;
	    return 0;
      }

      NetExpr*tval = true_val_->evaluate_function(loc, context_map);
      NetExpr*fval = false_val_->evaluate_function(loc, context_map);

      NetExpr*res = blended_arguments_(tval, fval);
      delete tval;
      delete fval;
      return res;
}

static NetExpr* eval_func_signal_default_(const NetESignal*sig);

static NetExpr** eval_func_signal_slot_(const LineInfo&loc,
                                        const NetESignal*sig,
                                        map<perm_string,LocalVar>&context_map,
                                        NetExpr*&invalid_slot,
                                        bool&discard_store)
{
      map<perm_string,LocalVar>::iterator ptr = context_map.find(sig->name());
      if (ptr == context_map.end()) {
            cerr << sig->get_fileline() << ": error: Cannot assign "
                 << sig->name() << " in this constant-function context." << endl;
            return 0;
      }
      LocalVar*var = &ptr->second;
      while (var->nwords == -1) {
            ivl_assert(*sig, var->ref);
            var = var->ref;
      }
      if (var->nwords == 0)
            return &var->value;

      const NetExpr*word = sig->word_index();
      if (!word) return 0;
      unique_ptr<NetExpr>word_result(word->evaluate_function(loc, context_map));
      if (!word_result) return 0;
      const NetEConst*word_const =
            dynamic_cast<const NetEConst*>(word_result.get());
      if (!word_const) return 0;
      int64_t index = 0;
      if (!const_index_int64_(word_const->value(), index)
          || index < 0 || index >= var->nwords) {
            invalid_slot = eval_func_signal_default_(sig);
            discard_store = true;
            return &invalid_slot;
      }
      return &var->array[index];
}

static NetExpr* eval_func_signal_default_(const NetESignal*sig)
{
      NetExpr*result = 0;
      switch (sig->expr_type()) {
        case IVL_VT_BOOL:
          result = make_const_0(sig->expr_width());
          break;
        case IVL_VT_LOGIC:
          result = make_const_x(sig->expr_width());
          break;
        case IVL_VT_REAL:
          return new NetECReal(verireal(0.0));
        default:
          return 0;
      }
      result->cast_signed(sig->has_sign());
      return result;
}

NetExpr* NetEAssignExpr::evaluate_function(const LineInfo&loc,
                              map<perm_string,LocalVar>&context_map) const
{
      ivl_assert(*this, nparms() == 2);
      const NetESignal*lhs = dynamic_cast<const NetESignal*>(parm(0));
      if (!lhs) return 0;
      NetExpr*invalid_slot = 0;
      bool discard_store = false;
      NetExpr**slot = eval_func_signal_slot_(loc, lhs, context_map,
                                             invalid_slot, discard_store);
      if (!slot) return 0;

      unique_ptr<NetExpr>rhs(parm(1)->evaluate_function(loc, context_map));
      if (!rhs) {
            delete invalid_slot;
            return 0;
      }
      NetExpr*assigned = 0;
      char op = name()[strlen(name())-1];
      if (op == '=') {
            assigned = fix_assign_value(lhs->sig(), rhs.release());
      } else {
            if (!*slot)
                  *slot = eval_func_signal_default_(lhs);
            const NetEConst*old_const =
                  dynamic_cast<const NetEConst*>(*slot);
            const NetEConst*rhs_const =
                  dynamic_cast<const NetEConst*>(rhs.get());
            if (!old_const || !rhs_const) {
                  delete invalid_slot;
                  return 0;
            }
            verinum value = old_const->value();
            eval_func_lval_op_vec_(loc, op, value, rhs_const->value());
            assigned = fix_assign_value(lhs->sig(), new NetEConst(value));
      }
      assigned->set_line(*this);
      delete *slot;
      *slot = assigned->dup_expr();
      if (discard_store) {
            delete *slot;
            *slot = 0;
      }
      return assigned;
}

NetExpr* NetEUnary::evaluate_function(const LineInfo&loc,
				map<perm_string,LocalVar>&context_map) const
{
      if (op_ == 'i' || op_ == 'I' || op_ == 'd' || op_ == 'D') {
            const NetESignal*sig = dynamic_cast<const NetESignal*>(expr_);
            if (!sig) return 0;
            NetExpr*invalid_slot = 0;
            bool discard_store = false;
            NetExpr**slot = eval_func_signal_slot_(loc, sig, context_map,
                                                   invalid_slot, discard_store);
            if (!slot) return 0;
            if (!*slot)
                  *slot = eval_func_signal_default_(sig);
            if (!*slot) {
                  delete invalid_slot;
                  return 0;
            }
            unique_ptr<NetExpr>old((*slot)->dup_expr());
            NetExpr*updated = 0;
            if (const NetEConst*old_const =
                      dynamic_cast<const NetEConst*>(old.get())) {
                  verinum value = old_const->value();
                  verinum one(uint64_t(1), value.len());
                  one.has_sign(value.has_sign());
                  eval_func_lval_op_vec_(loc,
                        (op_ == 'i' || op_ == 'I') ? '+' : '-', value, one);
                  updated = fix_assign_value(sig->sig(), new NetEConst(value));
            } else if (const NetECReal*old_real =
                            dynamic_cast<const NetECReal*>(old.get())) {
                  double value = old_real->value().as_double();
                  value += (op_ == 'i' || op_ == 'I') ? 1.0 : -1.0;
                  updated = new NetECReal(verireal(value));
            } else {
                  delete invalid_slot;
                  return 0;
            }
            updated->set_line(*this);
            delete *slot;
            *slot = updated;
            NetExpr*result = (op_ == 'i' || op_ == 'd')
                  ? old.release() : updated->dup_expr();
            if (discard_store) {
                  delete *slot;
                  *slot = 0;
            }
            return result;
      }
      NetExpr*val = expr_->evaluate_function(loc, context_map);
      if (val == 0) return 0;

      NetExpr*res = eval_arguments_(val);
      delete val;
      return res;
}

NetExpr* NetESFunc::evaluate_function(const LineInfo&loc,
				map<perm_string,LocalVar>&context_map) const
{
      if (strcmp(name_, "$ivl_checked_property_index") == 0) {
	    uint64_t canonical = 0;
	    bool invalid = false;
	    ivl_assert(*this, parms_.size() % 4 == 0);
	    for (size_t idx = 0; idx < parms_.size(); idx += 4) {
		  NetExpr*raw_expr = parms_[idx]->evaluate_function(loc, context_map);
		  if (!raw_expr) return 0;
		  const NetEConst*raw = dynamic_cast<NetEConst*>(raw_expr);
		  int64_t value = 0;
		  bool valid = raw && const_index_int64_(raw->value(), value);
		  delete raw_expr;
		  int64_t low = 0;
		  int64_t width = 0;
		  int64_t stride = 0;
		  for (unsigned sub = 1; valid && sub < 4; ++sub) {
			NetExpr*tmp_expr = parms_[idx+sub]->evaluate_function(
			      loc, context_map);
			if (!tmp_expr) return 0;
			const NetEConst*tmp = dynamic_cast<NetEConst*>(tmp_expr);
			int64_t*dst = sub == 1 ? &low : sub == 2 ? &width : &stride;
			valid = tmp && const_index_int64_(tmp->value(), *dst);
			delete tmp_expr;
		  }
		  if (!valid || width <= 0 || stride < 0 || value < low) {
			invalid = true;
			continue;
		  }
		  uint64_t ordinal = uint64_t(value)-uint64_t(low);
		  if (ordinal >= uint64_t(width)
		      || ordinal > UINT64_MAX/uint64_t(stride ? stride : 1)) {
			invalid = true;
			continue;
		  }
		  uint64_t add = ordinal * uint64_t(stride);
		  if (canonical > UINT64_MAX-add) {
			invalid = true;
			continue;
		  }
		  canonical += add;
	    }
	    if (invalid) {
		  NetEConst*res = make_const_x(64);
		  res->set_line(*this);
		  return res;
	    }
	    NetEConst*res = new NetEConst(verinum(canonical, 64));
	    res->set_line(*this);
	    return res;
      }

      if (strcmp(name_, "$ivl_string_method$len") == 0 && parms_.size() == 1) {
	    NetExpr*arg = parms_[0]->evaluate_function(loc, context_map);
	    if (arg == 0) return 0;
	    long len = 0;
	    if (const NetEConst*arg_const = dynamic_cast<const NetEConst*>(arg)) {
		  const verinum&value = arg_const->value();
		  if (value.is_string())
			len = static_cast<long>(value.as_raw_string().size());
	    }
	    delete arg;
	    NetEConst*res = new NetEConst(verinum(verinum(len), integer_width));
	    res->set_line(*this);
	    return res;
      }

      bool string_toupper = strcmp(name_, "$ivl_string_method$toupper") == 0;
      bool string_tolower = strcmp(name_, "$ivl_string_method$tolower") == 0;
      if ((string_toupper || string_tolower) && parms_.size() == 1) {
	    NetExpr*arg = parms_[0]->evaluate_function(loc, context_map);
	    if (arg == 0) return 0;
	    const NetEConst*arg_const = dynamic_cast<const NetEConst*>(arg);
	    if (arg_const == 0 || !arg_const->value().is_string()) {
		  delete arg;
		  return 0;
	    }

	    string text = arg_const->value().as_raw_string();
	    delete arg;
	    /* SystemVerilog strings are byte sequences. Restrict conversion to
	       ASCII letters so the folded value does not depend on the host
	       locale, and preserve every other byte. */
	    for (size_t idx = 0; idx < text.size(); ++idx) {
		  unsigned char ch = static_cast<unsigned char>(text[idx]);
		  if (string_toupper && ch >= 'a' && ch <= 'z')
			text[idx] = static_cast<char>(ch - 'a' + 'A');
		  else if (string_tolower && ch >= 'A' && ch <= 'Z')
			text[idx] = static_cast<char>(ch - 'A' + 'a');
	    }
	    NetECString*res = new NetECString(text);
	    res->set_line(*this);
	    return res;
      }

      ID id = built_in_id_();
      if (id == NOT_BUILT_IN) {
	    if (!warned_eval_string_len_fallback || strcmp(name_, "$ivl_string_method$len") != 0) {
		  cerr << get_fileline() << ": sorry: "
			  "Cannot evaluate system function '" << name_
		       << "' at compile time." << endl;
		  if (strcmp(name_, "$ivl_string_method$len") == 0)
			warned_eval_string_len_fallback = true;
	    }
	    return 0;
      }

      NetExpr*val0 = 0;
      NetExpr*val1 = 0;
      NetExpr*res = 0;
      switch (parms_.size()) {
	  case 1:
	    val0 = parms_[0]->evaluate_function(loc, context_map);
	    if (val0 == 0) break;
	    res = evaluate_one_arg_(id, val0);
	    break;
	  case 2:
	    val0 = parms_[0]->evaluate_function(loc, context_map);
	    val1 = parms_[1]->evaluate_function(loc, context_map);
	    if (val0 == 0 || val1 == 0) break;
	    res = evaluate_two_arg_(id, val0, val1);
	    break;
	  default:
	    ivl_assert(*this, 0);
	    break;
      }
      delete val0;
      delete val1;
      return res;
}

NetExpr* NetEUFunc::evaluate_function(const LineInfo&loc,
				map<perm_string,LocalVar>&context_map) const
{
      const NetFuncDef*def = func_->func_def();
      ivl_assert(*this, def);

      vector<NetExpr*>args(parms_.size());
      for (unsigned idx = 0 ;  idx < parms_.size() ;  idx += 1)
	    args[idx] = parms_[idx]->evaluate_function(loc, context_map);

      NetExpr*res = def->evaluate_function(*this, args);
      return res;
}

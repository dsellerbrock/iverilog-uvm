/*
 * Copyright (c) 1998-2026 Stephen Williams <steve@icarus.com>
 * Copyright CERN 2013 / Stephen Williams (steve@icarus.com)
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
# include  <iostream>

# include  "compiler.h"
# include  "PExpr.h"
# include  "pform.h"
# include  "PWire.h"
# include  "Module.h"
# include  "ivl_assert.h"
# include  "netmisc.h"
# include  "util.h"
# include  <typeinfo>

using namespace std;

PMatchPattern::PMatchPattern(kind_t kind)
: kind_(kind)
{
}

PMatchPattern::~PMatchPattern()
{
      delete expression_;
      for (PMatchPattern*child : children_)
            delete child;
}

void PMatchPattern::children(vector<PMatchPattern*>*children)
{
      if (children) {
            children_.swap(*children);
            delete children;
      }
}

void PMatchPattern::declare_implicit_nets(LexicalScope*scope,
                                           NetNet::Type type)
{
      if (expression_)
            expression_->declare_implicit_nets(scope, type);
      for (PMatchPattern*child : children_)
            child->declare_implicit_nets(scope, type);
}

bool PMatchPattern::has_aa_term(Design*des, NetScope*scope) const
{
      if (expression_ && expression_->has_aa_term(des, scope))
            return true;
      for (PMatchPattern*child : children_)
            if (child->has_aa_term(des, scope))
                  return true;
      return false;
}

void PMatchPattern::reloc_lexical_pos_bind(bool parameter_context)
{
      if (expression_)
            expression_->reloc_lexical_pos_bind(parameter_context);
      for (PMatchPattern*child : children_)
            child->reloc_lexical_pos_bind(parameter_context);
}

void PMatchPattern::dump(ostream&out) const
{
      switch (kind_) {
          case CONSTANT:
            if (expression_) expression_->dump(out);
            else out << "<missing-constant>";
            break;
          case VARIABLE:
            out << "." << name_;
            break;
          case WILDCARD:
            out << ".*";
            break;
          case TAGGED:
            out << "tagged " << name_;
            if (!children_.empty()) {
                  out << " ";
                  children_.front()->dump(out);
            }
            break;
          case STRUCTURE:
            out << "'{";
            for (size_t idx = 0; idx < children_.size(); idx += 1) {
                  if (idx) out << ", ";
                  children_[idx]->dump(out);
            }
            out << "}";
            break;
      }
}

PExpr::PExpr()
: expr_type_(IVL_VT_NO_TYPE)
{
      expr_width_  = 0;
      min_width_   = 0;
      signed_flag_ = false;
}

PExpr::~PExpr()
{
}

void PExpr::declare_implicit_nets(LexicalScope*, NetNet::Type)
{
}

bool PExpr::has_aa_term(Design*, NetScope*) const
{
      return false;
}

void PExpr::reloc_lexical_pos_bind(bool)
{
}

NetNet* PExpr::elaborate_lnet(Design*, NetScope*, bool) const
{
      cerr << get_fileline() << ": error: "
           << "expression not valid in assign l-value: "
           << *this << endl;
      return 0;
}

NetNet* PExpr::elaborate_bi_net(Design*, NetScope*, bool) const
{
      cerr << get_fileline() << ": error: "
           << "expression not valid as argument to inout port: "
           << *this << endl;
      return 0;
}

bool PExpr::is_collapsible_net(Design*, NetScope*, NetNet::PortType) const
{
      return false;
}


const char* PExpr::width_mode_name(width_mode_t mode)
{
      switch (mode) {
          case PExpr::SIZED:
            return "sized";
          case PExpr::UNSIZED:
            return "unsized";
          case PExpr::EXPAND:
            return "expand";
          case PExpr::LOSSLESS:
            return "lossless";
          case PExpr::UPSIZE:
            return "upsize";
          default:
            return "??";
      }
}

PEAssignPattern::PEAssignPattern()
{
}

PEAssignPattern::PEAssignPattern(const list<PExpr*>&p)
: parms_(p.begin(), p.end())
{
}

PEAssignPattern::PEAssignPattern(const list<pair<perm_string,PExpr*>>&named)
{
      for (auto&kv : named) {
	    parm_names_.push_back(kv.first);
	    parms_.push_back(kv.second);
	    assignment_pattern_key_t key(
		  kv.first == lex_strings.make("default")
			? assignment_pattern_key_t::DEFAULT
			: assignment_pattern_key_t::EXPR);
	    if (key.kind == assignment_pattern_key_t::EXPR) {
		  pform_name_t name;
		  name.push_back(name_component_t(kv.first));
		  key.expr = new PEIdent(name, 0);
	    }
	    keys_.push_back(key);
      }
}

PEAssignPattern::PEAssignPattern(const list<assignment_pattern_item_t>&keyed)
{
      static const perm_string def_key = lex_strings.make("default");
      for (const auto&item : keyed) {
	    keys_.push_back(item.key);
	    parms_.push_back(item.value);

	    perm_string legacy_name;
	    if (item.key.kind == assignment_pattern_key_t::DEFAULT) {
		  legacy_name = def_key;
	    } else if (item.key.kind == assignment_pattern_key_t::EXPR) {
		  const PEIdent*id = dynamic_cast<const PEIdent*>(item.key.expr);
		  if (id && !id->path().package && id->path().name.size() == 1
		      && id->path().name.front().index.empty())
			legacy_name = id->path().name.front().name;
	    }
	    parm_names_.push_back(legacy_name);
      }
}

PEAssignPattern::PEAssignPattern(PExpr*replication, const list<PExpr*>&p)
: parms_(p.begin(), p.end()), replication_(replication)
{
}

PEAssignPattern::~PEAssignPattern()
{
}

void PEAssignPattern::reloc_lexical_pos_bind(bool parameter_context)
{
      if (replication_)
	    replication_->reloc_lexical_pos_bind(parameter_context);
      for (size_t idx = 0 ; idx < parms_.size() ; idx += 1) {
	    if (parms_[idx])
		  parms_[idx]->reloc_lexical_pos_bind(parameter_context);
      }
      for (auto&key : keys_)
	    if (key.expr)
		  key.expr->reloc_lexical_pos_bind(parameter_context);
}

PEBinary::PEBinary(char op, PExpr*l, PExpr*r)
: op_(op), left_(l), right_(r)
{
}

void PEBinary::reloc_lexical_pos_bind(bool parameter_context)
{
      if (left_) left_->reloc_lexical_pos_bind(parameter_context);
      if (right_) right_->reloc_lexical_pos_bind(parameter_context);
}

PEBinary::~PEBinary()
{
}

PEAssignExpr::PEAssignExpr(char op, PExpr*l, PExpr*r)
: PEBinary(op, l, r)
{
}

void PEBinary::declare_implicit_nets(LexicalScope*scope, NetNet::Type type)
{
      if (left_) left_->declare_implicit_nets(scope, type);
      if (right_) right_->declare_implicit_nets(scope, type);
}

bool PEBinary::has_aa_term(Design*des, NetScope*scope) const
{
      ivl_assert(*this, left_ && right_);
      return left_->has_aa_term(des, scope) || right_->has_aa_term(des, scope);
}

PECastSize::PECastSize(PExpr*si, PExpr*b)
: size_(si), base_(b)
{
}

PECastSize::~PECastSize()
{
}

bool PECastSize::has_aa_term(Design *des, NetScope *scope) const
{
	return base_->has_aa_term(des, scope);
}

PECastType::PECastType(data_type_t*t, PExpr*b)
: target_(t), base_(b)
{
      target_type_ = nullptr;
}

PECastType::~PECastType()
{
}

bool PECastType::has_aa_term(Design *des, NetScope *scope) const
{
	return base_->has_aa_term(des, scope);
}

PECastSign::PECastSign(bool signed_flag, PExpr *base)
: base_(base)
{
    signed_flag_ = signed_flag;
}

bool PECastSign::has_aa_term(Design *des, NetScope *scope) const
{
	return base_->has_aa_term(des, scope);
}

PEBComp::PEBComp(char op, PExpr*l, PExpr*r)
: PEBinary(op, l, r)
{
      l_width_ = 0;
      r_width_ = 0;
}

PEBComp::~PEBComp()
{
}

PEBLogic::PEBLogic(char op, PExpr*l, PExpr*r)
: PEBinary(op, l, r)
{
      ivl_assert(*this, op == 'a' || op == 'o' || op == 'q' || op == 'Q');
}

PEBLogic::~PEBLogic()
{
}

PEBLeftWidth::PEBLeftWidth(char op, PExpr*l, PExpr*r)
: PEBinary(op, l, r)
{
}

PEBLeftWidth::~PEBLeftWidth()
{
}

PEBPower::PEBPower(char op, PExpr*l, PExpr*r)
: PEBLeftWidth(op, l, r)
{
}

PEBPower::~PEBPower()
{
}

PEBShift::PEBShift(char op, PExpr*l, PExpr*r)
: PEBLeftWidth(op, l, r)
{
}

PEBShift::~PEBShift()
{
}

PECallFunction::PECallFunction(const pform_name_t &n, const vector<named_pexpr_t> &parms)
: path_(n), parms_(parms), is_overridden_(false)
{
}

PECallFunction::PECallFunction(PPackage *pkg, const pform_name_t &n, const vector<named_pexpr_t> &parms)
: path_(pkg, n), parms_(parms), is_overridden_(false)
{
}

static pform_name_t pn_from_ps(perm_string n)
{
      name_component_t tmp_name (n);
      pform_name_t tmp;
      tmp.push_back(tmp_name);
      return tmp;
}

PECallFunction::PECallFunction(PPackage *pkg, const pform_name_t &n, const list<named_pexpr_t> &parms)
: path_(pkg, n), parms_(parms.begin(), parms.end()), is_overridden_(false)
{
}

PECallFunction::PECallFunction(perm_string n, const vector<named_pexpr_t> &parms)
: path_(pn_from_ps(n)), parms_(parms), is_overridden_(false)
{
}

PECallFunction::PECallFunction(perm_string n)
: path_(pn_from_ps(n)), is_overridden_(false)
{
}

// NOTE: Anachronism. Try to work all use of svector out.
PECallFunction::PECallFunction(const pform_name_t &n, const list<named_pexpr_t> &parms)
: path_(n), parms_(parms.begin(), parms.end()), is_overridden_(false)
{
}

PECallFunction::PECallFunction(perm_string n, const list<named_pexpr_t> &parms)
: path_(pn_from_ps(n)), parms_(parms.begin(), parms.end()), is_overridden_(false)
{
}

PECallFunction::PECallFunction(PExpr*receiver, perm_string method_name,
			       const list<named_pexpr_t> &parms)
: path_(pn_from_ps(method_name)), parms_(parms.begin(), parms.end()),
  receiver_(receiver), is_overridden_(false)
{
}

PECallFunction::~PECallFunction()
{
      if (owns_leading_type_args_)
            delete_parmvalue(leading_type_args_);
      delete receiver_;
}

void PECallFunction::reloc_lexical_pos_bind(bool parameter_context)
{
      if (receiver_) receiver_->reloc_lexical_pos_bind(parameter_context);
      for (unsigned idx = 0 ; idx < parms_.size() ; idx += 1) {
	    if (parms_[idx].parm)
		  parms_[idx].parm->reloc_lexical_pos_bind(parameter_context);
      }
      for (unsigned idx = 0 ; idx < with_constraints_.size() ; idx += 1) {
	    if (with_constraints_[idx])
		  with_constraints_[idx]->reloc_lexical_pos_bind(parameter_context);
      }
}

void PECallFunction::declare_implicit_nets(LexicalScope*scope, NetNet::Type type)
{
      if (receiver_)
	    receiver_->declare_implicit_nets(scope, type);
      for (const auto &parm : parms_) {
	    if (parm.parm)
		  parm.parm->declare_implicit_nets(scope, type);
      }
}

bool PECallFunction::has_aa_term(Design*des, NetScope*scope) const
{
      bool flag = false;
      if (receiver_)
	    flag |= receiver_->has_aa_term(des, scope);
      for (const auto &parm : parms_) {
	    if (parm.parm)
		  flag |= parm.parm->has_aa_term(des, scope);
      }
      return flag;
}

PEConcat::PEConcat(const list<PExpr*>&p, PExpr*r)
: parms_(p.begin(), p.end()), width_modes_(SIZED, p.size()), repeat_(r)
{
      tested_scope_ = 0;
      repeat_count_ = 1;
}

void PEConcat::reloc_lexical_pos_bind(bool parameter_context)
{
      if (repeat_) repeat_->reloc_lexical_pos_bind(parameter_context);
      for (unsigned idx = 0 ; idx < parms_.size() ; idx += 1) {
	    if (parms_[idx])
		  parms_[idx]->reloc_lexical_pos_bind(parameter_context);
      }
}

PEConcat::~PEConcat()
{
      delete repeat_;
}

void PEConcat::declare_implicit_nets(LexicalScope*scope, NetNet::Type type)
{
      for (unsigned idx = 0 ; idx < parms_.size() ; idx += 1) {
	    parms_[idx]->declare_implicit_nets(scope, type);
      }
}

bool PEConcat::has_aa_term(Design*des, NetScope*scope) const
{
      bool flag = false;
      for (unsigned idx = 0 ; idx < parms_.size() ; idx += 1) {
	    flag = parms_[idx]->has_aa_term(des, scope) || flag;
      }
      if (repeat_)
            flag = repeat_->has_aa_term(des, scope) || flag;

      return flag;
}

void PEStreamWith::dump(std::ostream&out) const
{
      base_->dump(out);
      out << " with [";
      first_->dump(out);
      switch (kind_) {
          case IVL_STREAM_RANGE_RANGE: out << ":"; break;
          case IVL_STREAM_RANGE_UP:    out << "+:"; break;
          case IVL_STREAM_RANGE_DOWN:  out << "-:"; break;
          default: break;
      }
      if (second_) second_->dump(out);
      out << "]";
}

void PEStreamWith::declare_implicit_nets(LexicalScope*scope,
                                          NetNet::Type type)
{
      base_->declare_implicit_nets(scope, type);
      first_->declare_implicit_nets(scope, type);
      if (second_) second_->declare_implicit_nets(scope, type);
}

bool PEStreamWith::has_aa_term(Design*des, NetScope*scope) const
{
      return base_->has_aa_term(des, scope)
          || first_->has_aa_term(des, scope)
          || (second_ && second_->has_aa_term(des, scope));
}

void PEStreamWith::reloc_lexical_pos_bind(bool parameter_context)
{
      base_->reloc_lexical_pos_bind(parameter_context);
      first_->reloc_lexical_pos_bind(parameter_context);
      if (second_) second_->reloc_lexical_pos_bind(parameter_context);
}

PEEvent::PEEvent(PEEvent::edge_t t, PExpr*e, PExpr*condition)
: type_(t), expr_(e), condition_(condition)
{
}

PEEvent::~PEEvent()
{
}

PEEvent::edge_t PEEvent::type() const
{
      return type_;
}

bool PEEvent::has_aa_term(Design*des, NetScope*scope) const
{
      ivl_assert(*this, expr_);
      bool flag = expr_->has_aa_term(des, scope);
      if (condition_)
	    flag = condition_->has_aa_term(des, scope) || flag;
      return flag;
}

PExpr* PEEvent::expr() const
{
      return expr_;
}

PExpr* PEEvent::condition() const
{
      return condition_;
}

PENull::PENull(void)
{
}

PENull::~PENull()
{
}

PEAssocType::PEAssocType(data_type_t*index_type)
: index_type_(index_type), wildcard_index_(false)
{
}

PEAssocType::PEAssocType(data_type_t*index_type, bool wildcard_index)
: index_type_(index_type), wildcard_index_(wildcard_index)
{
}

PEAssocType::~PEAssocType()
{
}

PEFNumber::PEFNumber(verireal*v)
: value_(v)
{
}

PEFNumber::~PEFNumber()
{
      delete value_;
}

const verireal& PEFNumber::value() const
{
      return *value_;
}

PEIdent::PEIdent(const pform_name_t&that, unsigned lexical_pos)
: path_(that), lexical_pos_(lexical_pos), no_implicit_sig_(false)
{
}

PEIdent::PEIdent(perm_string s, unsigned lexical_pos, bool no_implicit_sig)
: lexical_pos_(lexical_pos), no_implicit_sig_(no_implicit_sig)
{
      path_.name.push_back(name_component_t(s));
}

PEIdent::PEIdent(PPackage*pkg, const pform_name_t&that, unsigned lexical_pos)
: path_(pkg, that), lexical_pos_(lexical_pos), no_implicit_sig_(true)
{
}

PEIdent::~PEIdent()
{
      if (owns_leading_type_args_)
            delete_parmvalue(leading_type_args_);
}

void PEIdent::append_name(perm_string name)
{
      path_.name.push_back(name_component_t(name));
}

void PEIdent::append_index(const index_component_t&index)
{
      assert(!path_.name.empty());
      path_.name.back().index.push_back(index);
}

PEIdent* PEIdent::clone_for_reference() const
{
      PEIdent*res = path_.package
          ? new PEIdent(path_.package, path_.name, lexical_pos_)
          : new PEIdent(path_.name, lexical_pos_);
      res->leading_type_args_ = leading_type_args_;
      res->owns_leading_type_args_ = false;
      res->scoped_type_prefix_ = scoped_type_prefix_;
      res->clocking_access_ = clocking_access_;
      return res;
}

PEMemberAccess::PEMemberAccess(PExpr*base, perm_string member_name)
: base_(base), member_name_(member_name)
{
}

PEMemberAccess::~PEMemberAccess()
{
      delete base_;
}

PEPostSelect::PEPostSelect(PExpr*base, const index_component_t&index)
: base_(base), index_(index)
{
}

PEPostSelect::~PEPostSelect()
{
      delete base_;
      delete index_.msb;
      delete index_.lsb;
}

static bool find_enum_constant(LexicalScope*scope, perm_string name)
{
      return std::any_of(scope->enum_sets.cbegin(), scope->enum_sets.cend(),
                         [name](const enum_type_t *cur) {
	    return std::any_of(cur->names->cbegin(), cur->names->cend(),
	                       [name](const named_pexpr_t&idx){return idx.name == name;});
      });
}

void PEIdent::reloc_lexical_pos_bind(bool parameter_context)
{
      lexical_pos_ = UINT_MAX;
      bind_parameter_expr_ = parameter_context;
      for (pform_name_t::iterator name = path_.name.begin()
		 ; name != path_.name.end() ; ++name) {
	    for (std::list<index_component_t>::iterator idx = name->index.begin()
		       ; idx != name->index.end() ; ++idx) {
		  if (idx->msb)
			idx->msb->reloc_lexical_pos_bind(parameter_context);
		  if (idx->lsb)
			idx->lsb->reloc_lexical_pos_bind(parameter_context);
	    }
      }
}

void PEIdent::declare_implicit_nets(LexicalScope*scope, NetNet::Type type)
{
        /* We create an implicit wire if:
	   - this is a simple identifier
           - an identifier of that name has not already been declared in
             any enclosing scope.
	   - this is not an implicit named port connection */
     if (no_implicit_sig_)
	    return;
     if (path_.package)
	    return;
     if (path_.name.size() == 1 && path_.name.front().index.empty()) {
            perm_string name = path_.name.front().name;
            LexicalScope*ss = scope;
            while (ss) {
                  if (ss->wires.find(name) != ss->wires.end())
                        return;
                  if (ss->parameters.find(name) != ss->parameters.end())
                        return;
                  if (ss->genvars.find(name) != ss->genvars.end())
                        return;
                  if (ss->events.find(name) != ss->events.end())
                        return;
                  if (find_enum_constant(ss, name))
                        return;
		  // An explicitly imported package symbol is already a
		  // declaration visible in this scope (IEEE 1800-2017 26.3).
		  // Do not manufacture an implicit wire with the same name.
		  // In particular, enum literals imported in a module body and
		  // then used as parameter actuals were shadowed by such a wire;
		  // constant elaboration consequently rejected the literal as a
		  // net instead of reading its package enum value.
		  if (ss->explicit_imports.find(name) != ss->explicit_imports.end())
			return;
                  /* Strictly speaking, we should also check for name clashes
                     with tasks, functions, named blocks, and generate
                     blocks. However, this information is not readily
                     available. As these names would not be legal in this
                     context, we can declare implicit nets here and rely
                     on later checks for name clashes to report the error. */

                  /* Module/interface INSTANCE names are available and
                     matter: an interface instance used as a port actual
                     (`producer p (b);`) must not spawn a phantom
                     implicit wire `b` — it would shadow the instance
                     scope for hierarchical references like `b.data`. */
                  if (const Module*mod = dynamic_cast<const Module*>(ss)) {
                        for (const PGate*g : mod->get_gates())
                              if (g->get_name() == name)
                                    return;
                  }

                  ss = ss->parent_scope();
            }
            PWire*net = new PWire(name, lexical_pos_, type, NetNet::NOT_A_PORT);
            net->set_file(get_file());
            net->set_lineno(get_lineno());
            scope->wires[name] = net;
            if (warn_implicit) {
                  cerr << get_fileline() << ": warning: implicit "
                       "definition of wire '" << name << "'." << endl;
     }
}

}

bool PEIdent::has_aa_term(Design*des, NetScope*scope) const
{
      symbol_search_results sr;
      if (!symbol_search(this, des, scope, path_, lexical_pos_, &sr))
	    return false;

      // Class properties are not considered automatic since a non-blocking
      // assignment to an object stored in an automatic variable is supposed to
      // capture a reference to the object, not the variable.
      if (!sr.path_tail.empty() && sr.net && sr.net->class_type())
	    return false;

      if (sr.net) {
	    switch (sr.net->lifetime_override()) {
		case IVL_VLT_AUTOMATIC:
		      return true;
		case IVL_VLT_STATIC:
		      return false;
		case IVL_VLT_INHERITED:
		      break;
	    }
      }

      return sr.scope->is_auto();
}

void PEMemberAccess::declare_implicit_nets(LexicalScope*scope, NetNet::Type type)
{
      if (base_)
	    base_->declare_implicit_nets(scope, type);
}

bool PEMemberAccess::has_aa_term(Design*des, NetScope*scope) const
{
      return base_ ? base_->has_aa_term(des, scope) : false;
}

PENewArray::PENewArray(PExpr*size_expr, PExpr*init_expr)
: size_(size_expr), init_(init_expr)
{
}

PENewArray::~PENewArray()
{
      delete size_;
}

PENewClass::PENewClass(void)
: class_type_(nullptr)
{
}

PENewClass::PENewClass(const list<named_pexpr_t> &p, data_type_t *class_type)
: parms_(p.begin(), p.end()), class_type_(class_type)
{
}

PENewClass::~PENewClass()
{
      delete class_type_;
}

PENewCopy::PENewCopy(PExpr*src)
: src_(src)
{
}

PENewCopy::~PENewCopy()
{
}

PENumber::PENumber(verinum*vp)
: value_(vp)
{
      ivl_assert(*this, vp);
}

PENumber::~PENumber()
{
      delete value_;
}

const verinum& PENumber::value() const
{
      return *value_;
}

PEUnbounded::PEUnbounded()
{
}

PEUnbounded::~PEUnbounded()
{
}

PEString::PEString(char*s)
: text_(s? s : ""), text_width_(0), text_width_valid_(false),
  parsed_value_valid_(false)
{
      delete[]s;
}

PEString::~PEString()
{
}

const string& PEString::value() const
{
      return text_;
}

const verinum& PEString::parsed_value() const
{
      if (!parsed_value_valid_) {
	    parsed_value_cache_ = verinum(text_);
	    parsed_value_valid_ = true;
      }

      return parsed_value_cache_;
}

PETernary::PETernary(PExpr*e, PExpr*t, PExpr*f)
: expr_(e), tru_(t), fal_(f)
{
}

void PETernary::reloc_lexical_pos_bind(bool parameter_context)
{
      if (expr_) expr_->reloc_lexical_pos_bind(parameter_context);
      if (tru_) tru_->reloc_lexical_pos_bind(parameter_context);
      if (fal_) fal_->reloc_lexical_pos_bind(parameter_context);
}

PETernary::~PETernary()
{
}

void PETernary::declare_implicit_nets(LexicalScope*scope, NetNet::Type type)
{
      ivl_assert(*this, expr_ && tru_ && fal_);
      expr_->declare_implicit_nets(scope, type);
      tru_->declare_implicit_nets(scope, type);
      fal_->declare_implicit_nets(scope, type);
}

bool PETernary::has_aa_term(Design*des, NetScope*scope) const
{
      ivl_assert(*this, expr_ && tru_ && fal_);
      return expr_->has_aa_term(des, scope)
           || tru_->has_aa_term(des, scope)
           || fal_->has_aa_term(des, scope);
}

PETypename::PETypename(data_type_t*dt)
: data_type_(dt)
{
}

PETypename::~PETypename()
{
}

PEUnary::PEUnary(char op, PExpr*ex)
: op_(op), expr_(ex)
{
}

void PEUnary::reloc_lexical_pos_bind(bool parameter_context)
{
      if (expr_) expr_->reloc_lexical_pos_bind(parameter_context);
}

PEUnary::~PEUnary()
{
}

void PEUnary::declare_implicit_nets(LexicalScope*scope, NetNet::Type type)
{
      ivl_assert(*this, expr_);
      expr_->declare_implicit_nets(scope, type);
}

bool PEUnary::has_aa_term(Design*des, NetScope*scope) const
{
      ivl_assert(*this, expr_);
      return expr_->has_aa_term(des, scope);
}

PEVoid::PEVoid()
{
}

PEVoid::~PEVoid()
{
}

PEConstraintIf::PEConstraintIf(PExpr*cond, std::list<PExpr*>*then_items,
			       std::list<PExpr*>*else_items)
: cond_(cond)
{
      if (then_items) {
	    then_items_.assign(then_items->begin(), then_items->end());
	    delete then_items;
      }
      if (else_items) {
	    else_items_.assign(else_items->begin(), else_items->end());
	    delete else_items;
      }
}

PEConstraintIf::~PEConstraintIf()
{
      delete cond_;
      for (PExpr*item : then_items_)
	    delete item;
      for (PExpr*item : else_items_)
	    delete item;
}

void PEConstraintIf::dump(std::ostream&out) const
{
      out << "if (";
      if (cond_) cond_->dump(out);
      out << ") { ... }";
      if (!else_items_.empty())
	    out << " else { ... }";
}

unsigned PEConstraintIf::test_width(Design*, NetScope*, width_mode_t&)
{
      expr_type_ = IVL_VT_BOOL;
      expr_width_ = 1;
      min_width_ = 1;
      signed_flag_ = false;
      return expr_width_;
}

NetExpr* PEConstraintIf::elaborate_expr(Design*des, NetScope*, unsigned,
					unsigned) const
{
      cerr << get_fileline() << ": error: Conditional constraint sets are "
	   << "only valid inside constraint blocks." << endl;
      des->errors += 1;
      return 0;
}

PEConstraintForeach::PEConstraintForeach(perm_string array_name,
					 std::list<perm_string>*loop_vars,
					 std::list<PExpr*>*items)
: array_name_(array_name)
{
      if (loop_vars) {
	    loop_vars_.assign(loop_vars->begin(), loop_vars->end());
	    delete loop_vars;
      }
      if (items) {
	    items_.assign(items->begin(), items->end());
	    delete items;
      }
}

PEConstraintForeach::PEConstraintForeach(perm_string array_name,
					 std::list<perm_string>*prefix_names,
					 perm_string member_name,
					 std::list<perm_string>*loop_vars,
					 std::list<PExpr*>*items)
: array_name_(array_name), member_name_(member_name)
{
      if (prefix_names) {
	    prefix_names_.assign(prefix_names->begin(), prefix_names->end());
	    delete prefix_names;
      }
      if (loop_vars) {
	    loop_vars_.assign(loop_vars->begin(), loop_vars->end());
	    delete loop_vars;
      }
      if (items) {
	    items_.assign(items->begin(), items->end());
	    delete items;
      }
}

PEConstraintForeach::~PEConstraintForeach()
{
      for (PExpr*item : items_)
	    delete item;
}

void PEConstraintForeach::dump(std::ostream&out) const
{
      out << "foreach (" << array_name_;
      if (has_hierarchical_target())
	    out << "[...]." << member_name_;
      out << "[...]) { ... }";
}

unsigned PEConstraintForeach::test_width(Design*, NetScope*, width_mode_t&)
{
      expr_type_ = IVL_VT_BOOL;
      expr_width_ = 1;
      min_width_ = 1;
      signed_flag_ = false;
      return expr_width_;
}

NetExpr* PEConstraintForeach::elaborate_expr(Design*des, NetScope*, unsigned,
					     unsigned) const
{
      cerr << get_fileline() << ": error: Iterative constraints are only "
	   << "valid inside constraint blocks." << endl;
      des->errors += 1;
      return 0;
}

PEConstraintOrder::PEConstraintOrder(std::list<PExpr*>*before_list,
				     std::list<PExpr*>*after_list)
{
      if (before_list) {
	    before_.assign(before_list->begin(), before_list->end());
	    delete before_list;
      }
      if (after_list) {
	    after_.assign(after_list->begin(), after_list->end());
	    delete after_list;
      }
}

PEConstraintOrder::~PEConstraintOrder()
{
      for (PExpr*item : before_)
	    delete item;
      for (PExpr*item : after_)
	    delete item;
}

void PEConstraintOrder::dump(std::ostream&out) const
{
      out << "solve ... before ...;";
}

unsigned PEConstraintOrder::test_width(Design*, NetScope*, width_mode_t&)
{
      expr_type_ = IVL_VT_BOOL;
      expr_width_ = 1;
      min_width_ = 1;
      signed_flag_ = false;
      return expr_width_;
}

NetExpr* PEConstraintOrder::elaborate_expr(Design*des, NetScope*, unsigned,
					   unsigned) const
{
      cerr << get_fileline() << ": error: solve...before is only "
	   << "valid inside constraint blocks." << endl;
      des->errors += 1;
      return 0;
}

PEInside::PEInside(PExpr* expr, std::list<inside_range_t>* ranges,
		   bool is_dist)
: expr_(expr), is_dist_(is_dist)
{
      if (ranges) {
	    ranges_.assign(ranges->begin(), ranges->end());
	    delete ranges;
      }
}

PEInside::~PEInside()
{
      delete expr_;
      for (auto& r : ranges_) {
	    delete r.lo;
	    delete r.hi;
	    delete r.weight;
      }
}

void PEInside::dump(std::ostream& out) const
{
      out << "(";
      expr_->dump(out);
      out << (is_dist_ ? " dist {" : " inside {");
      for (size_t i = 0 ; i < ranges_.size() ; i++) {
	    if (i > 0) out << ", ";
	    if (ranges_[i].is_range) {
		  out << "[";
		  if (ranges_[i].lo) ranges_[i].lo->dump(out);
		  else out << "$";
		  out << ":";
		  if (ranges_[i].hi) ranges_[i].hi->dump(out);
		  else out << "$";
		  out << "]";
	    } else {
		  ranges_[i].hi->dump(out);
	    }
      }
      out << "})";
}

unsigned PEInside::test_width(Design*, NetScope*, width_mode_t&)
{
      return 1;
}

/* Note: PEInside::elaborate_expr is implemented in elab_expr.cc
 * where netlist.h, NetEBComp, NetEBLogic, NetESFunc, etc. are available. */

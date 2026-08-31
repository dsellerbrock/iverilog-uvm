/*
 * Copyright (c) 1998-2024 Stephen Williams (steve@icarus.com)
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
# include  <iterator>
# include  <map>
# include  <tuple>

# include  "Statement.h"
# include  "PExpr.h"
# include  "pform.h"
# include  "ivl_assert.h"

using namespace std;

Statement::~Statement()
{
}

PAssign_::PAssign_(PExpr*lval__, PExpr*ex, bool is_constant, bool is_init,
		   bool delete_rval, const typedef_t*rval_typedef)
: event_(0), count_(0), lval_(lval__), rval_(ex), is_constant_(is_constant),
  is_init_(is_init), delete_rval_(delete_rval),
  rval_typedef_(rval_typedef)
{
      delay_ = 0;
}

PAssign_::PAssign_(PExpr*lval__, PExpr*de, PExpr*ex)
: event_(0), count_(0), lval_(lval__), rval_(ex), is_constant_(false)
{
      delay_ = de;
}

PAssign_::PAssign_(PExpr*lval__, PExpr*cnt, PEventStatement*ev, PExpr*ex)
: event_(ev), count_(cnt), lval_(lval__), rval_(ex), is_constant_(false)
{
      delay_ = 0;
}

PAssign_::~PAssign_()
{
      delete lval_;
      if (delete_rval_)
	    delete rval_;
}

PAssign::PAssign(PExpr*lval__, PExpr*ex)
: PAssign_(lval__, ex, false), op_(0)
{
}

PAssign::PAssign(PExpr*lval__, char op, PExpr*ex)
: PAssign_(lval__, ex, false), op_(op)
{
}

PAssign::PAssign(PExpr*lval__, PExpr*d, PExpr*ex)
: PAssign_(lval__, d, ex), op_(0)
{
}

PAssign::PAssign(PExpr*lval__, PExpr*cnt, PEventStatement*d, PExpr*ex)
: PAssign_(lval__, cnt, d, ex), op_(0)
{
}

PAssign::PAssign(PExpr*lval__, PExpr*ex, bool is_constant, bool is_init)
: PAssign_(lval__, ex, is_constant, is_init), op_(0)
{
}

PAssign::PAssign(PExpr*lval__, PExpr*ex, bool is_constant, bool is_init,
		 bool delete_rval, const typedef_t*rval_typedef)
: PAssign_(lval__, ex, is_constant, is_init, delete_rval, rval_typedef), op_(0)
{
}

PAssign::~PAssign()
{
}

PAssignNB::PAssignNB(PExpr*lval__, PExpr*ex)
: PAssign_(lval__, ex, false)
{
}

PAssignNB::PAssignNB(PExpr*lval__, PExpr*d, PExpr*ex)
: PAssign_(lval__, d, ex)
{
}

PAssignNB::PAssignNB(PExpr*lval__, PExpr*cnt, PEventStatement*d, PExpr*ex)
: PAssign_(lval__, cnt, d, ex)
{
}

PAssignNB::~PAssignNB()
{
}

PBlock::PBlock(perm_string n, LexicalScope*parent, BL_TYPE t)
: PScope(n, parent), bl_type_(t)
{
}

PBlock::PBlock(BL_TYPE t)
: PScope(perm_string()), bl_type_(t)
{
}

PBlock::~PBlock()
{
      for (unsigned idx = 0 ;  idx < list_.size() ;  idx += 1)
	    delete list_[idx];
}

bool PBlock::var_init_needs_explicit_lifetime() const
{
      return default_lifetime == STATIC;
}

PChainConstructor* PBlock::extract_chain_constructor()
{
      if (list_.empty())
	    return 0;

      if (PChainConstructor*res = dynamic_cast<PChainConstructor*> (list_[0])) {
	    for (size_t idx = 0 ; idx < list_.size()-1 ; idx += 1)
		  list_[idx] = list_[idx+1];
	    list_.resize(list_.size()-1);
	    return res;
      }

	// Some parser paths represent `super.new(...)` as a plain task call.
	// Detect and canonicalize that first statement into a chain constructor
	// so constructor arguments are preserved.
      if (PCallTask*call = dynamic_cast<PCallTask*>(list_[0])) {
	    const pform_name_t&path = call->path();
	    if (peek_head_name(path) == perm_string::literal(SUPER_TOKEN)
		&& peek_tail_name(path) == perm_string::literal("new")) {
		  PChainConstructor*res = new PChainConstructor(call->parms());
		  res->set_line(*call);
		  delete call;
		  for (size_t idx = 0 ; idx < list_.size()-1 ; idx += 1)
			list_[idx] = list_[idx+1];
		  list_.resize(list_.size()-1);
		  return res;
	    }
      }

      return 0;
}

void PBlock::set_join_type(PBlock::BL_TYPE type)
{
      ivl_assert(*this, bl_type_ == BL_PAR);
      ivl_assert(*this, type==BL_PAR || type==BL_JOIN_NONE || type==BL_JOIN_ANY);
      bl_type_ = type;
}

void PBlock::set_statement(const vector<Statement*>&st)
{
      list_ = st;
}

void PBlock::push_statement_front(Statement*that)
{
      ivl_assert(*this, bl_type_==BL_SEQ);

      list_.resize(list_.size()+1);
      for (size_t idx = list_.size()-1 ; idx > 0 ; idx -= 1)
	    list_[idx] = list_[idx-1];

      list_[0] = that;
}

PNamedItem::SymbolType PBlock::symbol_type() const
{
      return BLOCK;
}

/*
 * contains_detached_fork walks the pform statement tree, staying within
 * the current activation frame (it does not descend into called tasks or
 * functions — those are separate frames), looking for a fork/join_none or
 * fork/join_any whose spawned branches outlive the enclosing statement.
 * See the base-class comment in Statement.h for how elaborate_scope uses
 * this to keep a per-entry frame for automatic-local blocks whose locals
 * are captured by a detached branch.
 */
bool PBlock::contains_detached_fork() const
{
      if (bl_type_ == BL_JOIN_NONE || bl_type_ == BL_JOIN_ANY)
	    return true;
      for (unsigned idx = 0 ; idx < list_.size() ; idx += 1)
	    if (list_[idx] && list_[idx]->contains_detached_fork())
		  return true;
      return false;
}

bool PCase::contains_detached_fork() const
{
      if (!items_)
	    return false;
      for (unsigned idx = 0 ; idx < items_->size() ; idx += 1) {
	    Item*cur = (*items_)[idx];
	    if (cur && cur->stat && cur->stat->contains_detached_fork())
		  return true;
      }
      return false;
}

PRandCase::~PRandCase()
{
      if (items_) {
	    for (PCase::Item*cur : *items_) {
		  if (!cur) continue;
		  for (PExpr*e : cur->expr) delete e;
		  delete cur->stat;
		  delete cur;
	    }
	    delete items_;
      }
}

bool PRandCase::contains_detached_fork() const
{
      if (!items_)
	    return false;
      for (PCase::Item*cur : *items_)
	    if (cur && cur->stat && cur->stat->contains_detached_fork())
		  return true;
      return false;
}

bool PCondit::contains_detached_fork() const
{
      if (if_ && if_->contains_detached_fork())
	    return true;
      if (else_ && else_->contains_detached_fork())
	    return true;
      return false;
}

bool PDelayStatement::contains_detached_fork() const
{
      return statement_ && statement_->contains_detached_fork();
}

bool PCycleDelay::contains_detached_fork() const
{
      return statement_ && statement_->contains_detached_fork();
}

bool PDoWhile::contains_detached_fork() const
{
      return statement_ && statement_->contains_detached_fork();
}

bool PEventStatement::contains_detached_fork() const
{
      return statement_ && statement_->contains_detached_fork();
}

bool PForeach::contains_detached_fork() const
{
      return statement_ && statement_->contains_detached_fork();
}

bool PForever::contains_detached_fork() const
{
      return statement_ && statement_->contains_detached_fork();
}

bool PForStatement::contains_detached_fork() const
{
      return statement_ && statement_->contains_detached_fork();
}

bool PRepeat::contains_detached_fork() const
{
      return statement_ && statement_->contains_detached_fork();
}

bool PWhile::contains_detached_fork() const
{
      return statement_ && statement_->contains_detached_fork();
}

namespace {

struct ctor_order_state_t {
      std::set<size_t> definitely_initialized;
      std::set<size_t> maybe_initialized;
};

struct ctor_order_channel_t {
      bool reachable = false;
      ctor_order_state_t state;
};

struct ctor_order_flow_t {
      ctor_order_channel_t normal;
      ctor_order_channel_t returned;
      ctor_order_channel_t broken;
      ctor_order_channel_t continued;
};

static std::set<size_t> ctor_order_intersection_(
      const std::set<size_t>&left, const std::set<size_t>&right)
{
      std::set<size_t> result;
      std::set_intersection(left.begin(), left.end(), right.begin(), right.end(),
			    std::inserter(result, result.end()));
      return result;
}

static std::set<size_t> ctor_order_union_(
      const std::set<size_t>&left, const std::set<size_t>&right)
{
      std::set<size_t> result = left;
      result.insert(right.begin(), right.end());
      return result;
}

static void ctor_order_merge_alternatives_(ctor_order_channel_t&dst,
					    const ctor_order_channel_t&src)
{
      if (!src.reachable)
	    return;
      if (!dst.reachable) {
	    dst = src;
	    return;
      }
      dst.state.definitely_initialized = ctor_order_intersection_(
	    dst.state.definitely_initialized,
	    src.state.definitely_initialized);
      dst.state.maybe_initialized = ctor_order_union_(
	    dst.state.maybe_initialized, src.state.maybe_initialized);
}

static ctor_order_flow_t ctor_order_identity_(const ctor_order_state_t&state)
{
      ctor_order_flow_t result;
      result.normal.reachable = true;
      result.normal.state = state;
      return result;
}

} // namespace

/*
 * Keep this analysis on the pform tree. The ordinary statement elaborators
 * intentionally fold constant conditionals, elaborate one case body more than
 * once when it has multiple guards, and lower some loops into quite different
 * NetProc shapes. None of those transformations preserve the source-order and
 * common-loop/fork facts required by IEEE 1800-2017 19.5.
 */
class pform_constructor_order_audit_t {
    public:
      pform_constructor_order_audit_t(
	    const pform_constructor_order_classifier_t&classifier,
	    const std::set<size_t>&initially_initialized)
	  : classifier_(classifier)
	  {
	    initially_initialized_.definitely_initialized = initially_initialized;
	    initially_initialized_.maybe_initialized = initially_initialized;
	  }

      pform_constructor_order_result_t run(const Statement*statement)
      {
	    collect_(statement);
	    for (const std::pair<const Statement*const,assignment_info_t>&entry :
		 assignments_)
		  if (entry.second.initializes_constant)
			result_.authorized_instance_constant_initializers.insert(
			      entry.first);
	    check_forbidden_regions_();

	    ctor_order_flow_t flow = flow_(statement, initially_initialized_);
	    ctor_order_channel_t exits;
	    ctor_order_merge_alternatives_(exits, flow.normal);
	    ctor_order_merge_alternatives_(exits, flow.returned);
	    result_.has_reachable_exit = exits.reachable;
	    if (exits.reachable)
		  result_.definitely_initialized_at_exit =
			exits.state.definitely_initialized;
	    return result_;
      }

    private:
      enum region_kind_t { REGION_LOOP, REGION_JOIN_NONE };

      struct region_t {
	    region_kind_t kind;
	    const Statement*statement;

	    bool operator==(const region_t&that) const
	    { return kind == that.kind && statement == that.statement; }
      };

      struct assignment_info_t {
	    pform_constructor_order_assignment_t assignment;
	    bool initializes_constant = false;
	    size_t initialized_property = 0;
	    bool constructs_covergroup = false;
	    std::vector<pform_constructor_order_dependency_t> dependencies;
	    std::vector<region_t> regions;
      };

      const pform_constructor_order_classifier_t&classifier_;
      ctor_order_state_t initially_initialized_;
      std::vector<const PBlock*>block_stack_;
      std::vector<region_t>region_stack_;
      std::map<const Statement*,assignment_info_t>assignments_;
      std::map<size_t,std::vector<const assignment_info_t*> >initializers_;
      std::vector<const assignment_info_t*>constructors_;
      pform_constructor_order_result_t result_;
      std::set<std::tuple<const Statement*,size_t> >reported_order_;
      std::set<std::tuple<const Statement*,size_t> >reported_reassignment_;
      std::set<std::tuple<const Statement*,size_t,const Statement*,int> >
	    reported_region_;

      void collect_assignment_(const Statement*statement, const PExpr*lval,
			       const PExpr*rval, bool for_initializer)
      {
	    assignment_info_t info;
	    info.assignment.statement = statement;
	    info.assignment.lval = lval;
	    info.assignment.rval = rval;
	    info.assignment.block_stack = &block_stack_;
	    info.assignment.for_initializer = for_initializer;
	    if (for_initializer) {
		  info.assignment.plain_blocking = true;
	    } else if (const PAssign*assign =
		       dynamic_cast<const PAssign*>(statement)) {
		  info.assignment.plain_blocking =
			assign->op() == 0 && !assign->has_timing_control();
	    }

	    info.initializes_constant =
		  classifier_.classify_instance_constant_initializer(
			info.assignment, info.initialized_property);
	    info.constructs_covergroup =
		  classifier_.classify_embedded_covergroup_constructor(
			info.assignment, info.dependencies);
	    info.regions = region_stack_;

	    if (!info.initializes_constant && !info.constructs_covergroup)
		  return;

	    std::pair<std::map<const Statement*,assignment_info_t>::iterator,bool>
		  inserted = assignments_.insert(std::make_pair(statement, info));
	    assignment_info_t*stored = &inserted.first->second;
	    if (stored->initializes_constant)
		  initializers_[stored->initialized_property].push_back(stored);
	    if (stored->constructs_covergroup)
		  constructors_.push_back(stored);
      }

      void collect_(const Statement*statement)
      {
	    if (!statement)
		  return;

	    if (const PAssign_*assign = dynamic_cast<const PAssign_*>(statement)) {
		  collect_assignment_(statement, assign->lval(), assign->rval(), false);
		  return;
	    }

	    if (const PBlock*block = dynamic_cast<const PBlock*>(statement)) {
		  block_stack_.push_back(block);
		  bool join_none = block->bl_type_ == PBlock::BL_JOIN_NONE;
		  if (join_none)
			region_stack_.push_back(region_t{REGION_JOIN_NONE, block});
		  for (const Statement*child : block->list_)
			collect_(child);
		  if (join_none)
			region_stack_.pop_back();
		  block_stack_.pop_back();
		  return;
	    }

	    if (const PCondit*cond = dynamic_cast<const PCondit*>(statement)) {
		  collect_(cond->if_clause());
		  collect_(cond->else_clause());
		  return;
	    }

	    if (const PCase*pcase = dynamic_cast<const PCase*>(statement)) {
		  if (pcase->items_)
			for (const PCase::Item*item : *pcase->items_)
			      if (item) collect_(item->stat);
		  return;
	    }

	    if (const PRandCase*pcase = dynamic_cast<const PRandCase*>(statement)) {
		  if (pcase->items_)
			for (const PCase::Item*item : *pcase->items_)
			      if (item) collect_(item->stat);
		  return;
	    }

	    if (const PCaseMatches*pcase =
		  dynamic_cast<const PCaseMatches*>(statement)) {
		  if (pcase->items_)
			for (const PCaseMatches::Item*item : *pcase->items_)
			      if (item) collect_(item->stat);
		  return;
	    }

	    if (const PDelayStatement*delay =
		  dynamic_cast<const PDelayStatement*>(statement)) {
		  collect_(delay->statement_);
		  return;
	    }

	    if (const PCycleDelay*delay = dynamic_cast<const PCycleDelay*>(statement)) {
		  collect_(delay->statement_);
		  return;
	    }

	    if (const PEventStatement*event =
		  dynamic_cast<const PEventStatement*>(statement)) {
		  collect_(event->statement());
		  return;
	    }

	    if (const PDoWhile*loop = dynamic_cast<const PDoWhile*>(statement)) {
		  region_stack_.push_back(region_t{REGION_LOOP, loop});
		  collect_(loop->statement_);
		  region_stack_.pop_back();
		  return;
	    }

	    if (const PForeach*loop = dynamic_cast<const PForeach*>(statement)) {
		  region_stack_.push_back(region_t{REGION_LOOP, loop});
		  collect_(loop->statement_);
		  region_stack_.pop_back();
		  return;
	    }

	    if (const PForever*loop = dynamic_cast<const PForever*>(statement)) {
		  region_stack_.push_back(region_t{REGION_LOOP, loop});
		  collect_(loop->statement_);
		  region_stack_.pop_back();
		  return;
	    }

	    if (const PForStatement*loop =
		  dynamic_cast<const PForStatement*>(statement)) {
		  if (loop->name1_)
			collect_assignment_(loop, loop->name1_, loop->expr1_, true);
		  region_stack_.push_back(region_t{REGION_LOOP, loop});
		  collect_(loop->statement_);
		  region_stack_.pop_back();
		  collect_(loop->step_);
		  return;
	    }

	    if (const PRepeat*loop = dynamic_cast<const PRepeat*>(statement)) {
		  region_stack_.push_back(region_t{REGION_LOOP, loop});
		  collect_(loop->statement_);
		  region_stack_.pop_back();
		  return;
	    }

	    if (const PWhile*loop = dynamic_cast<const PWhile*>(statement)) {
		  region_stack_.push_back(region_t{REGION_LOOP, loop});
		  collect_(loop->statement_);
		  region_stack_.pop_back();
		  return;
	    }
      }

      const LineInfo*initializer_site_(const assignment_info_t&info) const
      {
	    return info.assignment.lval
		  ? static_cast<const LineInfo*>(info.assignment.lval)
		  : static_cast<const LineInfo*>(info.assignment.statement);
      }

      const LineInfo*constructor_site_(const assignment_info_t&info) const
      {
	    return info.assignment.rval
		  ? static_cast<const LineInfo*>(info.assignment.rval)
		  : static_cast<const LineInfo*>(info.assignment.statement);
      }

      void check_forbidden_regions_()
      {
	    for (const assignment_info_t*constructor : constructors_) {
		  for (const pform_constructor_order_dependency_t&dependency :
		       constructor->dependencies) {
			std::map<size_t,std::vector<const assignment_info_t*> >::const_iterator
			      found = initializers_.find(dependency.property_idx);
			if (found == initializers_.end())
			      continue;
			for (const assignment_info_t*initializer : found->second) {
			      for (const region_t&left : initializer->regions) {
				    for (const region_t&right : constructor->regions) {
					  if (!(left == right))
						continue;
					  std::tuple<const Statement*,size_t,const Statement*,int>
						key(constructor->assignment.statement,
						    dependency.property_idx, left.statement,
						    static_cast<int>(left.kind));
					  if (!reported_region_.insert(key).second)
						continue;
					  // The structural prohibition is the more specific
					  // IEEE 1800 19.5 failure.  Suppress a second generic
					  // before-initialization diagnostic if this same call
					  // appears earlier than the initializer in the region.
					  reported_order_.insert(std::make_tuple(
						constructor->assignment.statement,
						dependency.property_idx));
					  pform_constructor_order_violation_t violation;
					  violation.kind = left.kind == REGION_LOOP
						? PFORM_CTOR_ORDER_SHARED_LOOP
						: PFORM_CTOR_ORDER_SHARED_JOIN_NONE;
					  violation.property_idx = dependency.property_idx;
					  violation.initializer_site =
						initializer_site_(*initializer);
					  violation.constructor_site =
						constructor_site_(*constructor);
					  violation.reference_site = dependency.reference_site;
					  violation.covergroup_name = dependency.covergroup_name;
					  violation.region = left.statement;
					  result_.violations.push_back(violation);
				    }
			      }
			}
		  }
	    }
      }

      ctor_order_state_t apply_assignment_(const Statement*statement,
					    const ctor_order_state_t&input)
      {
	    ctor_order_state_t output = input;
	    std::map<const Statement*,assignment_info_t>::const_iterator found =
		  assignments_.find(statement);
	    if (found == assignments_.end())
		  return output;

	    const assignment_info_t&info = found->second;
	    // The new expression is evaluated before its assignment takes effect.
	    // Check the covergroup dependencies before marking this assignment as
	    // an instance-constant initializer.
	    if (info.constructs_covergroup) {
		  for (const pform_constructor_order_dependency_t&dependency :
		       info.dependencies) {
			if (input.definitely_initialized.count(
			      dependency.property_idx))
			      continue;
			std::tuple<const Statement*,size_t>key(
			      statement, dependency.property_idx);
			if (!reported_order_.insert(key).second)
			      continue;
			pform_constructor_order_violation_t violation;
			violation.kind = PFORM_CTOR_ORDER_NOT_INITIALIZED;
			violation.property_idx = dependency.property_idx;
			violation.constructor_site = constructor_site_(info);
			violation.reference_site = dependency.reference_site;
			violation.covergroup_name = dependency.covergroup_name;
			result_.violations.push_back(violation);
		  }
	    }
	    if (info.initializes_constant) {
		  if (input.maybe_initialized.count(info.initialized_property)) {
			std::tuple<const Statement*,size_t>key(
			      statement, info.initialized_property);
			if (reported_reassignment_.insert(key).second) {
			      pform_constructor_order_violation_t violation;
			      violation.kind = PFORM_CTOR_ORDER_REASSIGNMENT;
			      violation.property_idx = info.initialized_property;
			      violation.initializer_site = initializer_site_(info);
			      result_.violations.push_back(violation);
			}
			result_.authorized_instance_constant_initializers.erase(
			      statement);
			result_.rejected_instance_constant_initializers.insert(
			      statement);
		  }
		  output.definitely_initialized.insert(info.initialized_property);
		  output.maybe_initialized.insert(info.initialized_property);
	    }
	    return output;
      }

      static ctor_order_channel_t channel_(const ctor_order_state_t&state)
      {
	    ctor_order_channel_t result;
	    result.reachable = true;
	    result.state = state;
	    return result;
      }

      ctor_order_flow_t flow_sequence_(const std::vector<Statement*>&statements,
					 const ctor_order_state_t&input)
      {
	    ctor_order_flow_t result;
	    ctor_order_channel_t current = channel_(input);
	    for (const Statement*statement : statements) {
		  if (!current.reachable)
			break;
		  ctor_order_flow_t child = flow_(statement, current.state);
		  ctor_order_merge_alternatives_(result.returned, child.returned);
		  ctor_order_merge_alternatives_(result.broken, child.broken);
		  ctor_order_merge_alternatives_(result.continued, child.continued);
		  current = child.normal;
	    }
	    result.normal = current;
	    return result;
      }

      static void merge_flow_alternatives_(ctor_order_flow_t&dst,
					     const ctor_order_flow_t&src)
      {
	    ctor_order_merge_alternatives_(dst.normal, src.normal);
	    ctor_order_merge_alternatives_(dst.returned, src.returned);
	    ctor_order_merge_alternatives_(dst.broken, src.broken);
	    ctor_order_merge_alternatives_(dst.continued, src.continued);
      }

      ctor_order_flow_t flow_parallel_(const PBlock*block,
					 const ctor_order_state_t&input)
      {
	    std::vector<ctor_order_flow_t>branches;
	    for (const Statement*statement : block->list_)
		  branches.push_back(flow_(statement, input));

	    if (block->bl_type_ == PBlock::BL_JOIN_NONE)
		  return ctor_order_identity_(input);

	    ctor_order_flow_t result;
	    if (branches.empty())
		  return ctor_order_identity_(input);

	    if (block->bl_type_ == PBlock::BL_PAR) {
		  // Every normally completing branch has finished at join, so a
		  // property initialized by any such branch is definite afterward.
		  result.normal = channel_(input);
		  for (const ctor_order_flow_t&branch : branches) {
			if (branch.normal.reachable) {
			      result.normal.state.definitely_initialized.insert(
				    branch.normal.state.definitely_initialized.begin(),
				    branch.normal.state.definitely_initialized.end());
			      result.normal.state.maybe_initialized.insert(
				    branch.normal.state.maybe_initialized.begin(),
				    branch.normal.state.maybe_initialized.end());
			}
			ctor_order_merge_alternatives_(result.returned,
						 branch.returned);
		  }
		  return result;
	    }

	    // join_any may resume after any branch, while all other branches are
	    // still live. Only facts true after every possible first finisher are
	    // definite at the continuation.
	    for (const ctor_order_flow_t&branch : branches)
		  ctor_order_merge_alternatives_(result.normal, branch.normal);
	    if (!result.normal.reachable)
		  result.normal = channel_(input);
	    return result;
      }

      ctor_order_flow_t flow_zero_trip_loop_(const Statement*body,
					       const ctor_order_state_t&input)
      {
	    ctor_order_flow_t body_flow = flow_(body, input);
	    ctor_order_flow_t result = ctor_order_identity_(input);
	    result.returned = body_flow.returned;
	    // A zero-iteration path always exists, so body initializations do not
	    // become definite after while/for/repeat/foreach.
	    return result;
      }

      ctor_order_flow_t flow_(const Statement*statement,
			      const ctor_order_state_t&input)
      {
	    if (!statement)
		  return ctor_order_identity_(input);

	    if (dynamic_cast<const PAssign_*>(statement)) {
		  return ctor_order_identity_(apply_assignment_(statement, input));
	    }

	    if (const PBlock*block = dynamic_cast<const PBlock*>(statement)) {
		  if (block->bl_type_ == PBlock::BL_SEQ)
			return flow_sequence_(block->list_, input);
		  return flow_parallel_(block, input);
	    }

	    if (const PCondit*cond = dynamic_cast<const PCondit*>(statement)) {
		  ctor_order_flow_t result;
		  merge_flow_alternatives_(result, flow_(cond->if_clause(), input));
		  merge_flow_alternatives_(result, flow_(cond->else_clause(), input));
		  return result;
	    }

	    if (const PCase*pcase = dynamic_cast<const PCase*>(statement)) {
		  ctor_order_flow_t result;
		  bool has_default = false;
		  if (pcase->items_) {
			for (const PCase::Item*item : *pcase->items_) {
			      if (!item) continue;
			      has_default = has_default || item->expr.empty();
			      merge_flow_alternatives_(result,
					       flow_(item->stat, input));
			}
		  }
		  if (!has_default)
			merge_flow_alternatives_(result,
					 ctor_order_identity_(input));
		  return result;
	    }

	    if (const PRandCase*pcase = dynamic_cast<const PRandCase*>(statement)) {
		  ctor_order_flow_t result = ctor_order_identity_(input);
		  if (pcase->items_)
			for (const PCase::Item*item : *pcase->items_)
			      if (item) merge_flow_alternatives_(
				    result, flow_(item->stat, input));
		  // A zero total weight executes no branch.
		  return result;
	    }

	    if (const PCaseMatches*pcase =
		  dynamic_cast<const PCaseMatches*>(statement)) {
		  ctor_order_flow_t result;
		  bool has_default = false;
		  if (pcase->items_) {
			for (const PCaseMatches::Item*item : *pcase->items_) {
			      if (!item) continue;
			      has_default = has_default || item->is_default;
			      merge_flow_alternatives_(result,
					       flow_(item->stat, input));
			}
		  }
		  if (!has_default)
			merge_flow_alternatives_(result,
					 ctor_order_identity_(input));
		  return result;
	    }

	    if (const PDelayStatement*delay =
		  dynamic_cast<const PDelayStatement*>(statement))
		  return flow_(delay->statement_, input);

	    if (const PCycleDelay*delay = dynamic_cast<const PCycleDelay*>(statement))
		  return flow_(delay->statement_, input);

	    if (const PEventStatement*event =
		  dynamic_cast<const PEventStatement*>(statement))
		  return flow_(event->statement(), input);

	    if (const PDoWhile*loop = dynamic_cast<const PDoWhile*>(statement)) {
		  ctor_order_flow_t body = flow_(loop->statement_, input);
		  ctor_order_flow_t result;
		  ctor_order_merge_alternatives_(result.normal, body.normal);
		  ctor_order_merge_alternatives_(result.normal, body.broken);
		  ctor_order_merge_alternatives_(result.normal, body.continued);
		  result.returned = body.returned;
		  return result;
	    }

	    if (const PForeach*loop = dynamic_cast<const PForeach*>(statement))
		  return flow_zero_trip_loop_(loop->statement_, input);

	    if (const PRepeat*loop = dynamic_cast<const PRepeat*>(statement))
		  return flow_zero_trip_loop_(loop->statement_, input);

	    if (const PWhile*loop = dynamic_cast<const PWhile*>(statement))
		  return flow_zero_trip_loop_(loop->statement_, input);

	    if (const PForever*loop = dynamic_cast<const PForever*>(statement)) {
		  ctor_order_flow_t body = flow_(loop->statement_, input);
		  ctor_order_flow_t result;
		  result.normal = body.broken;
		  result.returned = body.returned;
		  return result;
	    }

	    if (const PForStatement*loop =
		  dynamic_cast<const PForStatement*>(statement)) {
		  ctor_order_state_t before_loop = input;
		  if (loop->name1_)
			before_loop = apply_assignment_(loop, before_loop);

		  ctor_order_flow_t body = flow_(loop->statement_, before_loop);
		  ctor_order_channel_t step_input;
		  ctor_order_merge_alternatives_(step_input, body.normal);
		  ctor_order_merge_alternatives_(step_input, body.continued);
		  ctor_order_flow_t step;
		  if (loop->step_ && step_input.reachable)
			step = flow_(loop->step_, step_input.state);

		  ctor_order_flow_t result = ctor_order_identity_(before_loop);
		  result.returned = body.returned;
		  ctor_order_merge_alternatives_(result.returned, step.returned);
		  return result;
	    }

	    if (dynamic_cast<const PReturn*>(statement)) {
		  ctor_order_flow_t result;
		  result.returned = channel_(input);
		  return result;
	    }

	    if (dynamic_cast<const PBreak*>(statement)) {
		  ctor_order_flow_t result;
		  result.broken = channel_(input);
		  return result;
	    }

	    if (dynamic_cast<const PContinue*>(statement)) {
		  ctor_order_flow_t result;
		  result.continued = channel_(input);
		  return result;
	    }

	    return ctor_order_identity_(input);
      }
};

pform_constructor_order_result_t audit_pform_constructor_order(
      const Statement*statement,
      const pform_constructor_order_classifier_t&classifier,
      const std::set<size_t>&initially_initialized)
{
      pform_constructor_order_audit_t audit(classifier,
					     initially_initialized);
      return audit.run(statement);
}

PCallTask::PCallTask(const pform_name_t &n, const list<named_pexpr_t> &p)
: package_(0), path_(n), parms_(p.begin(), p.end())
{
}

PCallTask::PCallTask(PPackage *pkg, const pform_name_t &n, const list<named_pexpr_t> &p)
: package_(pkg), path_(n), parms_(p.begin(), p.end())
{
}

PCallTask::PCallTask(perm_string n, const list<named_pexpr_t> &p)
: package_(0), parms_(p.begin(), p.end())
{
      path_.push_back(name_component_t(n));
}

PCallTask::PCallTask(PExpr*receiver, perm_string method_name,
		     const list<named_pexpr_t> &p)
: package_(0), parms_(p.begin(), p.end()), receiver_(receiver)
{
      path_.push_back(name_component_t(method_name));
}

PCallTask::~PCallTask()
{
      delete_parmvalue(leading_type_args_);
	// receiver_ is deliberately not deleted here: elaboration may
	// transfer it into a synthesized PECallFunction (which owns its
	// receiver). pform objects are process-lifetime, so this does not
	// leak in practice.
}

const pform_name_t& PCallTask::path() const
{
      return path_;
}

PCase::PCase(ivl_case_quality_t q, NetCase::TYPE t, PExpr*ex,
             std::vector<PCase::Item*>*l, bool quality_if)
: quality_(q), type_(t), expr_(ex), items_(l), quality_if_(quality_if)
{
}

PCase::~PCase()
{
      delete expr_;
      for (unsigned idx = 0 ;  idx < items_->size() ;  idx += 1)
	    if ((*items_)[idx]->stat) delete (*items_)[idx]->stat;

      delete items_;
}

PCaseMatches::~PCaseMatches()
{
      delete expr_;
      if (items_) {
            for (auto*it : *items_) {
                  if (it && it->stat) delete it->stat;
                  delete it;
            }
            delete items_;
      }
}

PCaseMatches::Item::~Item()
{
      delete pattern;
}

PCAssign::PCAssign(PExpr*l, PExpr*r)
: lval_(l), expr_(r)
{
}

PCAssign::~PCAssign()
{
      delete lval_;
      delete expr_;
}

PChainConstructor::PChainConstructor(const list<named_pexpr_t> &parms)
: parms_(parms.begin(), parms.end())
{
}

PChainConstructor::PChainConstructor(const vector<named_pexpr_t> &parms)
: parms_(parms)
{
}

PChainConstructor::~PChainConstructor()
{
}

PCondit::PCondit(PExpr*ex, Statement*i, Statement*e)
: expr_(ex), if_(i), else_(e)
{
}

PCondit::~PCondit()
{
      delete expr_;
      delete if_;
      delete else_;
}

PExpr* PCondit::release_cond_expr()
{
      PExpr*tmp = expr_;
      expr_ = nullptr;
      return tmp;
}

Statement* PCondit::release_if_clause()
{
      Statement*tmp = if_;
      if_ = nullptr;
      return tmp;
}

Statement* PCondit::release_else_clause()
{
      Statement*tmp = else_;
      else_ = nullptr;
      return tmp;
}

PDeassign::PDeassign(PExpr*l)
: lval_(l)
{
}

PDeassign::~PDeassign()
{
      delete lval_;
}


PDelayStatement::PDelayStatement(PExpr*d, Statement*st)
: delay_(d), statement_(st)
{
}

PDelayStatement::~PDelayStatement()
{
}

PCycleDelay::PCycleDelay(PExpr*count, Statement*st)
: count_(count), statement_(st)
{
}

PCycleDelay::~PCycleDelay()
{
}

PDisable::PDisable(const pform_name_t&sc)
: scope_(sc)
{
}

PDisable::~PDisable()
{
}

PDoWhile::PDoWhile(PExpr*ex, Statement*st)
: cond_(ex), statement_(st)
{
}

PDoWhile::~PDoWhile()
{
      delete cond_;
      delete statement_;
}

PEventStatement::PEventStatement(const std::vector<PEEvent*>&ee)
: expr_(ee), statement_(0), always_sens_(false)
{
      ivl_assert(*this, expr_.size() > 0);
}


PEventStatement::PEventStatement(PEEvent*ee)
: expr_(1), statement_(0), always_sens_(false)
{
      expr_[0] = ee;
}

PEventStatement::PEventStatement(bool always_sens)
: statement_(0), always_sens_(always_sens)
{
}

PEventStatement::~PEventStatement()
{
	// delete the events and the statement?
}

void PEventStatement::set_statement(Statement*st)
{
      statement_ = st;
}

bool PEventStatement::has_aa_term(Design*des, NetScope*scope)
{
      bool flag = false;
      for (unsigned idx = 0 ; idx < expr_.size() ; idx += 1) {
	    flag = expr_[idx]->has_aa_term(des, scope) || flag;
      }
      return flag;
}

PForce::PForce(PExpr*l, PExpr*r)
: lval_(l), expr_(r)
{
}

PForce::~PForce()
{
      delete lval_;
      delete expr_;
}

PForeach::PForeach(const pform_name_t&av, const list<perm_string>&ix,
		   Statement*s, unsigned lexical_pos)
: array_path_(av), index_vars_(ix.begin(), ix.end()), statement_(s),
  lexical_pos_(lexical_pos)
{
}

PForeach::~PForeach()
{
      delete statement_;
}

PForever::PForever(Statement*s)
: statement_(s)
{
}

PForever::~PForever()
{
      delete statement_;
}

PForStatement::PForStatement(PExpr*n1, PExpr*e1, PExpr*cond,
			     Statement*step, Statement*st)
: name1_(n1), expr1_(e1), cond_(cond), step_(step), statement_(st)
{
}

PForStatement::~PForStatement()
{
}

PProcess::~PProcess()
{
      delete statement_;
}

PRelease::PRelease(PExpr*l)
: lval_(l)
{
}

PRelease::~PRelease()
{
      delete lval_;
}

PRepeat::PRepeat(PExpr*e, Statement*s)
: expr_(e), statement_(s)
{
}

PRepeat::~PRepeat()
{
      delete expr_;
      delete statement_;
}

PReturn::PReturn(PExpr*e)
: expr_(e)
{
}

PReturn::~PReturn()
{
      delete expr_;
}

PTrigger::PTrigger(PPackage*pkg, const pform_name_t&ev, unsigned lexical_pos)
: event_(pkg, ev), lexical_pos_(lexical_pos)
{
}

PTrigger::~PTrigger()
{
}

PNBTrigger::PNBTrigger(const pform_name_t&ev, unsigned lexical_pos, PExpr*dly)
: event_(ev), lexical_pos_(lexical_pos), dly_(dly)
{
}

PNBTrigger::~PNBTrigger()
{
}

PWhile::PWhile(PExpr*ex, Statement*st)
: cond_(ex), statement_(st)
{
}

PWhile::~PWhile()
{
      delete cond_;
      delete statement_;
}

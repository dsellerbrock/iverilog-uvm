/*
 * Copyright (c) 1999-2021 Stephen Williams (steve@icarus.com)
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
# include "PTask.h"
# include "ivl_assert.h"

using namespace std;

PTaskFunc::PTaskFunc(perm_string n, LexicalScope*p)
: PScope(n,p), this_type_(0), ports_(0)
{
}

PTaskFunc::~PTaskFunc()
{
}

bool PTaskFunc::var_init_needs_explicit_lifetime() const
{
      return default_lifetime == STATIC;
}

void PTaskFunc::set_ports(vector<pform_tf_port_t>*p)
{
	// ports_ may already hold ports appended by
	// append_stmt_port_decls() (statement-context direction
	// declarations parsed during the body). The tf_item_list ports
	// in p appeared earlier in the source, so they go first.
      if (ports_ == 0) {
	    ports_ = p;
	    return;
      }
      if (p) {
	    ports_->insert(ports_->begin(), p->begin(), p->end());
	    delete p;
      }
}

void PTaskFunc::append_stmt_port_decls(vector<pform_tf_port_t>*p)
{
      if (p == 0) return;
      if (ports_ == 0)
	    ports_ = new vector<pform_tf_port_t>;
      ports_->insert(ports_->end(), p->begin(), p->end());
      delete p;
}

void PTaskFunc::set_this(class_type_t*type, PWire*this_wire)
{
      ivl_assert(*this, this_type_ == 0);
      this_type_ = type;

	// Push a synthesis argument that is the "this" value.
      if (ports_==0)
	    ports_ = new vector<pform_tf_port_t>;

      size_t use_size = ports_->size();
      ports_->resize(use_size + 1);
      for (size_t idx = use_size ; idx > 0 ; idx -= 1)
	    ports_->at(idx) = ports_->at(idx-1);

      ports_->at(0) = pform_tf_port_t(this_wire);
}

void PTaskFunc::set_method_type_only(class_type_t*type)
{
      if (this_type_ == 0)
	    this_type_ = type;
      else
	    ivl_assert(*this, this_type_ == type);
}

PTask::PTask(perm_string name, LexicalScope*parent, bool is_auto__)
: PTaskFunc(name, parent), statement_(0)
{
      is_auto_ = is_auto__;
}

PTask::~PTask()
{
}

void PTask::set_statement(Statement*s)
{
      ivl_assert(*this, statement_ == 0);
      statement_ = s;
}

PNamedItem::SymbolType PTask::symbol_type() const
{
      return TASK;
}

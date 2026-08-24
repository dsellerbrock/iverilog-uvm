/*
 * Copyright (c) 2007-2019 Stephen Williams (steve@icarus.com)
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


# include  "pform_types.h"
# include  "pform.h"
# include  "PExpr.h"
# include  "PPackage.h"
# include  <set>

namespace {

struct interface_modport_resolver_t {
      explicit interface_modport_resolver_t(Design*design) : des(design) { }

      Design*des;
      std::set<const data_type_t*>active_types;
      std::set<const typedef_t*>active_typedefs;
      std::set<std::pair<const NetScope*,perm_string> >active_parameters;
};

static perm_string resolve_interface_modport_type_(
      interface_modport_resolver_t&resolver, NetScope*scope,
      const data_type_t*type);

static NetScope* find_type_parameter_scope_(NetScope*scope, perm_string name)
{
      for (NetScope*cur = scope; cur; cur = cur->parent()) {
	    std::map<perm_string,NetScope::param_expr_t>::const_iterator param =
		  cur->parameters.find(name);
	    if (param != cur->parameters.end() && param->second.type_flag)
		  return cur;
      }

      return 0;
}

static perm_string resolve_interface_modport_parameter_(
      interface_modport_resolver_t&resolver, NetScope*scope,
      perm_string name);

static perm_string resolve_interface_modport_expr_(
      interface_modport_resolver_t&resolver, NetScope*scope,
      const PExpr*expr)
{
      if (!expr)
	    return perm_string();

      if (const PETypename*type_expr =
		dynamic_cast<const PETypename*>(expr))
	    return resolve_interface_modport_type_(
		  resolver, scope, type_expr->get_type());

      const PEIdent*ident = dynamic_cast<const PEIdent*>(expr);
      if (!ident)
	    return perm_string();

      const pform_scoped_name_t&path = ident->path();
      if (path.name.size() != 1 || !path.name.front().index.empty())
	    return perm_string();

      NetScope*lookup_scope = scope;
      if (path.package) {
	    if (!resolver.des)
		  return perm_string();
	    lookup_scope = resolver.des->find_package(
		  path.package->pscope_name());
	    if (!lookup_scope)
		  return perm_string();
      } else if (find_type_parameter_scope_(lookup_scope,
					     path.name.front().name)) {
	    return resolve_interface_modport_parameter_(
		  resolver, lookup_scope, path.name.front().name);
      }

      if (!resolver.des || !lookup_scope)
	    return perm_string();

      typedef_t*type_decl = lookup_scope->find_typedef(
	    resolver.des, path.name.front().name);
      if (!type_decl)
	    return perm_string();

      return resolve_interface_modport_type_(
	    resolver, lookup_scope, type_decl->get_data_type());
}

static perm_string resolve_interface_modport_parameter_(
      interface_modport_resolver_t&resolver, NetScope*scope,
      perm_string name)
{
      NetScope*parameter_scope = find_type_parameter_scope_(scope, name);
      if (!parameter_scope)
	    return perm_string();

      const std::pair<const NetScope*,perm_string>key(parameter_scope, name);
      if (!resolver.active_parameters.insert(key).second)
	    return perm_string();

      std::map<perm_string,NetScope::param_expr_t>::const_iterator param =
	    parameter_scope->parameters.find(name);
      const NetScope::param_expr_t&record = param->second;
      NetScope*value_scope = record.val_scope
	    ? record.val_scope : parameter_scope;

      perm_string result = resolve_interface_modport_expr_(
	    resolver, value_scope, record.val_expr);
      if (result.nil() && record.val_type)
	    result = resolve_interface_modport_type_(
		  resolver, value_scope, record.val_type);

      resolver.active_parameters.erase(key);
      return result;
}

static perm_string resolve_interface_modport_type_(
      interface_modport_resolver_t&resolver, NetScope*scope,
      const data_type_t*type)
{
      if (!type)
	    return perm_string();

      if (const interface_type_t*interface_type =
		dynamic_cast<const interface_type_t*>(type))
	    return interface_type->modport;

      if (!resolver.active_types.insert(type).second)
	    return perm_string();

      perm_string result;
      if (const array_base_t*array_type =
		dynamic_cast<const array_base_t*>(type)) {
	    result = resolve_interface_modport_type_(
		  resolver, scope, array_type->base_type.get());

      } else if (const type_parameter_t*type_parameter =
		       dynamic_cast<const type_parameter_t*>(type)) {
	    if (resolver.des && scope)
		  result = resolve_interface_modport_parameter_(
			resolver, scope, type_parameter->name);

      } else if (const typeref_t*type_ref =
		       dynamic_cast<const typeref_t*>(type)) {
	    const typedef_t*typedef_decl = type_ref->typedef_ref();
	    if (typedef_decl
		&& resolver.active_typedefs.insert(typedef_decl).second) {
		  NetScope*definition_scope = scope;
		  if (resolver.des && scope) {
			if (NetScope*found = scope->find_typedef_scope(
			      resolver.des, typedef_decl))
			      definition_scope = found;
		  }
		  result = resolve_interface_modport_type_(
			resolver, definition_scope,
			typedef_decl->get_data_type());
		  resolver.active_typedefs.erase(typedef_decl);
	    }
      }

      resolver.active_types.erase(type);
      return result;
}

} // namespace

perm_string pform_interface_modport(const data_type_t*type)
{
      interface_modport_resolver_t resolver(0);
      return resolve_interface_modport_type_(resolver, 0, type);
}

perm_string pform_interface_modport(Design*des, NetScope*scope,
				    const data_type_t*type)
{
      interface_modport_resolver_t resolver(des);
      return resolve_interface_modport_type_(resolver, scope, type);
}

nettype_t::nettype_t(perm_string name, data_type_t*type,
                     const pform_scoped_name_t*resolution_function)
: name_(name), direct_type_(type), alias_type_(nullptr),
  resolution_function_(resolution_function
                       ? new pform_scoped_name_t(*resolution_function) : nullptr)
{
}

nettype_t::nettype_t(perm_string name, nettype_t*alias)
: name_(name), alias_type_(alias)
{
}

nettype_t::~nettype_t()
{
}

PNamedItem::SymbolType nettype_t::symbol_type() const
{
      return NETTYPE;
}

const nettype_t* nettype_t::canonical_type() const
{
      std::set<const nettype_t*> seen;
      const nettype_t*cur = this;
      while (cur && cur->alias_type_) {
            if (!seen.insert(cur).second)
                  return nullptr;
            cur = cur->alias_type_;
      }
      if (cur && !seen.insert(cur).second)
            return nullptr;
      return cur;
}

nettype_t* nettype_t::canonical_type()
{
      return const_cast<nettype_t*>(
            static_cast<const nettype_t*>(this)->canonical_type());
}

data_type_t::~data_type_t()
{
}

PNamedItem::SymbolType data_type_t::symbol_type() const
{
      return TYPE;
}

string_type_t::~string_type_t()
{
}

typeref_t::~typeref_t()
{
      delete_parmvalue(overrides);
}

atom_type_t size_type (atom_type_t::INT, true);

std::ostream& foreach_index_type_t::debug_dump(std::ostream&out) const
{
      out << "<foreach-index:";
      for (size_t idx = 0 ; idx < target_path.size() ; idx += 1) {
	    if (idx > 0)
		  out << ".";
	    out << target_path[idx];
      }
      out << "[" << index_depth << "]>";
      return out;
}

PNamedItem::SymbolType enum_type_t::symbol_type() const
{
      return ENUM;
}

PNamedItem::SymbolType class_type_t::symbol_type() const
{
      return CLASS;
}

bool typedef_t::set_data_type(data_type_t *t)
{
      if (data_type.get())
	    return false;

      data_type.reset(t);

      return true;
}

bool typedef_t::set_basic_type(enum basic_type bt)
{
      if (bt == ANY)
	    return true;
      if (basic_type != ANY && bt != basic_type)
	    return false;

      basic_type = bt;

      return true;
}

std::ostream& operator<< (std::ostream&out, enum typedef_t::basic_type bt)
{
	switch (bt) {
	case typedef_t::ANY:
		out << "any";
		break;
	case typedef_t::ENUM:
		out << "enum";
		break;
	case typedef_t::STRUCT:
		out << "struct";
		break;
	case typedef_t::UNION:
		out << "union";
		break;
	case typedef_t::CLASS:
		out << "class";
		break;
	}

	return out;
}

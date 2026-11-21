/*
 * Copyright (c) 2002-2025 Stephen Williams (steve@icarus.com)
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

# include  "config.h"
# include  "util.h"
# include  "PExpr.h"
# include  "netlist.h"
# include  "netmisc.h"
# include  "netvector.h"
# include  "Module.h"
# include  <algorithm>
# include  <iostream>
# include  <cassert>

using namespace std;

NetExpr* evaluate_attribute(PExpr*exp, verinum&legacy_value,
			    Design*des, NetScope*scope)
{
      if (!exp) {
	    legacy_value = verinum(1);
	    return nullptr;
      }

      NetExpr*tmp = elab_and_eval(des, scope, exp, -1, true);
      if (!tmp)
	    return nullptr;

      if (const auto*ce = dynamic_cast<const NetEConst*>(tmp)) {
	    legacy_value = ce->value();
      } else if (const auto*cer = dynamic_cast<const NetECReal*>(tmp)) {
	    legacy_value = verinum(cer->value().as_long());
      } else {
	    cerr << exp->get_fileline() << ": error: ``"
		 << *exp << "'' is not a constant expression." << endl;
	    des->errors += 1;
	    delete tmp;
	    return nullptr;
      }
      return tmp;
}

/*
 * The evaluate_attributes function evaluates the attribute
 * expressions from the map, and returns a table in a form suitable
 * for passing to netlist devices.
 */

attrib_list_t* evaluate_attributes(const map<perm_string,PExpr*>&att,
				   unsigned&natt,
				   Design*des, NetScope*scope)
{
      natt = att.size();
      if (natt == 0)
	    return 0;

      attrib_list_t*table = new attrib_list_t [natt];

      unsigned idx = 0;

      typedef map<perm_string,PExpr*>::const_iterator iter_t;
      for (iter_t cur = att.begin() ;  cur != att.end() ;  ++ cur , idx += 1) {
	    table[idx].key = (*cur).first;
	    delete evaluate_attribute(cur->second, table[idx].val, des, scope);
      }

      assert(idx == natt);
      return table;
}

NetNet::decl_attribute_t make_decl_attribute(const named_pexpr_t&spec,
					    unique_ptr<NetExpr> value,
					    Design*des, NetScope*scope)
{
      NetNet::decl_attribute_t attr;
      attr.name = spec.name;
      attr.set_line(spec);
      if (!spec.parm) {
	    value.reset(new NetEConst(&netvector_t::scalar_bool,
				      verinum(verinum::V1, 1)));
	    attr.integral_kind = IVL_DECL_ATTR_SCALAR;
      } else if (const auto*constant = dynamic_cast<const NetEConst*>(value.get())) {
	    ivl_type_t type = constant->net_type();
	    const auto*number = dynamic_cast<const PENumber*>(spec.parm);
	    if (const auto*cast = dynamic_cast<const PECastType*>(spec.parm)) {
		  type = cast->resolve_target_type(des, scope);
	    } else if (const auto*par = dynamic_cast<const NetEConstParam*>(constant)) {
		  const auto&params = par->scope()->parameters;
		  auto it = params.find(par->name());
		  if (it != params.end() && it->second.ivl_type)
			type = it->second.ivl_type;
	    }

	      // Unsized constant folding can trim the materialized value.
	      // Restore the self-determined width for VPI.
	    unsigned width = max(constant->expr_width(), spec.parm->expr_width());
	    const verinum&bits = constant->value();
	    const bool packed_text = bits.is_string() && type && type->packed();
	    if (packed_text || (!bits.is_string() && width > bits.len())) {
		  verinum full = cast_to_width(bits, width);
		  if (packed_text) {
			verinum packed(verinum::V0, width);
			for (unsigned i = 0; i < width; ++i)
			      packed.set(i, full.get(i));
			full = packed;
		  }
		  full.has_sign(constant->has_sign());
		  value.reset(new NetEConst(full));
	    }

	    const auto*vec = dynamic_cast<const netvector_t*>(type);
	    if (vec == &netvector_t::time_signed || vec == &netvector_t::time_unsigned)
		  attr.integral_kind = IVL_DECL_ATTR_TIME;
	    else if (type ? type->get_scalar()
			  : width == 1 && (!number || number->value().is_single()))
		  attr.integral_kind = IVL_DECL_ATTR_SCALAR;
	    else if (width <= 32 &&
		     (vec == &netvector_t::atom2s32 || vec == &netvector_t::atom2u32
		      || vec == &netvector_t::atom2s16 || vec == &netvector_t::atom2u16
		      || vec == &netvector_t::atom2s8 || vec == &netvector_t::atom2u8
		      || (vec && vec->get_isint())))
		  attr.integral_kind = IVL_DECL_ATTR_INTEGER;
      }
      value->set_line(spec);
      attr.value = std::move(value);
      return attr;
}

void Design::evaluate_module_attributes()
{
      // Keep the legacy target map's precedence while retaining both origins for VPI.
      for (bool on_definition : {false, true}) {
	    for (const auto&job : module_attribute_jobs) {
		  if (job.on_definition != on_definition)
			continue;

		  const Module*module = job.owners.front()->module_definition();
		  const bool publish_vpi = !module->program_block && !module->is_interface
			&& !module->is_checker;
		  for (const auto&entry : *job.specs) {
			const auto&spec = entry.second;
			verinum legacy;
			unique_ptr<NetExpr> value(evaluate_attribute(spec.parm, legacy, this,
								     job.eval_scope));
			for (NetScope*owner : job.owners)
			      owner->attribute(spec.name, legacy);

			if (!publish_vpi || spec.get_file().nil() || (spec.parm && !value))
			      continue;

			auto attr = make_shared<NetNet::decl_attribute_t>(
			      make_decl_attribute(spec, std::move(value), this, job.eval_scope));
			attr->on_definition = on_definition;
			for (NetScope*owner : job.owners)
			      owner->add_module_attribute(attr);
		  }
	    }
      }
      module_attribute_jobs.clear();
}

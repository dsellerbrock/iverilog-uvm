// SPDX-FileCopyrightText: 2023-2025 Lars-Peter Clausen <lars@metafoo.de>
// SPDX-License-Identifier: GPL-2.0-or-later

#include "PExpr.h"
#include "ivl_assert.h"
#include "map_named_args.h"
#include "netlist.h"

#include <iostream>

std::vector<PExpr*> map_named_args(Design *des,
			           const std::vector<perm_string> &names,
			           const std::vector<named_pexpr_t> &parms)
{
      std::vector<PExpr*> args(names.size());

      bool has_named = false;
      for (size_t i = 0; i < parms.size(); i++) {
	    if (!parms[i].name.nil()) {
		  has_named = true;
		  break;
	    }
      }

      if (!has_named) {
	    size_t limit = parms.size() < args.size()? parms.size() : args.size();
	    for (size_t i = 0; i < limit; i++)
		  args[i] = parms[i].parm;
	    return args;
      }

      bool seen_named = false;
      for (size_t i = 0; i < parms.size(); i++) {
	    if (parms[i].name.nil()) {
		  if (!parms[i].parm)
			continue;

		  if (seen_named) {
		      std::cerr << parms[i].get_fileline() << ": error: "
		           << "Positional argument must preceded "
			   << "named arguments."
			   << std::endl;
		  } else if (i < args.size()) {
			args[i] = parms[i].parm;
		  }

		  continue;
	    }
	    seen_named = true;

	    bool found = false;
	    for (size_t j = 0; j < names.size(); j++) {
		  if (names[j] == parms[i].name) {
			if (args[j]) {
			      std::cerr << parms[i].get_fileline() << ": error: "
			           << "Argument `"
				   << parms[i].name
				   << "` has already been specified."
				   << std::endl;
			      des->errors++;
			} else {
			      args[j] = parms[i].parm;
			}
			found = true;
			break;
		  }
	    }
	    if (!found) {
		  std::cerr << parms[i].get_fileline() << ": error: "
		       << "No argument called `"
		       << parms[i].name << "`."
		       << std::endl;
		  des->errors++;
	    }
      }

      return args;
}

std::vector<PExpr*> map_named_args(Design *des, const NetBaseDef *def,
				   const std::vector<named_pexpr_t> &parms,
				   unsigned int off)
{
      std::vector<PExpr*> args(def->port_count() - off);

      bool seen_named = false;
      for (size_t i = 0; i < parms.size(); i++) {
	    if (parms[i].name.nil()) {
		  if (!parms[i].parm)
			continue;

		  if (seen_named) {
		      std::cerr << parms[i].get_fileline() << ": error: "
		           << "Positional argument must preceded "
			   << "named arguments."
			   << std::endl;
		  } else if (i < args.size()) {
			args[i] = parms[i].parm;
		  }

		  continue;
	    }
	    seen_named = true;

	    bool found = false;
	    for (size_t j = off; j < def->port_count(); j++) {
		  if (def->port(j)->name() == parms[i].name) {
			size_t arg_idx = j - off;
			if (args[arg_idx]) {
			      std::cerr << parms[i].get_fileline() << ": error: "
			           << "Argument `"
				   << parms[i].name
				   << "` has already been specified."
				   << std::endl;
			      des->errors++;
			} else {
			      args[arg_idx] = parms[i].parm;
			}
			found = true;
			break;
		  }
	    }
	    if (!found) {
		  std::cerr << parms[i].get_fileline() << ": error: "
		       << "No argument called `"
		       << parms[i].name << "`."
		       << std::endl;
		  des->errors++;
	    }
      }

      return args;
}

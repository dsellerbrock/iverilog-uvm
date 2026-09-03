/*
 * Copyright (c) 2015-2019 Stephen Williams (steve@icarus.com)
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

# include  "PModport.h"
# include  "PExpr.h"

static void release_tf_port_prototype_(
      PModport::tf_port_prototype_t&prototype)
{
      delete prototype.return_type;
      prototype.return_type = nullptr;
      if (prototype.ports) {
            /* Prototype PWire nodes follow the compilation-lifetime convention
             * used by ordinary subroutine ports. Defaults and the private row
             * carrier are uniquely owned here and can be reclaimed safely. */
            for (pform_tf_port_t&port : *prototype.ports) {
                  delete port.defe;
                  port.defe = nullptr;
            }
            delete prototype.ports;
            prototype.ports = nullptr;
      }
}

PModport::PModport(perm_string n)
: name_(n)
{
}

PModport::~PModport()
{
      for (auto&port : simple_ports)
            delete port.second.second;
      for (auto&prototype : import_prototypes)
            release_tf_port_prototype_(prototype.second);
      for (auto&prototype : export_prototypes)
            release_tf_port_prototype_(prototype.second);
}

void PModport::add_tf_port_prototype(bool is_import, perm_string name,
                                     bool is_function,
                                     data_type_t*return_type,
                                     std::vector<pform_tf_port_t>*ports)
{
      tf_port_prototype_t prototype(is_function, return_type, ports);
      std::map<perm_string,tf_port_prototype_t>&prototypes =
            is_import ? import_prototypes : export_prototypes;
      auto prior = prototypes.find(name);
      if (prior != prototypes.end())
            release_tf_port_prototype_(prior->second);
      prototypes[name] = prototype;
}

const PModport::tf_port_prototype_t* PModport::find_tf_port_prototype(
                                     bool is_import, perm_string name) const
{
      const std::map<perm_string,tf_port_prototype_t>&prototypes =
            is_import ? import_prototypes : export_prototypes;
      std::map<perm_string,tf_port_prototype_t>::const_iterator found =
            prototypes.find(name);
      return found == prototypes.end() ? nullptr : &found->second;
}

PNamedItem::SymbolType PModport::symbol_type() const
{
      return MODPORT;
}

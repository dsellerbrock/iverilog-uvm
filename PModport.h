#ifndef IVL_PModport_H
#define IVL_PModport_H
/*
 * Copyright (c) 2015-2025 Stephen Williams (steve@icarus.com)
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

# include  "PNamedItem.h"
# include  "PScope.h"
# include  "StringHeap.h"
# include  "netlist.h"
# include  <set>
# include  <vector>

/*
 * The PModport class represents a parsed SystemVerilog modport list.
 */
class PModport : public PNamedItem {

    public:
	// The name is a perm-allocated string. It is the simple name
	// of the modport, without any scope.
      explicit PModport(perm_string name);
      ~PModport() override;

      perm_string name() const { return name_; }

      typedef std::pair <NetNet::PortType,PExpr*> simple_port_t;
      std::map<perm_string,simple_port_t> simple_ports;

	// Task/function ports (IEEE 1800-2017/2023 25.7): `import`ed names
	// refer to interface subroutines, while `export`ed names require a
	// provider in the module connected to the interface port. Keep the
	// two sets distinct so export is never mistaken for interface-local
	// method dispatch.
      std::set<perm_string> import_ports;
      std::set<perm_string> export_ports;

      /* IEEE 1800-2017/2023 25.7: A task/function modport item may carry a
       * complete prototype. Keep that prototype separate from the interface
       * implementation declaration: its formal names control named binding,
       * and its defaults are evaluated in the prototype's declaration scope.
       * The parse-form objects have compilation lifetime, like the rest of
       * the Module/PModport tree. */
      struct tf_port_prototype_t {
            bool is_function;
            data_type_t*return_type;
            std::vector<pform_tf_port_t>*ports;

            tf_port_prototype_t(bool function_flag = false,
                                data_type_t*return_type_arg = nullptr,
                                std::vector<pform_tf_port_t>*ports_arg = nullptr)
            : is_function(function_flag), return_type(return_type_arg),
              ports(ports_arg) { }
      };

      void add_tf_port_prototype(bool is_import, perm_string name,
                                 bool is_function,
                                 data_type_t*return_type,
                                 std::vector<pform_tf_port_t>*ports);
      const tf_port_prototype_t* find_tf_port_prototype(
                                 bool is_import,
                                 perm_string name) const;

      std::map<perm_string,tf_port_prototype_t> import_prototypes;
      std::map<perm_string,tf_port_prototype_t> export_prototypes;

      // Clocking blocks exported by `modport mp(clocking cb)'. Keep these
      // names so virtual-interface event resolution can treat the modport as
      // a transparent qualification layer (`vif.mp.cb').
      std::set<perm_string> clocking_ports;

      SymbolType symbol_type() const override;

    private:
      perm_string name_;

    private: // not implemented
      PModport(const PModport&);
      PModport& operator= (const PModport&);
};

#endif /* IVL_PModport_H */

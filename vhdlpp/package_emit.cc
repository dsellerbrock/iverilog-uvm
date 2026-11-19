/*
 * Copyright (c) 2013 Stephen Williams (steve@icarus.com)
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

# include  "package.h"
# include  "subprogram.h"
# include  "ivl_assert.h"
# include  <iostream>
# include  <list>

using namespace std;

string Package::type_package_name() const
{
      string lib = library_name().str();
      return "__ivl_vhdl_types_" + to_string(lib.size()) + "_" + lib + "_" + name().str();
}

void Package::emit_type_import(ostream&fd) const
{
      if (!cur_types_.empty())
	    fd << "import " << type_package_name() << "::*;" << endl;
}

int Package::emit_type_package(ostream&fd) const
{
      if (type_package_emitted_)
	    return 0;
      type_package_emitted_ = true;

      int errors = 0;
      const auto dependencies = type_dependencies();
      for (const Package*package : dependencies)
	    errors += package->emit_type_package(fd);
      if (cur_types_.empty())
	    return errors;

      // Share each nominal type between its package subprograms and the
      // generated modules that use them.
      string scope = type_package_name();
      fd << "`ifndef " << scope << endl;
      fd << "`define " << scope << endl;
      fd << "package " << scope << ";" << endl;
      fd << "import __ivl_vhdl_std::*;" << endl;
      for (const Package*package : dependencies)
	    package->emit_type_import(fd);

      typedef_context_t typedef_ctx;
      for (const auto&entry : use_types_)
	    if (auto*type = dynamic_cast<const VTypeDef*>(entry.second))
		  if (type->declaring_package())
			typedef_ctx[type] = MARKED;
      for (const auto&entry : cur_types_)
	    if (auto*type = dynamic_cast<const VTypeDef*>(entry.second))
		  errors += type->emit_typedef(fd, typedef_ctx);

      fd << "endpackage" << endl;
      fd << "`endif" << endl;
      emit_type_import(fd);
      return errors;
}

int Package::emit_package(ostream&fd) const
{
	// Don't emit the package if there is nothing in it that SV
	// cares about.
      if (cur_types_.empty() && cur_constants_.empty() && cur_subprograms_.empty())
	    return 0;

      int errors = emit_type_package(fd);

      fd << "`ifndef package_" << name() << endl;
      fd << "`define package_" << name() << endl;

      //for (map<perm_string,struct const_t*>::const_iterator cur = use_constants_.begin()
		 //; cur != use_constants_.end() ; ++cur) {
	    //fd << "localparam \\" << cur->first << " = ";
	    //errors += cur->second->val->emit_package(fd);
	    //fd << ";" << endl;
      //}
      //for (map<perm_string,struct const_t*>::const_iterator cur = cur_constants_.begin()
		 //; cur != cur_constants_.end() ; ++cur) {
	    //fd << "localparam " << cur->first << " = ";
	    //errors += cur->second->val->emit_package(fd);
	    //fd << ";" << endl;
      //}

      fd << "package \\" << name() << " ;" << endl;
      fd << "import __ivl_vhdl_std::*;" << endl;
      emit_type_import(fd);
      for (const Package*package : type_dependencies())
	    package->emit_type_import(fd);
      for (map<perm_string,SubHeaderList>::const_iterator cur = cur_subprograms_.begin()
		 ; cur != cur_subprograms_.end() ; ++ cur) {
	    const SubHeaderList& subp_list = cur->second;

	    for(SubHeaderList::const_iterator it = subp_list.begin();
			it != subp_list.end(); ++it) {
                SubprogramHeader*header = *it;

                // Do not emit unbounded functions, we will just need fixed instances later
                if(!header->unbounded())
                    errors += header->emit_package(fd);
                else
                    fd << "/* function " << header->name()
                       << " has to be instantiated, skipping */" << endl;
            }

      }

      fd << "endpackage /* " << name() << " */" << endl;
      fd << "`endif" << endl;

      return errors;
}

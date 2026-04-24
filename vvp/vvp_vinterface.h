#ifndef IVL_vvp_vinterface_H
#define IVL_vvp_vinterface_H
/*
 * Copyright (c) 2026 Stephen Williams (steve@icarus.com)
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

# include  <string>
# include  <vector>
# include  "vpi_user.h"
# include  "vvp_object.h"
# include  "event.h"

class __vpiScope;
class class_type;
class vvp_vector4_t;

class vvp_vinterface : public vvp_object {

    public:
      vvp_vinterface(__vpiScope*scope, const class_type*defn);
      ~vvp_vinterface() override;

      void set_vec4(size_t pid, const vvp_vector4_t&val, size_t idx = 0);
      void get_vec4(size_t pid, vvp_vector4_t&val, size_t idx = 0) const;

      void set_real(size_t pid, double val);
      double get_real(size_t pid) const;

      void set_string(size_t pid, const std::string&val);
      std::string get_string(size_t pid) const;

      void set_object(size_t pid, const vvp_object_t&val, size_t idx = 0);
      void get_object(size_t pid, vvp_object_t&val, size_t idx = 0) const;

      vvp_fun_edge_sa* get_posedge_functor(size_t M);

      void shallow_copy(const vvp_object*that) override;
      vvp_object* duplicate(void) const override;

    private:
      enum slot_kind_t {
	    SLOT_NONE,
	    SLOT_SIGNAL,
	    SLOT_REAL,
	    SLOT_STRING,
	    SLOT_OBJECT
      };

      struct slot_t {
	    slot_t() : kind(SLOT_NONE), handle(0) { }
	    slot_kind_t kind;
	    vpiHandle handle;
      };

      slot_t get_slot_(size_t pid) const;
      void resolve_slots_(void);

    private:
      __vpiScope*scope_;
      const class_type*defn_;
      std::vector<slot_t>slots_;
      std::vector<vvp_fun_edge_sa*> posedge_functors_;
};

#endif /* IVL_vvp_vinterface_H */

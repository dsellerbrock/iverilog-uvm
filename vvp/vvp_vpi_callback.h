#ifndef IVL_vvp_vpi_callback_H
#define IVL_vvp_vpi_callback_H
/*
 * Copyright (c) 2009-2014 Stephen Williams (steve@icarus.com)
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
# include  "vpi_user.h"

class value_callback;
class vvp_vector2_t;

extern vpiHandle vpip_set_force_statement(vpiHandle statement);
extern void vpip_note_force_statement(struct vvp_code_s*code, vpiHandle statement);
extern vpiHandle vpip_force_statement_for(struct vvp_code_s*code);

class vvp_force_statement_context {
    public:
      explicit vvp_force_statement_context(vpiHandle statement)
          : previous_(vpip_set_force_statement(statement)) { }
      ~vvp_force_statement_context() { vpip_set_force_statement(previous_); }
    private:
      vpiHandle previous_;
};

/*
 * Things derived from vvp_vpi_callback may have callbacks
 * attached. This is how vpi callbacks are attached to the vvp
 * structure.
 *
 * Things derived from vvp_vpi_callback may also be array'ed, so it
 * includes some members that arrays use.
 */
class vvp_vpi_callback {

    public:
      vvp_vpi_callback();
      virtual ~vvp_vpi_callback();

      void attach_as_word(struct __vpiArray* arr, unsigned long addr);

      void add_vpi_callback(value_callback*);
      void add_driver_activity_callback(value_callback*);
#ifdef CHECK_WITH_VALGRIND
	/* This has only been tested at EOS. */
      void clear_all_callbacks(void);
#endif

	// Derived classes implement this method to provide a way for
	// vpi to get at the vvp value of the object.
      virtual void get_value(struct t_vpi_value*value) =0;

	// M12B-fr: fire force/release callbacks (cbForce/cbRelease)
	// attached to this object. Called from the force/release
	// execution paths; fires every attached callback whose
	// cb_data.reason matches, unconditionally (no value-change
	// test -- a re-force of the same value still reports).
      void run_force_callbacks(int reason);
      void run_force_callbacks(int reason, const vvp_vector2_t&mask);
      void run_force_callbacks(int reason, unsigned base, unsigned width);

    protected:
	// Derived classes call this method to indicate that it is
	// time to call the callback.
      void run_vpi_callbacks();
      void run_driver_activity_callbacks();

    private:
      value_callback*vpi_callbacks_;
      value_callback*driver_activity_callbacks_;
      struct __vpi_array_word*array_words_;
      void run_force_callbacks_(int reason, const vvp_vector2_t*mask,
                                bool have_range, unsigned base,
                                unsigned width);
};


#endif /* IVL_vvp_vpi_callback_H */

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

/*
 * Continuous assignment objects (IEEE 1800-2023 37.47). The behavior of
 * an assignment is the structural netlist; this object only describes
 * it. Its value is the value its driver last sent. A design that never
 * asks for a value-change callback pays nothing: the tap that records
 * the driver's output is installed when the first callback is placed.
 */

# include  "compile.h"
# include  "vpi_priv.h"
# include  "vvp_net.h"
# include  <cstdlib>
# include  <cstring>

/* vpi_user.h does not define these Annex K codes. */
static const int IEEE_vpiNetDeclAssign = 43;

/* A filter on the driver's own output that remembers the last value. */
class contassign_tap_fil : public vvp_net_fil_t {
    public:
      contassign_tap_fil() : have_vec_(false), have_real_(false), real_(0.0) { }

      prop_t filter_vec4(const vvp_vector4_t&val, vvp_vector4_t&,
			 unsigned, unsigned) override
      {
	    if (have_vec_ && vec_.size() == val.size() && vec_.eeq(val))
		  return PROP;
	    vec_ = val;
	    have_vec_ = true;
	    run_vpi_callbacks_in_boundary();
	    return PROP;
      }
      prop_t filter_vec8(const vvp_vector8_t&val, vvp_vector8_t&,
			 unsigned base, unsigned vwid) override
      {
	    vvp_vector4_t rep;
	    return filter_vec4(reduce4(val), rep, base, vwid);
      }
      prop_t filter_real(double&val) override
      {
	    if (have_real_ && real_ == val) return PROP;
	    real_ = val;
	    have_real_ = true;
	    run_vpi_callbacks_in_boundary();
	    return PROP;
      }

      void release(vvp_net_ptr_t, bool) override { }
      void release_pv(vvp_net_ptr_t, unsigned, unsigned, bool) override { }
      unsigned filter_size() const override { return vec_.size(); }
      void force_fil_vec4(const vvp_vector4_t&, const vvp_vector2_t&) override { }
      void force_fil_vec8(const vvp_vector8_t&, const vvp_vector2_t&) override { }
      void force_fil_real(double, const vvp_vector2_t&) override { }

	/* The value at installation, so the first send after it reports
	   only a real change. */
      void seed(const vvp_vector4_t&val)
      {
	    vec_ = val;
	    have_vec_ = true;
      }

      bool have_value() const { return have_vec_ || have_real_; }
      void get_value(struct t_vpi_value*vp) override
      {
	    if (have_real_)
		  vpip_real_get_value(real_, vp);
	    else
		  vpip_vec4_get_value(vec_, vec_.size(), false, vp);
      }

    private:
      bool have_vec_, have_real_;
      vvp_vector4_t vec_;
      double real_;
};

class __vpiContAssign : public __vpiHandle {
    public:
      __vpiContAssign(int flags, int str0, int str1, unsigned file_idx,
		      unsigned lineno, unsigned argc, vpiHandle*argv)
      : scope_(vpip_peek_current_scope()), argc_(argc), argv_(argv),
	driver_(0), tap_(0), flags_(flags), str0_(str0), str1_(str1),
	file_idx_(file_idx), lineno_(lineno) { }

      int get_type_code(void) const override { return vpiContAssign; }
      int vpi_get(int code) override;
      char* vpi_get_str(int code) override;
      void vpi_get_value(p_vpi_value vp) override;
      vpiHandle vpi_handle(int code) override;

      bool add_value_callback(value_callback*cb);

	/* The handles may be resolved after construction, in place. */
      vpiHandle lhs() const
      { return (flags_ & 2) && argc_ == 2 ? argv_[0] : 0; }
      vpiHandle rhs() const { return argv_[argc_-1]; }

      __vpiScope*scope_;
      unsigned argc_;
      vpiHandle*argv_;
      vvp_net_t*driver_;
      contassign_tap_fil*tap_;
      int flags_, str0_, str1_;
      unsigned file_idx_, lineno_;
};

int __vpiContAssign::vpi_get(int code)
{
      switch (code) {
	  case vpiStrength0:
	    return str0_;
	  case vpiStrength1:
	    return str1_;
	  case vpiLineNo:
	    return lineno_;
	  case vpiAutomatic:
	    return 0;
	  case vpiSize:
	    return lhs() ? ::vpi_get(vpiSize, lhs()) : ::vpi_get(vpiSize, rhs());
	  default:
	    if (code == IEEE_vpiNetDeclAssign)
		  return (flags_ & 1) != 0;
	    return vpiUndefined;
      }
}

char* __vpiContAssign::vpi_get_str(int code)
{
      if (code == vpiFile && file_idx_ < file_names.size())
	    return simple_set_rbuf_str(file_names[file_idx_]);
      return 0;
}

void __vpiContAssign::vpi_get_value(p_vpi_value vp)
{
	/* The driver's last output; before the first change after the
	   tap went in, the r-value read now. */
      if (tap_ && tap_->have_value())
	    tap_->get_value(vp);
      else
	    ::vpi_get_value(rhs(), vp);
}

vpiHandle __vpiContAssign::vpi_handle(int code)
{
      switch (code) {
	  case vpiLhs:
	    return lhs();
	  case vpiRhs:
	    return rhs();
	  case vpiParent:
	  case vpiScope:
	  case vpiModule:
	    return scope_;
	  default:
	    return 0;
      }
}

bool __vpiContAssign::add_value_callback(value_callback*cb)
{
      if (!driver_)
	    return false;
	/* A driver that is itself a signal reports through its own filter. */
      if (vvp_vpi_callback*fil = dynamic_cast<vvp_vpi_callback*>(driver_->fil)) {
	    if (!tap_ || fil != tap_) {
		  fil->add_vpi_callback(cb);
		  return true;
	    }
      }
      if (!driver_->fil) {
	    tap_ = new contassign_tap_fil;
	    s_vpi_value val;
	    val.format = vpiObjTypeVal;
	    ::vpi_get_value(rhs(), &val);
	    int wid = ::vpi_get(vpiSize, rhs());
	    if (val.format == vpiVectorVal && wid > 0)
		  tap_->seed(vec4_from_vpi_value(&val, wid));
	    driver_->fil = tap_;
      }
      tap_->add_vpi_callback(cb);
      return true;
}

bool vpip_contassign_add_callback(vpiHandle ref, value_callback*cb)
{
      __vpiContAssign*obj = dynamic_cast<__vpiContAssign*>(ref);
      return obj && obj->add_value_callback(cb);
}

void vpip_contassign_set_driver(vpiHandle ref, vvp_net_t*net)
{
      if (__vpiContAssign*obj = dynamic_cast<__vpiContAssign*>(ref))
	    obj->driver_ = net;
}

vpiHandle vpip_make_contassign(int flags, int str0, int str1,
			       unsigned file_idx, unsigned lineno,
			       unsigned argc, vpiHandle*argv)
{
      if (argc == 0) {
	    free(argv);
	    return 0;
      }
      vpiHandle obj = new __vpiContAssign(flags, str0, str1, file_idx, lineno,
					  argc, argv);
      vpip_attach_to_current_scope(obj);
      return obj;
}

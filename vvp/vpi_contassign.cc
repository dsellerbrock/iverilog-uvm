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
# include  <vector>

/* vpi_user.h does not define these Annex K codes. */
static const int IEEE_vpiNetDeclAssign = 43;
static const int IEEE_vpiContAssignBit = 128;
static const int IEEE_vpiOffset = 60;

class __vpiContAssign;

/* A scalar view of one bit of a continuous assignment's driven value. */
class __vpiContAssignBit : public __vpiHandle {
    public:
      __vpiContAssignBit(__vpiContAssign*parent, unsigned offset)
      : parent_(parent), offset_(offset) { }

      int get_type_code(void) const override { return vpiContAssign; }
      int get_vpi_type_code(void) const override { return IEEE_vpiContAssignBit; }
      int vpi_get(int code) override;
      void vpi_get_value(p_vpi_value vp) override;
      vpiHandle vpi_handle(int code) override;
      __vpiContAssign* parent() const { return parent_; }
      unsigned offset() const { return offset_; }

    private:
      __vpiContAssign*parent_;
      unsigned offset_;
};

class contassign_bit_callback : public value_callback {
    public:
      explicit contassign_bit_callback(p_cb_data data);
      bool test_value_callback_ready(void) override;

    private:
      static PLI_INT32 dispatch(p_cb_data data);
      char value_;
      PLI_INT32 (*callback_)(p_cb_data);
      const PLI_BYTE8*user_data_;
      int format_;
};

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
      vpiHandle vpi_iterate(int code) override;

      bool add_value_callback(value_callback*cb);
      value_callback* add_bit_value_callback(unsigned offset, p_cb_data data);
      vpiHandle bit(unsigned offset);

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
      std::vector<vpiHandle> bits_;
};

int __vpiContAssignBit::vpi_get(int code)
{
      switch (code) {
          case IEEE_vpiOffset:
            return offset_;
          case vpiSize:
          case vpiScalar:
            return 1;
          case vpiAutomatic:
            return 0;
          case vpiSigned:
          case vpiVector:
            return 0;
          default:
            return vpiUndefined;
      }
}

void __vpiContAssignBit::vpi_get_value(p_vpi_value vp)
{
      s_vpi_value full;
      full.format = vpiBinStrVal;
      parent_->vpi_get_value(&full);
      unsigned width = ::vpi_get(vpiSize, parent_);
      if (width == 0 || offset_ >= width) {
            vpip_vec4_get_value(vvp_vector4_t(1, BIT4_X), 1, false, vp);
            return;
      }
      vvp_vector4_t vec = vec4_from_vpi_value(&full, width);
      vvp_vector4_t bit(1, vec.value(offset_));
      vpip_vec4_get_value(bit, 1, false, vp);
}

vpiHandle __vpiContAssignBit::vpi_handle(int code)
{
      switch (code) {
          case vpiParent:
            return parent_;
          case vpiScope:
          case vpiModule:
            return parent_->vpi_handle(code);
          default:
            return 0;
      }
}

contassign_bit_callback::contassign_bit_callback(p_cb_data data)
: value_callback(data), value_(0), callback_(data->cb_rtn),
  user_data_(data->user_data), format_(data->value ? data->value->format
							  : vpiSuppressVal)
{
      s_vpi_value value;
      value.format = vpiBinStrVal;
      data->obj->vpi_get_value(&value);
      value_ = value.value.str[0];
      cb_data.cb_rtn = dispatch;
      cb_data.user_data = reinterpret_cast<const PLI_BYTE8*>(this);
	/* The driver filter normally supplies the whole assignment value. The
	   trampoline fills the caller's requested format from this bit handle. */
      cb_value.format = vpiSuppressVal;
}

PLI_INT32 contassign_bit_callback::dispatch(p_cb_data data)
{
      const contassign_bit_callback*obj =
	    reinterpret_cast<const contassign_bit_callback*>(data->user_data);
      s_vpi_value value;
      value.format = obj->format_;
      data->obj->vpi_get_value(&value);
      p_vpi_value save_value = data->value;
      const PLI_BYTE8*save_user_data = data->user_data;
      data->value = &value;
      data->user_data = obj->user_data_;
      PLI_INT32 result = obj->callback_(data);
      data->value = save_value;
      data->user_data = save_user_data;
      return result;
}

bool contassign_bit_callback::test_value_callback_ready(void)
{
      s_vpi_value value;
      value.format = vpiBinStrVal;
      cb_data.obj->vpi_get_value(&value);
      if (value_ == value.value.str[0])
            return false;
      value_ = value.value.str[0];
      return true;
}

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
	    return scope_;
	  case vpiModule:
	    return vpip_module(scope_);
	  default:
	    return 0;
      }
}

vpiHandle __vpiContAssign::bit(unsigned offset)
{
      if (bits_.empty()) {
            unsigned width = vpi_get(vpiSize);
            for (unsigned idx = 0; idx < width; ++idx)
                  bits_.push_back(new __vpiContAssignBit(this, idx));
      }
      return offset < bits_.size() ? bits_[offset] : 0;
}

vpiHandle __vpiContAssign::vpi_iterate(int code)
{
      if (code != vpiBit) return 0;
      unsigned width = vpi_get(vpiSize);
      vpiHandle*args = static_cast<vpiHandle*>(
	    calloc(width, sizeof(vpiHandle)));
      for (unsigned idx = 0; idx < width; ++idx)
            args[idx] = bit(idx);
      return vpip_make_iterator(width, args, true);
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

value_callback* __vpiContAssign::add_bit_value_callback(unsigned offset,
								 p_cb_data data)
{
      if (!driver_ || offset >= static_cast<unsigned>(vpi_get(vpiSize)))
            return 0;
      contassign_bit_callback*bit_cb = new contassign_bit_callback(data);
      if (add_value_callback(bit_cb))
            return bit_cb;
      delete bit_cb;
      return 0;
}

bool vpip_contassign_add_callback(vpiHandle ref, value_callback*cb)
{
      __vpiContAssign*obj = dynamic_cast<__vpiContAssign*>(ref);
      return obj && obj->add_value_callback(cb);
}

value_callback* vpip_contassign_add_bit_callback(vpiHandle ref, p_cb_data data)
{
      __vpiContAssignBit*bit = dynamic_cast<__vpiContAssignBit*>(ref);
      return bit ? bit->parent()->add_bit_value_callback(bit->offset(), data) : 0;
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

/*
 * Drivers and loads (IEEE 1800-2023 37.16, 37.21, 37.46). The objects that
 * drive or load a net or variable are the continuous assignments and the
 * ports connected to it; active forces and procedural assign statements
 * are not described yet. The index is built from the assignment and port
 * records on the first iteration: a design that never asks pays nothing.
 */

/* One object an assignment or port touches: a signal, or a word of an
   array, and the canonical bits of it (lo < 0 for all of them). */
struct conn_ref_ {
      vpiHandle root;
      long word;
      long lo, hi;
};

struct conn_item_ {
      vpiHandle obj;
      __vpiScope*module;
      bool drives;
      bool joins;	/* a port connecting one whole net to another */
      std::vector<conn_ref_> refs;
};

/* ponytail: each query scans the whole index (and once more per joined
   net); key it by root object if iterating over many nets gets slow. */
static std::vector<conn_item_> conn_index_;
static bool conn_built_ = false;

static long conn_int_(vpiHandle ref)
{
      s_vpi_value val;
      val.format = vpiIntVal;
      ::vpi_get_value(ref, &val);
      return val.value.integer;
}

static __vpiScope*conn_module_(__vpiScope*scope)
{
      while (scope && scope->get_type_code() != vpiModule)
	    scope = scope->scope;
      return scope;
}

/* The root object and bits one handle names; false for a constant or a
   handle the index cannot trace. */
static bool conn_ref_of_(vpiHandle ref, conn_ref_&res)
{
      if (!ref) return false;
      res.word = -1;
      res.lo = res.hi = -1;

      vpiHandle array;
      unsigned word;
      if (vpip_array_word_of(ref, array, word)) {
	    res.root = array;
	    res.word = word;
	    return true;
      }
      if (dynamic_cast<__vpiArray*>(ref)) {
	    res.root = ref;
	    return true;
      }
      if (__vpiBit::as_bit_t*as_bit = dynamic_cast<__vpiBit::as_bit_t*>(ref)) {
	    __vpiBit*bit = reinterpret_cast<__vpiBit*>(as_bit);
	    __vpiSignal*sig = bit->get_parent();
	    if (!conn_ref_of_(sig, res)) return false;
	    res.lo = res.hi = sig->value_base + bit->get_norm_index();
	    return true;
      }
      if (__vpiSignal*sig = dynamic_cast<__vpiSignal*>(ref)) {
	    __vpiSignal*root = sig;
	    while (root->packed_view_parent) root = root->packed_view_parent;
	    if (root != sig) {
		  if (!conn_ref_of_(root, res)) return false;
		  res.lo = sig->value_base;
		  res.hi = sig->value_base + sig->width() - 1;
		  return true;
	    }
	    res.root = sig;
	    return true;
      }
	/* A constant select of a whole vector (37.58, 37.59). */
      int type = ref->get_type_code();
      if (type == vpiBitSelect || type == vpiPartSelect) {
	    vpiHandle parent = ref->vpi_handle(vpiParent);
	    __vpiSignal*sig = dynamic_cast<__vpiSignal*>(parent);
	    if (!sig || !conn_ref_of_(parent, res)) return false;
	    long left, right;
	    if (type == vpiBitSelect) {
		  vpiHandle idx = ref->vpi_handle(vpiIndex);
		  if (!idx) return false;
		  left = right = conn_int_(idx);
	    } else {
		  vpiHandle lh = ref->vpi_handle(vpiLeftRange);
		  vpiHandle rh = ref->vpi_handle(vpiRightRange);
		  if (!lh || !rh) return false;
		  left = conn_int_(lh);
		  right = conn_int_(rh);
	    }
	    long msb = sig->msb.get_value(), lsb = sig->lsb.get_value();
	    long a = msb >= lsb ? left - lsb : lsb - left;
	    long b = msb >= lsb ? right - lsb : lsb - right;
	    long base = res.lo < 0 ? 0 : res.lo;
	    res.lo = base + (a < b ? a : b);
	    res.hi = base + (a < b ? b : a);
	    return true;
      }
      return false;
}

/* Every object an expression reads or writes. */
static void conn_refs_(vpiHandle ref, std::vector<conn_ref_>&out)
{
      unsigned nops;
      vpiHandle*ops;
      if (vpip_lazy_expr_operands(ref, nops, ops)) {
	    for (unsigned idx = 0; idx < nops; idx += 1)
		  conn_refs_(ops[idx], out);
	    return;
      }
      conn_ref_ res;
      if (conn_ref_of_(ref, res)) out.push_back(res);
}

static void conn_add_(vpiHandle obj, __vpiScope*module, bool drives,
		      bool joins, vpiHandle expr)
{
      conn_item_ item;
      item.obj = obj;
      item.module = module;
      item.drives = drives;
      item.joins = joins;
      conn_refs_(expr, item.refs);
      if (!item.refs.empty()) conn_index_.push_back(item);
}

static bool conn_is_net_(vpiHandle ref)
{
      return ref && dynamic_cast<__vpiSignal*>(ref)
	    && ref->get_type_code() == vpiNet;
}

static void conn_scan_scope_(__vpiScope*scope)
{
      for (vpiHandle item : scope->intern) {
	    if (__vpiScope*child = dynamic_cast<__vpiScope*>(item)) {
		  conn_scan_scope_(child);
		  continue;
	    }
	    if (__vpiContAssign*ca = dynamic_cast<__vpiContAssign*>(item)) {
		  __vpiScope*module = conn_module_(ca->scope_);
		  if (ca->lhs()) conn_add_(ca, module, true, false, ca->lhs());
		  conn_add_(ca, module, false, false, ca->rhs());
		  continue;
	    }
	    vpiPortInfo*port = dynamic_cast<vpiPortInfo*>(item);
	    if (!port) continue;
	    int dir = port->get_direction();
	    bool in = dir == vpiInput || dir == vpiInout;
	    bool out = dir == vpiOutput || dir == vpiInout;
	    vpiHandle low = port->vpi_handle(vpiLowConn);
	    vpiHandle high = port->vpi_handle(vpiHighConn);
	    bool joins = conn_is_net_(low) && conn_is_net_(high);
	      /* 37.16 detail 17: seen from a net inside the module, an input
		 port drives it and an output port loads it. */
	    __vpiScope*module = conn_module_(scope);
	    if (low && in) conn_add_(port, module, true, joins, low);
	    if (low && out) conn_add_(port, module, false, joins, low);
	      /* Seen from the instantiating module the roles swap: the
		 actual of an input port is a load (37.46 detail 1). */
	    __vpiScope*outer = conn_module_(scope->scope);
	    if (high && in) conn_add_(port, outer, false, joins, high);
	    if (high && out) conn_add_(port, outer, true, joins, high);
      }
}

static void conn_build_(void)
{
      if (conn_built_) return;
      conn_built_ = true;
      vpiHandle*table;
      unsigned ntable;
      vpip_make_root_iterator(table, ntable);
      for (unsigned idx = 0; idx < ntable; idx += 1)
	    if (__vpiScope*scope = dynamic_cast<__vpiScope*>(table[idx]))
		  conn_scan_scope_(scope);
}

static bool conn_overlap_(const conn_ref_&a, const conn_ref_&b)
{
      if (a.root != b.root) return false;
      if (a.word >= 0 && b.word >= 0 && a.word != b.word) return false;
      if (a.lo < 0 || b.lo < 0) return true;
      return a.lo <= b.hi && b.lo <= a.hi;
}

static bool conn_touches_(const conn_item_&item, const conn_ref_&ref)
{
      for (const conn_ref_&cur : item.refs)
	    if (conn_overlap_(cur, ref)) return true;
      return false;
}

static __vpiScope*conn_root_module_(vpiHandle root)
{
      if (__vpiArrayBase*array = dynamic_cast<__vpiArrayBase*>(root))
	    return conn_module_(array->get_scope());
      return conn_module_(dynamic_cast<__vpiScope*>(::vpi_handle(vpiScope, root)));
}

vpiHandle vpip_conn_iterate(int code, vpiHandle ref)
{
      bool local = code == vpiLocalDriver || code == vpiLocalLoad;
      bool drives = code == vpiDriver || code == vpiLocalDriver;
      if (!local && code != vpiDriver && code != vpiLoad) return 0;
      conn_ref_ query;
      if (!conn_ref_of_(ref, query)) return 0;
	/* 37.21 defines only vpiDriver and vpiLoad for variables. */
      __vpiArray*array = dynamic_cast<__vpiArray*>(query.root);
      bool net = array ? array->nets != 0
	    : query.root->get_type_code() == vpiNet;
      if (local && !net) return 0;
      conn_build_();

	/* The nets that are one simulated net with this one: whole nets
	   joined through ports (37.16 details 4 and 22). Local iteration
	   stays inside the net's own module instance. */
      std::vector<conn_ref_> nets(1, query);
      for (size_t cur = 0; !local && cur < nets.size(); cur += 1)
	    for (const conn_item_&item : conn_index_) {
		  if (!item.joins || !conn_touches_(item, nets[cur])) continue;
		  vpiHandle low = item.obj->vpi_handle(vpiLowConn);
		  vpiHandle high = item.obj->vpi_handle(vpiHighConn);
		  for (vpiHandle side : {low, high}) {
			conn_ref_ other;
			bool seen = false;
			if (!conn_ref_of_(side, other)) continue;
			other.lo = nets[cur].lo;
			other.hi = nets[cur].hi;
			for (const conn_ref_&have : nets)
			      if (have.root == other.root) seen = true;
			if (!seen) nets.push_back(other);
		  }
	    }

      __vpiScope*module = conn_root_module_(query.root);
      std::vector<vpiHandle> found;
      for (const conn_item_&item : conn_index_) {
	    if (item.drives != drives) continue;
	    if (local ? item.module != module : item.joins) continue;
	    bool hit = false;
	    for (const conn_ref_&cur : nets)
		  if (conn_touches_(item, cur)) hit = true;
	    if (!hit) continue;
	    bool dup = false;
	    for (vpiHandle have : found)
		  if (have == item.obj) dup = true;
	    if (!dup) found.push_back(item.obj);
      }
      if (found.empty()) return 0;
      vpiHandle*args = static_cast<vpiHandle*>(
	    calloc(found.size(), sizeof(vpiHandle)));
      for (size_t idx = 0; idx < found.size(); idx += 1)
	    args[idx] = found[idx];
      return vpip_make_iterator(found.size(), args, true);
}

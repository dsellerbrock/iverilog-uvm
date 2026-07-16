#ifndef IVL_PExpr_H
#define IVL_PExpr_H
/*
 * Copyright (c) 1998-2025 Stephen Williams <steve@icarus.com>
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

# include  <string>
# include  <vector>
# include  <valarray>
# include  <memory>
# include  "netlist.h"
# include  "verinum.h"
# include  "LineInfo.h"
# include  "pform_types.h"

class Design;
class Module;
class LexicalScope;
class NetNet;
class NetExpr;
class NetScope;
class PPackage;
struct symbol_search_results;

/*
 * The PExpr class hierarchy supports the description of
 * expressions. The parser can generate expression objects from the
 * source, possibly reducing things that it knows how to reduce.
 */

class PExpr : public LineInfo {

    public:
	// Mode values used by test_width() (see below for description).
      enum width_mode_t { SIZED, UNSIZED, EXPAND, LOSSLESS, UPSIZE };

        // Flag values that can be passed to elaborate_expr().
      static const unsigned NO_FLAGS     = 0x0;
      static const unsigned NEED_CONST   = 0x1;
      static const unsigned SYS_TASK_ARG = 0x2;
      static const unsigned ANNOTATABLE  = 0x4;

	// Convert width mode to human-readable form.
      static const char*width_mode_name(width_mode_t mode);

      PExpr();
      virtual ~PExpr() override;

      virtual void dump(std::ostream&) const;

        // This method tests whether the expression contains any identifiers
        // that have not been previously declared in the specified scope or
        // in any containing scope. Any such identifiers are added to the
        // specified scope as scalar nets of the specified type.
        //
        // This operation must be performed by the parser, to ensure that
        // subsequent declarations do not affect the decision to create an
        // implicit net.
      virtual void declare_implicit_nets(LexicalScope*scope, NetNet::Type type);

        // This method tests whether the expression contains any
        // references to automatically allocated variables.
      virtual bool has_aa_term(Design*des, NetScope*scope) const;

	// SystemVerilog bind directives (IEEE 1800-2017 23.11) insert
	// their port/parameter expressions into the TARGET module, where
	// they must resolve as if written at the end of the target's
	// body. This method recursively resets identifier lexical
	// positions to end-of-scope so the declaration-before-use check
	// does not reject target names declared "after" the directive's
	// own parse position (e.g. binds in a different source file).
      virtual void reloc_lexical_pos_bind();

	// This method tests the type and width that the expression wants
	// to be. It should be called before elaborating an expression to
	// figure out the type and width of the expression. It also figures
	// out the minimum width that can be used to evaluate the expression
	// without changing the result. This allows the expression width to
	// be pruned when not all bits of the result are used.
	//
	// Normally mode should be initialized to SIZED before starting to
	// test the width of an expression. In SIZED mode the expression
	// width will be calculated strictly according to the IEEE standard
	// rules for expression width.
	//
	// If the expression is found to contain an unsized literal number
	// and gn_strict_expr_width_flag is set, mode will be changed to
	// UNSIZED. In UNSIZED mode the expression width will be calculated
	// exactly as in SIZED mode - the change in mode simply flags that
	// the expression contains an unsized numbers.
	//
	// If the expression is found to contain an unsized literal number
	// and gn_strict_expr_width_flag is not set, mode will be changed
	// to LOSSLESS. In LOSSLESS mode the expression width will be
	// calculated as the minimum width necessary to avoid arithmetic
	// overflow or underflow.
	//
	// Once in LOSSLESS mode, if the expression is found to contain
	// an operation that coerces a vector operand to a different type
	// (signed <-> unsigned), mode will be changed to UPSIZE. UPSIZE
	// mode is the same as LOSSLESS, except that the final expression
	// width will be forced to be at least integer_width. This is
	// necessary to ensure compatibility with the IEEE standard, which
	// requires unsized numbers to be treated as having the same width
	// as an integer. The lossless width calculation is inadequate in
	// this case because coercing an operand to a different type means
	// that the expression no longer obeys the normal rules of arithmetic.
	//
	// If mode is initialized to EXPAND instead of SIZED, the expression
	// width will be calculated as the minimum width necessary to avoid
	// arithmetic overflow or underflow, even if it contains no unsized
	// literals. mode will be changed LOSSLESS or UPSIZE as described
	// above. This supports a non-standard mode of expression width
	// calculation.
	//
	// When the final value of mode is UPSIZE, the width returned by
	// this method is the calculated lossless width, but the width
	// returned by a subsequent call to the expr_width method will be
	// the final expression width.
      virtual unsigned test_width(Design*des, NetScope*scope,
				  width_mode_t&mode);

	// After the test_width method is complete, these methods
	// return valid results.
      ivl_variable_type_t expr_type() const { return expr_type_; }
      unsigned expr_width() const           { return expr_width_; }
      unsigned min_width() const            { return min_width_; }
      bool has_sign() const                 { return signed_flag_; }

        // This method allows the expression type (signed/unsigned)
        // to be propagated down to any context-dependant operands.
      void cast_signed(bool flag) { signed_flag_ = flag; }

	// This is the more generic form of the elaborate_expr method
	// below. The plan is to replace the simpler elaborate_expr
	// method with this version, which can handle more advanced
	// types. But for now, this is only implemented in special cases.
      virtual NetExpr*elaborate_expr(Design*des, NetScope*scope,
				     ivl_type_t type, unsigned flags) const;

	// Procedural elaboration of the expression. The expr_width is
	// the required width of the expression.
	//
	// The sys_task_arg flag is true if expressions are allowed to
	// be incomplete.
      virtual NetExpr*elaborate_expr(Design*des, NetScope*scope,
				     unsigned expr_wid,
                                     unsigned flags) const;

	// This method elaborates the expression as gates, but
	// restricted for use as l-values of continuous assignments.
      virtual NetNet* elaborate_lnet(Design*des, NetScope*scope,
                                     bool var_allowed_in_sv) const;

	// This is similar to elaborate_lnet, except that the
	// expression is evaluated to be bi-directional. This is
	// useful for arguments to inout ports of module instances and
	// ports of tran primitives.
      virtual NetNet* elaborate_bi_net(Design*des, NetScope*scope,
                                       bool var_allowed_in_sv) const;

	// Expressions that can be in the l-value of procedural
	// assignments can be elaborated with this method. If the
	// is_cassign or is_force flags are true, then the set of
	// valid l-value types is slightly modified to accommodate
	// the Verilog procedural continuous assignment statements.
      virtual NetAssign_* elaborate_lval(Design*des,
					 NetScope*scope,
					 bool is_cassign,
					 bool is_force,
					 bool is_init = false) const;

	// This method returns true if the expression represents a
        // structural net that can have multiple drivers. This is
        // used to test whether an input port connection can be
        // collapsed to a single wire.
      virtual bool is_collapsible_net(Design*des, NetScope*scope,
                                      NetNet::PortType port_type) const;

    protected:
      unsigned fix_width_(width_mode_t mode);

	// The derived class test_width methods should fill these in.
      ivl_variable_type_t expr_type_;
      unsigned expr_width_;
      unsigned min_width_;
      bool signed_flag_;

    private: // not implemented
      PExpr(const PExpr&);
      PExpr& operator= (const PExpr&);
};

std::ostream& operator << (std::ostream&, const PExpr&);

class PEAssignPattern : public PExpr {
    public:
      explicit PEAssignPattern();
      explicit PEAssignPattern(const std::list<PExpr*>&p);
      explicit PEAssignPattern(const std::list<std::pair<perm_string,PExpr*>>&named);
      // Replication form: '{N{elem0, elem1, ...}} — parms_ holds the base elements,
      // replication_ holds the count expression.
      explicit PEAssignPattern(PExpr*replication, const std::list<PExpr*>&p);
      ~PEAssignPattern() override;

      void dump(std::ostream&) const override;

      virtual unsigned test_width(Design*des, NetScope*scope, width_mode_t&mode) override;
      virtual NetExpr*elaborate_expr(Design*des, NetScope*scope,
				     ivl_type_t type, unsigned flags) const override;

      virtual NetExpr*elaborate_expr(Design*des, NetScope*scope,
				     unsigned expr_wid,
                                     unsigned flags) const override;
      const std::vector<PExpr*>& parms() const { return parms_; }
      const std::vector<perm_string>& parm_names() const { return parm_names_; }
      PExpr* replication() const { return replication_; }
    private:
      NetExpr* elaborate_expr_packed_(Design *des, NetScope *scope,
				      ivl_variable_type_t base_type,
				      unsigned int width,
				      const netranges_t &dims,
				      unsigned int cur_dim,
				      bool need_const) const;
      NetExpr* elaborate_expr_struct_(Design *des, NetScope *scope,
				      const netstruct_t *struct_type,
				      bool need_const) const;
      NetExpr* elaborate_expr_array_(Design *des, NetScope *scope,
				     const netarray_t *array_type,
				     bool need_const, bool up) const;
      NetExpr* elaborate_expr_uarray_(Design *des, NetScope *scope,
				      const netuarray_t *uarray_type,
				      const netranges_t &dims,
				      unsigned int cur_dim,
				      bool need_const) const;

    private:
      std::vector<PExpr*>parms_;
      std::vector<perm_string>parm_names_; // non-empty → named member pattern
      PExpr* replication_ = nullptr;       // non-null for '{N{...}} form
};

class PEConcat : public PExpr {

    public:
      explicit PEConcat(const std::list<PExpr*>&p, PExpr*r =0);
      ~PEConcat() override;

      virtual void reloc_lexical_pos_bind() override;

      bool is_empty_concat() const { return parms_.empty() && repeat_ == 0; }

      // Read-only operand access for the streaming-concatenation
      // lowering (a multi-operand stream is parsed as a PEConcat).
      const std::vector<PExpr*>& stream_parms() const { return parms_; }
      bool has_repeat() const { return repeat_ != 0; }

      virtual void dump(std::ostream&) const override;

      virtual void declare_implicit_nets(LexicalScope*scope, NetNet::Type type) override;

      virtual bool has_aa_term(Design*des, NetScope*scope) const override;

      virtual unsigned test_width(Design*des, NetScope*scope,
				  width_mode_t&mode) override;

      virtual NetNet* elaborate_lnet(Design*des, NetScope*scope,
                                     bool var_allowed_in_sv) const override;
      virtual NetNet* elaborate_bi_net(Design*des, NetScope*scope,
                                       bool var_allowed_in_sv) const override;

      virtual NetExpr*elaborate_expr(Design*des, NetScope*scope,
				     ivl_type_t type, unsigned flags) const override;

      virtual NetExpr*elaborate_expr(Design*des, NetScope*,
				     unsigned expr_wid,
                                     unsigned flags) const override;
      virtual NetAssign_* elaborate_lval(Design*des,
					 NetScope*scope,
					 bool is_cassign,
					 bool is_force,
					 bool is_init = false) const override;
      virtual bool is_collapsible_net(Design*des, NetScope*scope,
                                      NetNet::PortType port_type) const override;
    private:
      NetNet* elaborate_lnet_common_(Design*des, NetScope*scope,
				     bool bidirectional_flag,
				     bool var_allowed_in_sv) const;
    private:
      std::vector<PExpr*>parms_;
      std::valarray<width_mode_t>width_modes_;

      PExpr*repeat_;
      NetScope*tested_scope_;
      unsigned repeat_count_;
      // Phase 63b: when a string concat has a runtime-variable
      // repeat count, test_width saves the elaborated runtime
      // expression here so the elaborate_expr stage can plumb it
      // through to NetEConcat::set_repeat_expr without re-eval.
      // mutable because elaborate_expr is a const member but needs
      // to take ownership.
      mutable NetExpr*runtime_repeat_ = nullptr;
};

/*
 * Event expressions are expressions that can be combined with the
 * event "or" operator. These include "posedge foo" and similar, and
 * also include named events. "edge" events are associated with an
 * expression, whereas named events simply have a name, which
 * represents an event variable.
 */
class PEEvent : public PExpr {

    public:
      enum edge_t {ANYEDGE, POSEDGE, NEGEDGE, EDGE, POSITIVE};

	// Use this constructor to create events based on edges or levels.
      PEEvent(edge_t t, PExpr*e);

      ~PEEvent() override;

      edge_t type() const;
      PExpr* expr() const;

      virtual void dump(std::ostream&) const override;

      virtual bool has_aa_term(Design*des, NetScope*scope) const override;

    private:
      edge_t type_;
      PExpr *expr_;
};

/*
 * This holds a floating point constant in the source.
 */
class PEFNumber : public PExpr {

    public:
      explicit PEFNumber(verireal*vp);
      ~PEFNumber() override;

      const verireal& value() const;

      virtual unsigned test_width(Design*des, NetScope*scope,
				  width_mode_t&mode) override;
      virtual NetExpr*elaborate_expr(Design*des, NetScope*,
				     ivl_type_t type, unsigned flags) const override;
      virtual NetExpr*elaborate_expr(Design*des, NetScope*,
				     unsigned expr_wid,
                                     unsigned flags) const override;

      virtual void dump(std::ostream&) const override;

    private:
      verireal*value_;
};

class PEIdent : public PExpr {

    public:
      explicit PEIdent(perm_string, unsigned lexical_pos, bool no_implicit_sig=false);
      explicit PEIdent(PPackage*pkg, const pform_name_t&name, unsigned lexical_pos);
      explicit PEIdent(const pform_name_t&, unsigned lexical_pos);
      ~PEIdent() override;

	// Add another name to the string of hierarchy that is the
	// current identifier.
      void append_name(perm_string);

      virtual void dump(std::ostream&) const override;

      virtual void declare_implicit_nets(LexicalScope*scope, NetNet::Type type) override;

      virtual bool has_aa_term(Design*des, NetScope*scope) const override;

      virtual unsigned test_width(Design*des, NetScope*scope,
				  width_mode_t&mode) override;

	// Identifiers are allowed (with restrictions) is assign l-values.
      virtual NetNet* elaborate_lnet(Design*des, NetScope*scope, bool var_allowed_in_sv) const override;

      virtual NetNet* elaborate_bi_net(Design*des, NetScope*scope, bool var_allowed_in_sv) const override;

	// Identifiers are also allowed as procedural assignment l-values.
      virtual NetAssign_* elaborate_lval(Design*des,
					 NetScope*scope,
					 bool is_cassign,
					 bool is_force,
					 bool is_init = false) const override;

      virtual NetExpr*elaborate_expr(Design*des, NetScope*scope,
				     ivl_type_t type, unsigned flags) const override;
      virtual NetExpr*elaborate_expr(Design*des, NetScope*,
				     unsigned expr_wid,
                                     unsigned flags) const override;

	// Elaborate the PEIdent as a port to a module. This method
	// only applies to Ident expressions.
      NetNet* elaborate_subport(Design*des, NetScope*sc) const;

	// Elaborate the identifier allowing for unpacked arrays. This
	// method only applies to Ident expressions because only Ident
	// expressions can can be unpacked arrays.
      NetNet* elaborate_unpacked_net(Design*des, NetScope*sc) const;

      virtual bool is_collapsible_net(Design*des, NetScope*scope,
                                      NetNet::PortType port_type) const override;

      const pform_scoped_name_t& path() const { return path_; }

      unsigned lexical_pos() const { return lexical_pos_; }

      virtual void reloc_lexical_pos_bind() override;

      // I5 (Phase 62m): when path was parsed from `Class#(args)::var`,
      // these are the leading type arguments needed to identify the
      // parameterized-class specialization.  Without this, the
      // elaborator falls back to the unspecialized class, so static
      // property accesses target the base instead of the specialization.
      void set_leading_type_args(struct parmvalue_t*type_args)
            { leading_type_args_ = type_args; }
      const struct parmvalue_t* leading_type_args() const
            { return leading_type_args_; }

    private:
      pform_scoped_name_t path_;
      unsigned lexical_pos_;
      bool no_implicit_sig_;
      struct parmvalue_t* leading_type_args_ = 0;

    private:
	// Common functions to calculate parts of part/bit
	// selects. These methods return true if the expressions
	// elaborate/calculate, or false if there is some sort of
	// source error.

      bool calculate_bits_(Design*, NetScope*, long&msb, bool&defined) const;

	// The calculate_parts_ method calculates the range
	// expressions of a part select for the current object. The
	// part select expressions are elaborated and evaluated, and
	// the values written to the msb/lsb arguments. If there are
	// invalid bits (xz) in either expression, then the defined
	// flag is set to *false*.
      void calculate_parts_(Design*, NetScope*, long&msb, long&lsb, bool&defined) const;
      NetExpr* calculate_up_do_base_(Design*, NetScope*, bool need_const) const;

      bool calculate_up_do_width_(Design*, NetScope*, unsigned long&wid) const;

	// Evaluate the prefix indices. All but the final index in a
	// chain of indices must be a single value and must evaluate
	// to constants at compile time. For example:
	//    [x]          - OK
	//    [1][2][x]    - OK
	//    [1][x:y]     - OK
	//    [2:0][x]     - BAD
	//    [y][x]       - BAD
	// Leave the last index for special handling.
      bool calculate_packed_indices_(Design*des, NetScope*scope, const NetNet*net,
				     std::list<long>&prefix_indices) const;

    private:

      void report_mixed_assignment_conflict_(const char*category) const;

      NetAssign_ *elaborate_lval_array_(Design *des, NetScope *scope,
				        bool is_force, NetNet *reg) const;
      NetAssign_ *elaborate_lval_var_(Design *des, NetScope *scope,
				      bool is_force, bool is_cassign,
				      NetNet *reg, ivl_type_t data_type,
				      pform_name_t tail_path,
				      const std::list<index_component_t>&base_index) const;
      NetAssign_*elaborate_lval_net_word_(Design*, NetScope*, NetNet*,
					  bool need_const_idx, bool is_force) const;
      bool elaborate_lval_net_bit_(Design*, NetScope*, NetAssign_*,
				   bool need_const_idx, bool is_force) const;
      bool elaborate_lval_net_part_(Design*, NetScope*, NetAssign_*,
				    bool is_force) const;
      bool elaborate_lval_net_idx_(Design*, NetScope*, NetAssign_*,
                                   index_component_t::ctype_t,
				   bool need_const_idx, bool is_force) const;
      NetAssign_*elaborate_lval_net_class_member_(Design*, NetScope*,
						   ivl_type_t root_type,
						   NetNet*,
						   pform_name_t,
						   const std::list<index_component_t>&base_index) const;
      bool elaborate_lval_net_packed_member_(Design*, NetScope*,
					     NetAssign_*,
					     pform_name_t member_path, bool is_force) const;
      bool elaborate_lval_darray_bit_(Design*, NetScope*,
				      NetAssign_*, bool is_force) const;

    private:
      NetExpr* elaborate_expr_(Design *des, NetScope *scope,
			      unsigned expr_wid, unsigned flags) const;

      NetExpr*elaborate_expr_param_or_specparam_(Design*des,
						 NetScope*scope,
						 const NetExpr*par,
						 NetScope*found_in,
						 ivl_type_t par_type,
						 unsigned expr_wid,
						 unsigned flags) const;
      NetExpr*elaborate_expr_param_(Design*des,
				    NetScope*scope,
				    const NetExpr*par,
				    const NetScope*found_in,
				    ivl_type_t par_type,
				    unsigned expr_wid,
                                    unsigned flags) const;
      NetExpr*elaborate_expr_param_bit_(Design*des,
					NetScope*scope,
					const NetExpr*par,
					const NetScope*found_in,
					ivl_type_t par_type,
                                        bool need_const) const;
      NetExpr*elaborate_expr_param_part_(Design*des,
					 NetScope*scope,
					 const NetExpr*par,
					 const NetScope*found_in,
					 ivl_type_t par_type,
				         unsigned expr_wid) const;
      NetExpr*elaborate_expr_param_idx_up_(Design*des,
					   NetScope*scope,
					   const NetExpr*par,
					   const NetScope*found_in,
					   ivl_type_t par_type,
                                           bool need_const) const;
      NetExpr*elaborate_expr_param_idx_do_(Design*des,
					   NetScope*scope,
					   const NetExpr*par,
					   const NetScope*found_in,
					   ivl_type_t par_type,
                                           bool need_const) const;
      NetExpr*elaborate_expr_net(Design*des,
				 NetScope*scope,
				 NetNet*net,
				 NetScope*found,
				 unsigned expr_wid,
				 unsigned flags) const;
      NetExpr*elaborate_expr_net_word_(Design*des,
				       NetScope*scope,
				       NetNet*net,
				       NetScope*found,
				       unsigned expr_wid,
				       unsigned flags) const;
      NetExpr*elaborate_expr_net_part_(Design*des,
				       NetScope*scope,
				       NetESignal*net,
				       NetScope*found,
				       unsigned expr_wid) const;
      NetExpr*elaborate_expr_net_idx_up_(Design*des,
				         NetScope*scope,
				         NetESignal*net,
				         NetScope*found,
                                         bool need_const) const;
      NetExpr*elaborate_expr_net_idx_do_(Design*des,
				         NetScope*scope,
				         NetESignal*net,
				         NetScope*found,
                                         bool need_const) const;
      NetExpr*elaborate_expr_net_bit_(Design*des,
				      NetScope*scope,
				      NetESignal*net,
				      NetScope*found,
                                      bool need_const) const;
      NetExpr*elaborate_expr_net_bit_last_(Design*des,
					   NetScope*scope,
					   NetESignal*net,
					   NetScope*found,
					   bool need_const) const;

      NetExpr *elaborate_expr_class_field_(Design*des, NetScope*scope,
					   const symbol_search_results &sr,
					   unsigned expr_wid,
					   unsigned flags) const;

      unsigned test_width_parameter_(const NetExpr *par, width_mode_t&mode);

      ivl_type_t resolve_type_(Design *des, const symbol_search_results &sr,
			       unsigned int &index_depth) const;

    private:
      NetNet* elaborate_lnet_common_(Design*des, NetScope*scope,
				     bool bidirectional_flag,
				     bool var_allowed_in_sv) const;


      bool eval_part_select_(Design*des, NetScope*scope, const NetNet*sig,
			     long&midx, long&lidx) const;
};

class PEMemberAccess : public PExpr {

    public:
      explicit PEMemberAccess(PExpr*base, perm_string member_name);
      ~PEMemberAccess() override;

      virtual void dump(std::ostream&) const override;

      virtual void declare_implicit_nets(LexicalScope*scope, NetNet::Type type) override;

      virtual bool has_aa_term(Design*des, NetScope*scope) const override;

      virtual unsigned test_width(Design*des, NetScope*scope,
				  width_mode_t&mode) override;

      virtual NetExpr*elaborate_expr(Design*des, NetScope*scope,
				     ivl_type_t type, unsigned flags) const override;
      virtual NetExpr*elaborate_expr(Design*des, NetScope*scope,
				     unsigned expr_wid,
				     unsigned flags) const override;

    private:
      PExpr*base_;
      perm_string member_name_;
};

class PENewArray : public PExpr {

    public:
      explicit PENewArray (PExpr*s, PExpr*i);
      ~PENewArray() override;

      virtual void dump(std::ostream&) const override;
      virtual unsigned test_width(Design*des, NetScope*scope,
				  width_mode_t&mode) override;
      virtual NetExpr*elaborate_expr(Design*des, NetScope*scope,
				     ivl_type_t type, unsigned flags) const override;
      virtual NetExpr*elaborate_expr(Design*des, NetScope*,
				     unsigned expr_wid,
                                     unsigned flags) const override;

    private:
      PExpr*size_;
      PExpr*init_;
};

class PENewClass : public PExpr {

    public:
	// New without (or with default) constructor
      explicit PENewClass ();
	// New with constructor arguments
      explicit PENewClass (const std::list<named_pexpr_t> &p,
			   data_type_t *class_type = nullptr);

      ~PENewClass() override;

      virtual void dump(std::ostream&) const override;
	// Class objects don't have a useful width, but the expression
	// is IVL_VT_CLASS.
      virtual unsigned test_width(Design*des, NetScope*scope,
				  width_mode_t&mode) override;
	// Note that class (new) expressions only appear in context
	// that uses this form of the elaborate_expr method. In fact,
	// the type argument is going to be a netclass_t object.
      virtual NetExpr*elaborate_expr(Design*des, NetScope*scope,
				     ivl_type_t type, unsigned flags) const override;

    private:
      NetExpr* elaborate_expr_constructor_(Design*des, NetScope*scope,
					   const netclass_t*ctype,
					   NetExpr*obj, unsigned flags) const;

    private:
      std::vector<named_pexpr_t> parms_;
      data_type_t *class_type_;
};

class PENewCopy : public PExpr {
    public:
      explicit PENewCopy(PExpr*src);
      ~PENewCopy() override;

      virtual void dump(std::ostream&) const override;
	// Class objects don't have a useful width, but the expression
	// is IVL_VT_CLASS.
      virtual unsigned test_width(Design*des, NetScope*scope,
				  width_mode_t&mode) override;
	// Note that class (new) expressions only appear in context
	// that uses this form of the elaborate_expr method. In fact,
	// the type argument is going to be a netclass_t object.
      virtual NetExpr*elaborate_expr(Design*des, NetScope*scope,
				     ivl_type_t type, unsigned flags) const override;

    private:
      PExpr*src_;
};

class PENull : public PExpr {
    public:
      explicit PENull();
      ~PENull() override;

      virtual void dump(std::ostream&) const override;
      virtual unsigned test_width(Design*des, NetScope*scope,
				  width_mode_t&mode) override;
      virtual NetExpr*elaborate_expr(Design*des, NetScope*scope,
				     ivl_type_t type, unsigned flags) const override;
      virtual NetExpr*elaborate_expr(Design*des, NetScope*,
				     unsigned expr_wid,
                                     unsigned flags) const override;
};

/*
 * Placeholder used only in unpacked-dimension declarations to preserve
 * associative-array index types through parsing.
 */
class PEAssocType : public PExpr {
    public:
      explicit PEAssocType(data_type_t*index_type);
      ~PEAssocType() override;

      inline data_type_t* index_type() { return index_type_.get(); }
      inline const data_type_t* index_type() const { return index_type_.get(); }

      virtual unsigned test_width(Design*des, NetScope*scope,
				  width_mode_t&mode) override;
      virtual NetExpr*elaborate_expr(Design*des, NetScope*scope,
				     ivl_type_t type, unsigned flags) const override;
      virtual NetExpr*elaborate_expr(Design*des, NetScope*,
				     unsigned expr_wid,
                                     unsigned flags) const override;

    private:
      std::unique_ptr<data_type_t> index_type_;
};

class PENumber : public PExpr {

    public:
      explicit PENumber(verinum*vp);
      ~PENumber() override;

      const verinum& value() const;

      virtual void dump(std::ostream&) const override;
      virtual unsigned test_width(Design*des, NetScope*scope,
				  width_mode_t&mode) override;

      virtual NetExpr  *elaborate_expr(Design*des, NetScope*scope,
				       ivl_type_t type, unsigned flags) const override;
      virtual NetEConst*elaborate_expr(Design*des, NetScope*,
				       unsigned expr_wid, unsigned) const override;
      virtual NetAssign_* elaborate_lval(Design*des,
					 NetScope*scope,
					 bool is_cassign,
					 bool is_force,
					 bool is_init = false) const override;

    private:
      verinum*const value_;
};

/*
 * This represents a string constant in an expression.
 *
 * The s parameter to the PEString constructor is a C string that this
 * class instance will take for its own. The caller should not delete
 * the string, the destructor will do it.
 */
class PEString : public PExpr {

    public:
      explicit PEString(char*s);
      ~PEString() override;

      const std::string& value() const;
      const verinum& parsed_value() const;
      virtual void dump(std::ostream&) const override;

      virtual unsigned test_width(Design*des, NetScope*scope,
				  width_mode_t&mode) override;

      virtual NetEConst*elaborate_expr(Design*des, NetScope*scope,
				       ivl_type_t type, unsigned flags) const override;

      virtual NetEConst*elaborate_expr(Design*des, NetScope*,
				       unsigned expr_wid, unsigned) const override;

    private:
      std::string text_;
      unsigned text_width_;
      bool text_width_valid_;
      mutable verinum parsed_value_cache_;
      mutable bool parsed_value_valid_;
};

class PETypename : public PExpr {
    public:
      explicit PETypename(data_type_t*data_type);
      ~PETypename() override;

      virtual void dump(std::ostream&) const override;
	      virtual unsigned test_width(Design*des, NetScope*scope,
					  width_mode_t&mode) override;
	      virtual NetExpr*elaborate_expr(Design*des, NetScope*scope,
					     ivl_type_t type, unsigned flags) const override;
	      virtual NetExpr*elaborate_expr(Design*des, NetScope*scope,
					     unsigned expr_wid, unsigned flags) const override;

	      inline data_type_t* get_type() const { return data_type_; }

    private:
      data_type_t*data_type_;
};

class PEUnary : public PExpr {

    public:
      explicit PEUnary(char op, PExpr*ex);
      ~PEUnary() override;

      virtual void dump(std::ostream&out) const override;

      virtual void declare_implicit_nets(LexicalScope*scope, NetNet::Type type) override;

      virtual bool has_aa_term(Design*des, NetScope*scope) const override;

      virtual void reloc_lexical_pos_bind() override;

      virtual unsigned test_width(Design*des, NetScope*scope,
				  width_mode_t&mode) override;

      virtual NetExpr*elaborate_expr(Design*des, NetScope*,
				     unsigned expr_wid,
                                     unsigned flags) const override;

    public:
      inline char get_op() const { return op_; }
      inline PExpr*get_expr() const { return expr_; }

    private:
      NetExpr* elaborate_expr_bits_(NetExpr*operand, unsigned expr_wid) const;

    private:
      char op_;
      PExpr*expr_;
};

class PEBinary : public PExpr {

    public:
      explicit PEBinary(char op, PExpr*l, PExpr*r);
      ~PEBinary() override;

      virtual void dump(std::ostream&out) const override;

      virtual void declare_implicit_nets(LexicalScope*scope, NetNet::Type type) override;

      virtual bool has_aa_term(Design*des, NetScope*scope) const override;

      virtual void reloc_lexical_pos_bind() override;

      virtual unsigned test_width(Design*des, NetScope*scope,
				  width_mode_t&mode) override;

      virtual NetExpr*elaborate_expr(Design*des, NetScope*,
				     unsigned expr_wid,
                                     unsigned flags) const override;

      inline char   get_op()    const { return op_; }
      inline PExpr* get_left()  const { return left_; }
      inline PExpr* get_right() const { return right_; }

    protected:
      char op_;
      PExpr*left_;
      PExpr*right_;

      NetExpr*elaborate_expr_base_(Design*, NetExpr*lp, NetExpr*rp,
				   unsigned expr_wid) const;
      NetExpr*elaborate_eval_expr_base_(Design*, NetExpr*lp, NetExpr*rp,
					unsigned expr_wid) const;

      NetExpr*elaborate_expr_base_bits_(Design*, NetExpr*lp, NetExpr*rp,
                                        unsigned expr_wid) const;
      NetExpr*elaborate_expr_base_div_(Design*, NetExpr*lp, NetExpr*rp,
				       unsigned expr_wid) const;
      NetExpr*elaborate_expr_base_mult_(Design*, NetExpr*lp, NetExpr*rp,
					unsigned expr_wid) const;
      NetExpr*elaborate_expr_base_add_(Design*, NetExpr*lp, NetExpr*rp,
				       unsigned expr_wid) const;

};

/*
 * Here are a few specialized classes for handling specific binary
 * operators.
 */
class PEBComp  : public PEBinary {

    public:
      explicit PEBComp(char op, PExpr*l, PExpr*r);
      ~PEBComp() override;

      virtual unsigned test_width(Design*des, NetScope*scope,
				  width_mode_t&mode) override;

      NetExpr* elaborate_expr(Design*des, NetScope*scope,
			      unsigned expr_wid, unsigned flags) const override;

    private:
      unsigned l_width_;
      unsigned r_width_;
};

/*
 * This derived class is for handling logical expressions: && and ||.
*/
class PEBLogic  : public PEBinary {

    public:
      explicit PEBLogic(char op, PExpr*l, PExpr*r);
      ~PEBLogic() override;

      virtual unsigned test_width(Design*des, NetScope*scope,
				  width_mode_t&mode) override;

      NetExpr* elaborate_expr(Design*des, NetScope*scope,
			      unsigned expr_wid, unsigned flags) const override;
};

/*
 * A couple of the binary operands have a special sub-expression rule
 * where the expression width is carried entirely by the left
 * expression, and the right operand is self-determined.
 */
class PEBLeftWidth  : public PEBinary {

    public:
      explicit PEBLeftWidth(char op, PExpr*l, PExpr*r);
      ~PEBLeftWidth() override =0;

      virtual NetExpr*elaborate_expr_leaf(Design*des, NetExpr*lp, NetExpr*rp,
					  unsigned expr_wid) const =0;

    protected:
      virtual unsigned test_width(Design*des, NetScope*scope,
				  width_mode_t&mode) override;

      virtual NetExpr*elaborate_expr(Design*des, NetScope*scope,
				     unsigned expr_wid,
                                     unsigned flags) const override;
};

class PEBPower  : public PEBLeftWidth {

    public:
      explicit PEBPower(char op, PExpr*l, PExpr*r);
      ~PEBPower() override;

      NetExpr*elaborate_expr_leaf(Design*des, NetExpr*lp, NetExpr*rp,
				  unsigned expr_wid) const override;
};

class PEBShift  : public PEBLeftWidth {

    public:
      explicit PEBShift(char op, PExpr*l, PExpr*r);
      ~PEBShift() override;

      NetExpr*elaborate_expr_leaf(Design*des, NetExpr*lp, NetExpr*rp,
				  unsigned expr_wid) const override;
};

/*
 * This class supports the ternary (?:) operator. The operator takes
 * three expressions, the test, the true result and the false result.
 */
class PETernary : public PExpr {

    public:
      explicit PETernary(PExpr*e, PExpr*t, PExpr*f);
      ~PETernary() override;

      inline PExpr* get_cond()  const { return expr_; }
      inline PExpr* get_true()  const { return tru_; }
      inline PExpr* get_false() const { return fal_; }

      virtual void dump(std::ostream&out) const override;

      virtual void declare_implicit_nets(LexicalScope*scope, NetNet::Type type) override;

      virtual bool has_aa_term(Design*des, NetScope*scope) const override;

      virtual void reloc_lexical_pos_bind() override;

      virtual unsigned test_width(Design*des, NetScope*scope,
				  width_mode_t&mode) override;

      virtual NetExpr*elaborate_expr(Design*des, NetScope*,
		                     unsigned expr_wid,
                                     unsigned flags) const override;

    private:
      NetExpr* elab_and_eval_alternative_(Design*des, NetScope*scope,
					  PExpr*expr, unsigned expr_wid,
                                          unsigned flags, bool short_cct) const;

    private:
      PExpr*expr_;
      PExpr*tru_;
      PExpr*fal_;
};

/*
 * This class represents a parsed call to a function, including calls
 * to system functions. The parameters in the parms list are the
 * expressions that are passed as input to the ports of the function.
 */
class PECallFunction : public PExpr {
    public:
      explicit PECallFunction(const pform_name_t &n, const std::vector<named_pexpr_t> &parms);
	// Call function defined in package.
      explicit PECallFunction(PPackage *pkg, const pform_name_t &n, const std::list<named_pexpr_t> &parms);

	// Used to convert a user function called as a task
      explicit PECallFunction(PPackage *pkg, const pform_name_t &n, const std::vector<named_pexpr_t> &parms);

	// Call of system function (name is not hierarchical)
      explicit PECallFunction(perm_string n, const std::vector<named_pexpr_t> &parms);
      explicit PECallFunction(perm_string n);

	// Method call on an arbitrary receiver expression, e.g.
	// f().method(args) or C#(T)::get().method(args). The receiver is
	// elaborated first and the method is dispatched against the exact
	// type of the receiver result (IEEE 1800-2017 8.10, 6.19.5).
      explicit PECallFunction(PExpr*receiver, perm_string method_name,
			      const std::list<named_pexpr_t> &parms);

	// std::list versions. Should be removed!
      explicit PECallFunction(const pform_name_t &n, const std::list<named_pexpr_t> &parms);
      explicit PECallFunction(perm_string n, const std::list<named_pexpr_t> &parms);

      ~PECallFunction() override;

      void set_leading_type_args(struct parmvalue_t*type_args)
            { leading_type_args_ = type_args; }
      const struct parmvalue_t* leading_type_args() const
            { return leading_type_args_; }

      const pform_scoped_name_t& path() const { return path_; }
      const std::vector<named_pexpr_t>& get_parms() const { return parms_; }

      virtual void dump(std::ostream &) const override;

      virtual void declare_implicit_nets(LexicalScope*scope, NetNet::Type type) override;

      virtual bool has_aa_term(Design*des, NetScope*scope) const override;

      virtual void reloc_lexical_pos_bind() override;

      virtual NetExpr*elaborate_expr(Design*des, NetScope*scope,
				     ivl_type_t type, unsigned flags) const override;

      virtual NetExpr*elaborate_expr(Design*des, NetScope*scope,
				     unsigned expr_wid, unsigned flags) const override;

      virtual unsigned test_width(Design*des, NetScope*scope,
				  width_mode_t&mode) override;

    public:
      void set_with_constraints(std::vector<PExpr*> c)
            { with_constraints_ = std::move(c); }
      const std::vector<PExpr*>& with_constraints() const
            { return with_constraints_; }

    private:
      pform_scoped_name_t path_;
      std::vector<named_pexpr_t> parms_;
      std::vector<PExpr*> with_constraints_;
      struct parmvalue_t*leading_type_args_ = 0;
	// Non-null for method calls on arbitrary receiver expressions.
	// In that case path_ holds only the method name.
      PExpr*receiver_ = nullptr;

        // For system functions.
      bool is_overridden_;

      bool check_call_matches_definition_(Design*des, NetScope*dscope) const;


      NetExpr* cast_to_width_(NetExpr*expr, unsigned wid) const;

      NetExpr* elaborate_expr_(Design *des, NetScope *scope,
			       unsigned flags) const;

      NetExpr* elaborate_expr_method_(Design*des, NetScope*scope,
				      symbol_search_results&search_results)
				      const;
      NetExpr* elaborate_expr_method_par_(Design*des, const NetScope*scope,
					  const symbol_search_results&search_results)
					  const;

	// Shared dispatch of a method call against an elaborated receiver
	// expression and its exact result type. Used both by the
	// search-result driven path and by receiver-based calls.
      NetExpr* elaborate_method_dispatch_(Design*des, NetScope*scope,
					  NetExpr*sub_expr,
					  ivl_type_t target_type,
					  bool target_indexed,
					  perm_string method_name,
					  const pform_name_t&use_path,
					  bool explicit_super) const;
      NetExpr* elaborate_receiver_method_(Design*des, NetScope*scope,
					  unsigned flags) const;

      NetExpr* elaborate_sfunc_(Design*des, NetScope*scope,
                                unsigned expr_wid,
                                unsigned flags) const;
      NetExpr* elaborate_access_func_(Design*des, NetScope*scope, ivl_nature_t)
                                      const;
      unsigned test_width_sfunc_(Design*des, NetScope*scope,
			         width_mode_t&mode);
      unsigned test_width_method_(Design*des, NetScope*scope,
				  const symbol_search_results&search_results,
				  width_mode_t&mode);

      NetExpr*elaborate_base_(Design*des, NetScope*scope, NetScope*dscope,
			      unsigned flags) const;

      unsigned elaborate_arguments_(Design*des, NetScope*scope,
                                    const NetFuncDef*def, bool need_const,
                                    std::vector<NetExpr*>&parms,
                                    unsigned parm_off) const;
};

/*
 * Support the SystemVerilog cast to size.
 */
class PECastSize  : public PExpr {

    public:
      explicit PECastSize(PExpr*size, PExpr*base);
      ~PECastSize() override;

      void dump(std::ostream &out) const override;

      virtual NetExpr*elaborate_expr(Design*des, NetScope*scope,
				     unsigned expr_wid,
                                     unsigned flags) const override;

      virtual bool has_aa_term(Design *des, NetScope *scope) const override;

      virtual unsigned test_width(Design*des, NetScope*scope,
				  width_mode_t&mode) override;

    private:
      PExpr* size_;
      PExpr* base_;
};

/*
 * Support the SystemVerilog cast to a different type.
 */
class PECastType  : public PExpr {

    public:
      explicit PECastType(data_type_t*target, PExpr*base);
      ~PECastType() override;

      void dump(std::ostream &out) const override;

      virtual NetExpr*elaborate_expr(Design*des, NetScope*scope,
				     ivl_type_t type, unsigned flags) const override;

      virtual NetExpr*elaborate_expr(Design*des, NetScope*scope,
				     unsigned expr_wid, unsigned flags) const override;

      virtual bool has_aa_term(Design *des, NetScope *scope) const override;

      virtual unsigned test_width(Design*des, NetScope*scope,
				  width_mode_t&mode) override;

      // Streaming-concatenation support: resolve and expose the cast
      // target type, and the base expression, so a stream operand of
      // the form queue_type'(...) can be classified and elaborated.
      ivl_type_t resolve_target_type(Design*des, NetScope*scope) const;
      PExpr* cast_base() const { return base_; }

    private:
      data_type_t* target_;
      mutable ivl_type_t target_type_;
      PExpr* base_;
};

/*
 * Support the SystemVerilog sign cast.
 */
class PECastSign : public PExpr {

    public:
      explicit PECastSign(bool signed_flag, PExpr *base);
      ~PECastSign() override = default;

      void dump(std::ostream &out) const override;

      NetExpr* elaborate_expr(Design *des, NetScope *scope,
			      unsigned expr_wid, unsigned flags) const override;

      virtual bool has_aa_term(Design *des, NetScope *scope) const override;

      unsigned test_width(Design *des, NetScope *scope, width_mode_t &mode) override;

    private:
      std::unique_ptr<PExpr> base_;
};

/*
 * Represents one element in an "inside" expression range list.
 * Either a single value (is_range=false, lo=nullptr, hi=value) or
 * a range [lo:hi] (is_range=true).
 */
struct inside_range_t {
    PExpr* lo;
    PExpr* hi;
    bool is_range;
    // C7 (Phase 62b): dist weight expression.  Non-null only for `dist`-form
    // ranges that carry an explicit weight (`val := w` or `val :/ w`).
    // Weight is null for plain `inside { ... }` ranges (uniform pick).
    PExpr* weight = nullptr;
    // C7: true if the weight was specified with `:/` (divide across range
    // count) rather than `:=` (per-item).  Only meaningful when weight!=null.
    bool weight_is_divided = false;
};

/*
 * SystemVerilog streaming-concatenation operator (IEEE 1800-2017
 * 11.4.14).
 *   {<<N {e1, e2, ...}}  — pack with N-bit chunk-reverse of the whole
 *                          concatenated stream.  N=1: full bit-reverse.
 *   {>>N {e1, e2, ...}}  — pack in stream (concatenation) order.
 * The slice size may be a constant expression (resolved at elaboration
 * so parameters work) or a type (slice = the type's packed width, e.g.
 * {<< byte {...}}); both null means slice 1.
 *
 * As an assignment target (11.4.14.4) the parser rewrites
 *   {op N {l1, l2, ...}} = rhs;
 * into
 *   {l1, l2, ...} = {op N {rhs}};   // PEStreaming with lval_context
 * The lval_context form implements the unpack width rules: it is an
 * error when the source stream has fewer bits than the target, and
 * when the source is wider the target takes the leading (left-most)
 * bits of the reordered stream — see the "hello world" example in
 * 11.4.14.4.
 */
class PEStreaming : public PExpr {
    public:
      enum direction_t { DIR_LSHIFT, DIR_RSHIFT };
      PEStreaming(direction_t dir, PExpr*slice_expr, data_type_t*slice_type,
                  PExpr*inner, bool lval_context)
      : dir_(dir), slice_expr_(slice_expr), slice_type_(slice_type),
        inner_(inner), lval_context_(lval_context) {}
      ~PEStreaming() override
          { delete inner_; delete slice_expr_; delete slice_type_; }
      direction_t get_dir() const { return dir_; }
      PExpr* get_inner() const { return inner_; }
      bool is_lval_context() const { return lval_context_; }
      // Release ownership of inner_ so a parse-time rewrite can
      // reparent the expression without a double-delete when the
      // PEStreaming is itself destroyed.
      PExpr* release_inner() { PExpr*r = inner_; inner_ = nullptr; return r; }
      void dump(std::ostream& out) const override {
            out << "{" << (dir_ == DIR_LSHIFT ? "<<" : ">>");
            if (slice_expr_) { out << " "; slice_expr_->dump(out); }
            out << "{";
            inner_->dump(out);
            out << "}}";
      }
      unsigned test_width(Design* des, NetScope* scope,
                          width_mode_t& mode) override;
      NetExpr* elaborate_expr(Design* des, NetScope* scope,
                              ivl_type_t type, unsigned flags) const override;
      NetExpr* elaborate_expr(Design* des, NetScope* scope,
                              unsigned expr_wid, unsigned flags) const override;
      // Unpack elaboration (11.4.14.3): the streaming concatenation was
      // the target of an assignment and lv_width is the total width of
      // the (rewritten) l-value concatenation.
      NetExpr* elaborate_unpack(Design* des, NetScope* scope,
                                unsigned lv_width) const;
      // Pack as assignment source (11.4.14): left-align the stream in
      // the lv_width-bit target (error if the target is narrower).
      NetExpr* elaborate_pack_into(Design* des, NetScope* scope,
                                   unsigned lv_width) const;
      // Dynamic-size streaming (11.4.14.4): true when any operand is a
      // queue, dynamic array, or string (directly or via a cast to
      // such a type), so the stream width is a runtime value.
      bool stream_is_dynamic(Design*des, NetScope*scope) const;
      // Build the runtime stream expression: an internal system
      // function "$ivl_stream$pack$<l|r>$<slice>" whose arguments are
      // the elaborated operands.  rtype non-null gives a typed
      // (container or string) result; otherwise the result is a
      // vector of expr_wid bits (aligned at runtime).
      NetExpr* elaborate_stream_sfunc(Design*des, NetScope*scope,
                                      ivl_type_t rtype,
                                      unsigned expr_wid) const;
    private:
      void collect_operands_(std::vector<PExpr*>&ops) const;
      unsigned resolve_slice_(Design* des, NetScope* scope) const;
      NetExpr* reorder_stream_(NetExpr*body, unsigned wid,
                               unsigned slice, bool invert) const;
    private:
      direction_t dir_;
      PExpr* slice_expr_;
      data_type_t* slice_type_;
      PExpr* inner_;
      bool lval_context_;
};

/*
 * I4 (Phase 62c): wraps a soft constraint expression.  Constraint solving
 * applies it as a soft assertion (default weight 1) rather than a hard
 * conjunct — Z3 satisfies it when feasible but allows violation if other
 * hard constraints conflict.  Plain elaboration just delegates to the
 * inner expression so non-constraint contexts ignore the soft flag.
 */
class PESoft : public PExpr {
    public:
      explicit PESoft(PExpr* inner) : inner_(inner) {}
      ~PESoft() override { delete inner_; }
      PExpr* get_inner() const { return inner_; }
      void dump(std::ostream& out) const override {
            out << "(soft "; inner_->dump(out); out << ")";
      }
      unsigned test_width(Design*des, NetScope*scope, width_mode_t&mode) override {
            return inner_->test_width(des, scope, mode);
      }
      NetExpr* elaborate_expr(Design*des, NetScope*scope,
                              ivl_type_t type, unsigned flags) const override {
            return inner_->elaborate_expr(des, scope, type, flags);
      }
      NetExpr* elaborate_expr(Design*des, NetScope*scope,
                              unsigned w, unsigned flags) const override {
            return inner_->elaborate_expr(des, scope, w, flags);
      }
    private:
      PExpr* inner_;
};

/*
 * Represents conditional constraint forms inside constraint blocks
 * (IEEE 1800-2017 18.5.6 implication with a constraint set,
 * 18.5.7 if-else constraints):
 *   cond -> { items... }
 *   if (cond) { items... } [ else { items... } ]
 * The item lists are constraint expressions that apply only when the
 * condition holds (resp. fails). Only meaningful in constraint IR
 * generation; ordinary expression elaboration reports an error.
 */
class PEConstraintIf : public PExpr {
    public:
      PEConstraintIf(PExpr*cond, std::list<PExpr*>*then_items,
		     std::list<PExpr*>*else_items);
      ~PEConstraintIf() override;

      PExpr* get_cond() const { return cond_; }
      const std::list<PExpr*>& then_items() const { return then_items_; }
      const std::list<PExpr*>& else_items() const { return else_items_; }

      void dump(std::ostream&out) const override;
      unsigned test_width(Design*des, NetScope*scope,
			  width_mode_t&mode) override;
      NetExpr* elaborate_expr(Design*des, NetScope*scope,
			      unsigned w, unsigned flags) const override;

    private:
      PExpr*cond_;
      std::list<PExpr*> then_items_;
      std::list<PExpr*> else_items_;
};

/*
 * Represents an iterative constraint (IEEE 1800-2017 18.5.8):
 *   foreach (array_name[i]) { items... }
 * Only meaningful in constraint IR generation.
 */
class PEConstraintForeach : public PExpr {
    public:
      PEConstraintForeach(perm_string array_name,
			  std::list<perm_string>*loop_vars,
			  std::list<PExpr*>*items);
      ~PEConstraintForeach() override;

      perm_string array_name() const { return array_name_; }
      const std::vector<perm_string>& loop_vars() const { return loop_vars_; }
      const std::list<PExpr*>& items() const { return items_; }

      void dump(std::ostream&out) const override;
      unsigned test_width(Design*des, NetScope*scope,
			  width_mode_t&mode) override;
      NetExpr* elaborate_expr(Design*des, NetScope*scope,
			      unsigned w, unsigned flags) const override;

    private:
      perm_string array_name_;
      std::vector<perm_string> loop_vars_;
      std::list<PExpr*> items_;
};

/*
 * Represents a constraint ordering directive (IEEE 1800-2017 18.5.10):
 *   solve a, b before c, d;
 * Only meaningful in constraint IR generation.
 */
class PEConstraintOrder : public PExpr {
    public:
      PEConstraintOrder(std::list<PExpr*>*before_list,
			std::list<PExpr*>*after_list);
      ~PEConstraintOrder() override;

      const std::list<PExpr*>& before_items() const { return before_; }
      const std::list<PExpr*>& after_items() const { return after_; }

      void dump(std::ostream&out) const override;
      unsigned test_width(Design*des, NetScope*scope,
			  width_mode_t&mode) override;
      NetExpr* elaborate_expr(Design*des, NetScope*scope,
			      unsigned w, unsigned flags) const override;

    private:
      std::list<PExpr*> before_;
      std::list<PExpr*> after_;
};

/*
 * Represents the SystemVerilog "inside" expression:
 *   expr inside {[lo:hi], val, ...}
 */
class PEInside : public PExpr {
    public:
      PEInside(PExpr* expr, std::list<inside_range_t>* ranges);
      ~PEInside() override;

      PExpr* get_expr() const { return expr_; }
      const std::vector<inside_range_t>& get_ranges() const { return ranges_; }

      // C7: PEInside doubles as the `dist` lowering target.  When any
      // range carries a non-null weight, emit a `(dist ...)` constraint
      // IR opcode instead of `(inside ...)` so the Z3 backend can apply
      // soft assertions.
      bool is_dist() const;

      void dump(std::ostream& out) const override;
      unsigned test_width(Design* des, NetScope* scope,
                          width_mode_t& mode) override;
      NetExpr* elaborate_expr(Design* des, NetScope* scope,
                              ivl_type_t type, unsigned flags) const override;
      NetExpr* elaborate_expr(Design* des, NetScope* scope,
                              unsigned expr_wid, unsigned flags) const override;
    private:
      PExpr* expr_;
      std::vector<inside_range_t> ranges_;
};

/*
 * This class is used for error recovery. All methods do nothing and return
 * null or default values.
 */
class PEVoid : public PExpr {

    public:
      explicit PEVoid();
      ~PEVoid() override;

      virtual NetExpr*elaborate_expr(Design*des, NetScope*scope,
				     unsigned expr_wid,
                                     unsigned flags) const override;
};

#endif /* IVL_PExpr_H */

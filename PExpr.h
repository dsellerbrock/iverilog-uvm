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
class PExpr;
class PLet;
class NetExpr;
class NetScope;
class PPackage;
struct symbol_search_results;

/* Parse-form pattern tree shared by case-matches, pattern conditionals and
 * the matches predicate of a conditional expression (IEEE 1800-2017 12.6).
 * A structure pattern is ordered in this first complete slice; the node shape
 * deliberately leaves the matching engine reusable for named structure
 * patterns and filters without another parser-specific representation. */
class PMatchPattern : public LineInfo {
    public:
      enum kind_t { CONSTANT, VARIABLE, WILDCARD, TAGGED, STRUCTURE };

      explicit PMatchPattern(kind_t kind);
      ~PMatchPattern() override;

      kind_t kind() const { return kind_; }
      PExpr* expression() const { return expression_; }
      perm_string name() const { return name_; }
      const std::vector<PMatchPattern*>& children() const { return children_; }

      void expression(PExpr*expr) { expression_ = expr; }
      void name(perm_string name) { name_ = name; }
      void children(std::vector<PMatchPattern*>*children);

      void declare_implicit_nets(LexicalScope*scope, NetNet::Type type);
      bool has_aa_term(Design*des, NetScope*scope) const;
      void reloc_lexical_pos_bind(bool parameter_context = false);
      void dump(std::ostream&out) const;

    private:
      kind_t kind_;
      PExpr*expression_ = nullptr;
      perm_string name_;
      std::vector<PMatchPattern*>children_;
};

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
      // Permit the symbolic unbounded value only while evaluating a value
      // parameter assignment or the argument of $isunbounded().
      static const unsigned ALLOW_UNBOUNDED = 0x8;

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
      virtual void reloc_lexical_pos_bind(bool parameter_context = false);

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

/* Boolean match predicate. Statement contexts install pattern variables in
 * their implicit true-arm/item scopes; use of a binding from the true operand
 * of a conditional expression remains outside this first slice. This node is
 * responsible only for evaluating the typed pattern and remains reusable by
 * all three 12.6 forms. */
class PEMatches : public PExpr {
    public:
      PEMatches(PExpr*subject, PMatchPattern*pattern,
                NetCase::TYPE case_type = NetCase::EQ);
      ~PEMatches() override;

      PExpr* subject() const { return subject_; }
      PMatchPattern* pattern() const { return pattern_; }
      NetCase::TYPE case_type() const { return case_type_; }

      void dump(std::ostream&out) const override;
      void declare_implicit_nets(LexicalScope*scope,
                                 NetNet::Type type) override;
      bool has_aa_term(Design*des, NetScope*scope) const override;
      void reloc_lexical_pos_bind(bool parameter_context = false) override;
      unsigned test_width(Design*des, NetScope*scope,
                          width_mode_t&mode) override;
      NetExpr* elaborate_expr(Design*des, NetScope*scope,
                              unsigned expr_wid,
                              unsigned flags) const override;

    private:
      PExpr*subject_;
      PMatchPattern*pattern_;
      NetCase::TYPE case_type_;
};

std::ostream& operator << (std::ostream&, const PExpr&);

/* IEEE 1800-2017 10.9 assignment-pattern keys. A key written as an
 * expression is resolved against the target: for a structure a bare
 * identifier can name a member, while for an array it is a constant
 * declared index. Types and default are syntactically unambiguous. */
struct assignment_pattern_key_t {
      enum kind_t { EXPR, TYPE, DEFAULT };

      explicit assignment_pattern_key_t(kind_t k = EXPR)
      : kind(k), expr(nullptr), type(nullptr) { }

      kind_t kind;
      PExpr*expr;
      data_type_t*type;
};

struct assignment_pattern_item_t {
      assignment_pattern_key_t key;
      PExpr*value;
};

class PEAssignPattern : public PExpr {
    public:
      explicit PEAssignPattern();
      explicit PEAssignPattern(const std::list<PExpr*>&p);
      explicit PEAssignPattern(const std::list<std::pair<perm_string,PExpr*>>&named);
      explicit PEAssignPattern(const std::list<assignment_pattern_item_t>&keyed);
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
      void reloc_lexical_pos_bind(bool parameter_context) override;
      const std::vector<PExpr*>& parms() const { return parms_; }
      const std::vector<perm_string>& parm_names() const { return parm_names_; }
      const std::vector<assignment_pattern_key_t>& keys() const { return keys_; }
	// Non-null when the pattern is exactly `'{default: value}'.
      PExpr* lone_default_() const;
	// Effective element list, expanding the `'{N{...}}' replication
	// form. False (diagnosed) when N is not a usable constant.
      bool expand_replication_(Design*des, NetScope*scope,
			       std::vector<PExpr*>&out) const;
      bool resolve_keyed_dimension_(Design*des, NetScope*scope,
				    const netrange_t&range,
				    ivl_type_t element_type,
				    std::vector<PExpr*>&out) const;
      PExpr* replication() const { return replication_; }
    private:
	// decl_type is the DECLARED type the dims were flattened from,
	// carried along so a nested pattern can be matched against the
	// real element type (a packed struct, say) instead of against a
	// bit count. Nil keeps the pure dimension-list behaviour.
      NetExpr* elaborate_expr_packed_(Design *des, NetScope *scope,
				      ivl_variable_type_t base_type,
				      unsigned int width,
				      const netranges_t &dims,
				      unsigned int cur_dim,
				      bool need_const,
				      ivl_type_t decl_type = nullptr) const;
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
      std::vector<assignment_pattern_key_t>keys_; // non-empty → keyed pattern
      PExpr* replication_ = nullptr;       // non-null for '{N{...}} form
};

class PEConcat : public PExpr {

    public:
      explicit PEConcat(const std::list<PExpr*>&p, PExpr*r =0);
      ~PEConcat() override;

      virtual void reloc_lexical_pos_bind(bool parameter_context) override;

      bool is_empty_concat() const { return parms_.empty() && repeat_ == 0; }

      // Read-only operand access for the streaming-concatenation
      // lowering (a multi-operand stream is parsed as a PEConcat).
      const std::vector<PExpr*>& stream_parms() const { return parms_; }
      bool has_repeat() const { return repeat_ != 0; }
      PExpr* repeat_expr() const { return repeat_; }

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
	// The optional condition is the IEEE 1800 event-expression `iff'
	// guard. It is sampled only when the associated event occurs.
      PEEvent(edge_t t, PExpr*e, PExpr*condition = nullptr);

      ~PEEvent() override;

      edge_t type() const;
      PExpr* expr() const;
      PExpr* condition() const;

      virtual void dump(std::ostream&) const override;

      virtual bool has_aa_term(Design*des, NetScope*scope) const override;

    private:
      edge_t type_;
      PExpr *expr_;
      PExpr *condition_;
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

	// Set on identifiers that came out of a CONCURRENT ASSERTION.
	// An unresolved name normally degrades to a compile-progress
	// warning so UVM-heavy code keeps building, but inside an
	// assertion that leaves a property which compiles, never
	// evaluates, and reports nothing -- the check silently does not
	// exist. Marked identifiers take the error branch instead.
      void set_strict_bind() { strict_bind_ = true; }
      bool strict_bind() const { return strict_bind_; }

	// Set on COMPILER-GENERATED references that merely shadow a name
	// the user already wrote (the $ivl_clocking_hist_on bookkeeping
	// argument). If such a name fails to bind, the user's own
	// reference reports it; this one must stay silent rather than
	// duplicate the diagnostic.
      void set_quiet_bind() { quiet_bind_ = true; }
      bool quiet_bind() const { return quiet_bind_; }

      // Add another name to the string of hierarchy that is the
      // current identifier.
      void append_name(perm_string);

      // Add a select to the final component of the identifier. This is
      // used by recursive class-scoped carriers, which must retain their
      // specialization provenance while accepting ordinary l-value suffixes.
      void append_index(const index_component_t&);

      // Make a second reference to the same parsed path for a synthetic
      // receiver expression. The clone borrows specialization arguments;
      // the original identifier remains their owner.
      PEIdent* clone_for_reference() const;

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
      NetNet* elaborate_unpacked_net(Design*des, NetScope*sc,
				      ivl_type_t target_type = nullptr) const;

      virtual bool is_collapsible_net(Design*des, NetScope*scope,
                                      NetNet::PortType port_type) const override;

      const pform_scoped_name_t& path() const { return path_; }

      unsigned lexical_pos() const { return lexical_pos_; }

      virtual void reloc_lexical_pos_bind(bool parameter_context) override;

      // I5 (Phase 62m): when path was parsed from `Class#(args)::var`,
      // these are the leading type arguments needed to identify the
      // parameterized-class specialization.  Without this, the
      // elaborator falls back to the unspecialized class, so static
      // property accesses target the base instead of the specialization.
      void set_leading_type_args(struct parmvalue_t*type_args)
            { leading_type_args_ = type_args; }
      const struct parmvalue_t* leading_type_args() const
            { return leading_type_args_; }
      void set_borrowed_leading_type_args(
            const struct parmvalue_t*type_args)
            { leading_type_args_ = const_cast<struct parmvalue_t*>(type_args);
              owns_leading_type_args_ = false; }
      struct parmvalue_t* take_leading_type_args()
            { struct parmvalue_t*tmp = leading_type_args_;
              leading_type_args_ = nullptr; return tmp; }
      void set_scoped_type_prefix(bool flag = true)
            { scoped_type_prefix_ = flag; }
      bool has_scoped_type_prefix() const
            { return scoped_type_prefix_; }

	// IEEE 1800-2017 6.23 `type()` operator support: resolve the type
	// of this identifier reference (including any indices, hierarchy
	// or member-selects) WITHOUT evaluating it -- index expressions
	// are only counted structurally, never computed. Returns 0 if the
	// identifier can't be resolved this way; the caller is responsible
	// for diagnosing that (no diagnostic is emitted here on failure,
	// so callers that tolerate a null result don't get double errors).
      ivl_type_t test_type_of_ident(Design*des, NetScope*scope) const;

	// Constraint legality checks must inspect the expression after `let'
	// substitution as well as the surface call/reference. This accessor uses
	// the same cached expansion as width testing and elaboration.
      PExpr* constraint_let_substitution(Design*des, NetScope*scope) const
            { return let_substitution_(des, scope); }

    private:
      pform_scoped_name_t path_;
      unsigned lexical_pos_;

	// M13: cached let-expansion for a bare let reference.
      mutable PExpr*let_subst_ = nullptr;
      mutable bool let_subst_tried_ = false;
      PExpr* let_substitution_(Design*des, NetScope*scope) const;
      bool no_implicit_sig_;
      struct parmvalue_t* leading_type_args_ = 0;
      bool owns_leading_type_args_ = true;
      bool scoped_type_prefix_ = false;
      mutable bool bare_generic_scope_error_reported_ = false;
      mutable bool scoped_lvalue_error_reported_ = false;

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

	// True when this select needs the general computed packed base
	// (a run-time index in a NON-final dimension, which the constant
	// prefix path above cannot express). False for every shape that
	// path already handles, so it stays in charge of those.
      bool packed_base_needs_expr_(Design*des, NetScope*scope,
				   const NetNet*net,
				   const std::list<index_component_t>&indices) const;

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
      bool elaborate_lval_darray_part_(Design*, NetScope*,
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
	// General select on a multi-dimensional packed parameter, or any
	// select with more than one index component. Computes ONE
	// canonical flattened offset plus the addressed slice width, for
	// any mix of constant and variable indices.
      NetExpr*elaborate_expr_param_select_multi_(Design*des,
						 NetScope*scope,
						 const NetExpr*par,
						 const NetScope*found_in,
						 ivl_type_t par_type,
						 bool need_const) const;
	// Any select on an unpacked ARRAY parameter (elements are stored
	// as individual "name[i]" parameters under their declared
	// indices): resolve the element, then apply remaining indices.
      NetExpr*elaborate_expr_param_array_(Design*des,
					  NetScope*scope,
					  const NetExpr*par,
					  const NetScope*found_in,
					  ivl_type_t par_type,
					  bool need_const) const;
	// Materialize a whole, partially indexed, or sliced unpacked array
	// parameter as a typed array value. Source and target dimensions may
	// have different index bounds/directions; assignment is left-to-left.
      NetExpr*elaborate_expr_param_array_value_(Design*des,
						NetScope*scope,
						const NetScope*found_in,
						perm_string name,
						ivl_type_t par_type,
						ivl_type_t target_type,
						bool need_const) const;
	// Select packed-struct members after resolving a scalar parameter or
	// an element of an unpacked array parameter (P[i].member).
      NetExpr*elaborate_expr_param_member_(Design*des,
					   NetScope*scope,
					   const symbol_search_results&sr,
					   unsigned flags) const;
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
      bool strict_bind_ = false;
      bool quiet_bind_ = false;
      bool bind_parameter_expr_ = false;

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

      PExpr* base() const { return base_; }
      PExpr* take_base()
            { PExpr*tmp = base_; base_ = nullptr; return tmp; }
      perm_string member_name() const { return member_name_; }

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

/* IEEE 1800-2017 11.5 permits a bit or part select on a packed expression,
 * not only on a named variable. This carrier represents bases that cannot be
 * folded into a hierarchy_identifier. The parser initially uses it for
 * concatenations such as `{a,b}[9:6]`. */
class PEPostSelect : public PExpr {

    public:
      PEPostSelect(PExpr*base, const index_component_t&index);
      ~PEPostSelect() override;

      void dump(std::ostream&) const override;
      void declare_implicit_nets(LexicalScope*scope,
                                 NetNet::Type type) override;
      bool has_aa_term(Design*des, NetScope*scope) const override;
      void reloc_lexical_pos_bind(bool parameter_context) override;

      unsigned test_width(Design*des, NetScope*scope,
                          width_mode_t&mode) override;
      NetExpr*elaborate_expr(Design*des, NetScope*scope,
                             unsigned expr_wid,
                             unsigned flags) const override;

    private:
      PExpr*base_;
      index_component_t index_;
      long constant_base_ = 0;
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
      explicit PEAssocType(data_type_t*index_type, bool wildcard_index);
      ~PEAssocType() override;

      inline data_type_t* index_type() { return index_type_.get(); }
      inline const data_type_t* index_type() const { return index_type_.get(); }
      bool wildcard_index() const { return wildcard_index_; }

      virtual unsigned test_width(Design*des, NetScope*scope,
				  width_mode_t&mode) override;
      virtual NetExpr*elaborate_expr(Design*des, NetScope*scope,
				     ivl_type_t type, unsigned flags) const override;
      virtual NetExpr*elaborate_expr(Design*des, NetScope*,
				     unsigned expr_wid,
                                     unsigned flags) const override;

    private:
      std::unique_ptr<data_type_t> index_type_;
      bool wildcard_index_;
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
 * IEEE 1800-2017 6.20.2.1: `$' is a symbolic unbounded parameter
 * value, not a large number or an unknown bit vector.  Keep it distinct
 * in the parse form so ordinary expression contexts can reject it and
 * $isunbounded() can query it without evaluating a fabricated value.
 */
class PEUnbounded : public PExpr {

    public:
      PEUnbounded();
      ~PEUnbounded() override;

      void dump(std::ostream&) const override;
      unsigned test_width(Design*des, NetScope*scope,
                          width_mode_t&mode) override;

      NetExpr*elaborate_expr(Design*des, NetScope*scope,
                             ivl_type_t type, unsigned flags) const override;
      NetEConst*elaborate_expr(Design*des, NetScope*scope,
                               unsigned expr_wid,
                               unsigned flags) const override;
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

      virtual NetExpr*elaborate_expr(Design*des, NetScope*scope,
				      ivl_type_t type, unsigned flags) const override;

      virtual NetEConst*elaborate_expr(Design*des, NetScope*,
				       unsigned expr_wid, unsigned) const override;

      NetExpr* elaborate_expr_uarray_(Design*des, NetScope*scope,
				      const netuarray_t*uarray_type,
				      const netranges_t&dims,
				      unsigned cur_dim) const;

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

      virtual void reloc_lexical_pos_bind(bool parameter_context) override;

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

      virtual void reloc_lexical_pos_bind(bool parameter_context) override;

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

/* IEEE 1800-2017 11.3.6 permits a parenthesized blocking assignment
 * wherever an expression is allowed. The expression both updates its
 * l-value and yields the assigned value. */
class PEAssignExpr : public PEBinary {

    public:
      explicit PEAssignExpr(char op, PExpr*l, PExpr*r);

      unsigned test_width(Design*des, NetScope*scope,
                          width_mode_t&mode) override;

      NetExpr* elaborate_expr(Design*des, NetScope*scope,
                              unsigned expr_wid,
                              unsigned flags) const override;
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

      virtual void reloc_lexical_pos_bind(bool parameter_context) override;

      virtual unsigned test_width(Design*des, NetScope*scope,
				  width_mode_t&mode) override;

      virtual NetExpr*elaborate_expr(Design*des, NetScope*,
		                     unsigned expr_wid,
                                     unsigned flags) const override;

	// Type-context form. Without this the base class falls back to
	// the width form with a width of 1, which strands any operand
	// that needs a TYPE rather than a width -- an assignment pattern
	// in particular.
      virtual NetExpr*elaborate_expr(Design*des, NetScope*,
				     ivl_type_t type,
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
      void set_borrowed_leading_type_args(
            const struct parmvalue_t*type_args)
            { leading_type_args_ = const_cast<struct parmvalue_t*>(type_args);
              owns_leading_type_args_ = false; }
      void set_scoped_type_prefix(bool flag = true)
            { scoped_type_prefix_ = flag; }
      bool has_scoped_type_prefix() const
            { return scoped_type_prefix_; }

	// Constraint legality checks operate on the semantic `let' body. Keep
	// expansion ownership and caching private while exposing the result.
      PExpr* constraint_let_substitution(Design*des, NetScope*scope) const
            { return let_substitution_(des, scope); }

      const pform_scoped_name_t& path() const { return path_; }
      const std::vector<named_pexpr_t>& get_parms() const { return parms_; }
      PExpr* receiver_expr() const { return receiver_; }
      virtual void dump(std::ostream &) const override;

      virtual void declare_implicit_nets(LexicalScope*scope, NetNet::Type type) override;

      virtual bool has_aa_term(Design*des, NetScope*scope) const override;

      virtual void reloc_lexical_pos_bind(bool parameter_context) override;

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
	// IEEE 1800-2017 18.7: `with (identifier_list)' makes exactly
	// these unqualified names resolve in the randomized object's scope;
	// other unqualified names retain caller-scope lookup.
      void set_randomize_with_identifiers(std::vector<perm_string> names)
	    { randomize_with_identifier_list_present_ = true;
	      randomize_with_identifiers_ = std::move(names); }
      const std::vector<perm_string>& randomize_with_identifiers() const
	    { return randomize_with_identifiers_; }
      bool has_randomize_with_identifier_list() const
	    { return randomize_with_identifier_list_present_; }

	// M9-SV: procedural sampled value functions (IEEE 1800-2017
	// 16.9.3). $past/$rose/$fell/$stable/$changed are not ordinary
	// system functions -- their value depends on a clocking event,
	// not just on their arguments. When the parser binds one of
	// these calls to a clock it synthesizes the sample and history
	// registers and leaves here the expression that reads them;
	// test_width and elaborate_expr then use that in place of the
	// call, the same way a `let' expansion substitutes.
      void set_sampled_subst(PExpr*e) { sampled_subst_ = e; }
      PExpr* sampled_subst() const { return sampled_subst_; }

    private:
      PExpr*sampled_subst_ = nullptr;
      pform_scoped_name_t path_;
      std::vector<named_pexpr_t> parms_;
      std::vector<PExpr*> with_constraints_;
      bool randomize_with_identifier_list_present_ = false;
      std::vector<perm_string> randomize_with_identifiers_;

	// M13: cached let-expansion (IEEE 1800-2017 11.13). When the
	// call name resolves to a let in scope, the substituted body is
	// built once and test_width/elaborate_expr delegate to it.
      mutable PExpr*let_subst_ = nullptr;
      mutable bool let_subst_tried_ = false;
      PExpr* let_substitution_(Design*des, NetScope*scope) const;
      struct parmvalue_t*leading_type_args_ = 0;
      bool owns_leading_type_args_ = true;
      bool scoped_type_prefix_ = false;
      mutable bool bare_generic_scope_error_reported_ = false;
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

      PExpr* cast_size() const { return size_; }
      PExpr* cast_base() const { return base_; }

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
      data_type_t* cast_target() const { return target_; }
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

      PExpr* cast_base() const { return base_.get(); }

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
                  PExpr*inner, bool lval_context,
                  bool ranged_lval_context = false)
      : dir_(dir), slice_expr_(slice_expr), slice_type_(slice_type),
        inner_(inner), lval_context_(lval_context),
        ranged_lval_context_(ranged_lval_context) {}
      ~PEStreaming() override
          { delete inner_; delete slice_expr_; delete slice_type_; }
      direction_t get_dir() const { return dir_; }
      PExpr* get_inner() const { return inner_; }
      bool is_lval_context() const { return lval_context_; }
      bool is_ranged_lval_context() const { return ranged_lval_context_; }
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
      bool ranged_lval_context_;
};

/* One streaming operand with the IEEE 1800-2023 11.4.14.4
 * `with [array_range_expression]' suffix.  This parse node deliberately
 * owns an arbitrary expression operand; legality is decided only after its
 * unpacked-array type is known during elaboration. */
class PEStreamWith : public PExpr {
    public:
      PEStreamWith(PExpr*base, ivl_stream_range_t kind,
                   PExpr*first, PExpr*second)
      : base_(base), kind_(kind), first_(first), second_(second) {}
      ~PEStreamWith() override
          { delete base_; delete first_; delete second_; }

      PExpr* base() const { return base_; }
      ivl_stream_range_t range_kind() const { return kind_; }
      PExpr* range_first() const { return first_; }
      PExpr* range_second() const { return second_; }

      void dump(std::ostream&out) const override;
      void declare_implicit_nets(LexicalScope*scope,
                                 NetNet::Type type) override;
      bool has_aa_term(Design*des, NetScope*scope) const override;
      void reloc_lexical_pos_bind(bool parameter_context) override;
      unsigned test_width(Design*des, NetScope*scope,
                          width_mode_t&mode) override;
      NetExpr* elaborate_expr(Design*des, NetScope*scope,
                              unsigned expr_wid,
                              unsigned flags) const override;
      NetAssign_* elaborate_lval(Design*des, NetScope*scope,
                                 bool is_cassign, bool is_force,
                                 bool is_init = false) const override;

    private:
      PExpr*base_;
      ivl_stream_range_t kind_;
      PExpr*first_;
      PExpr*second_;
};

/*
 * I4 (Phase 62c): wraps a soft constraint expression.  Constraint solving
 * applies it as a soft assertion (default weight 1) rather than a hard
 * conjunct — Z3 satisfies it when feasible but allows violation if other
 * hard constraints conflict.  Plain elaboration just delegates to the
 * inner expression so non-constraint contexts ignore the soft flag.
 */
/* unique {...} constraint (IEEE 1800-2017 18.5.5): the listed scalar
 * variables and array elements must take pairwise distinct values. The
 * constraint-IR emitter expands each unpacked-array operand to its
 * elements and emits pairwise (ne ...) terms. Only meaningful inside a
 * constraint block; ordinary expression elaboration folds it to 1. */
class PEUnique : public PExpr {
    public:
      explicit PEUnique(std::list<PExpr*>*items) : items_(items) {}
      ~PEUnique() override {
	    if (items_) {
		  for (PExpr*e : *items_) delete e;
		  delete items_;
	    }
      }
      const std::list<PExpr*>& items() const {
	    static const std::list<PExpr*> empty;
	    return items_ ? *items_ : empty;
      }
      void dump(std::ostream& out) const override {
	    out << "unique {...}";
      }
      unsigned test_width(Design*, NetScope*, width_mode_t&) override {
	    expr_type_ = IVL_VT_BOOL;
	    expr_width_ = 1;
	    min_width_ = 1;
	    signed_flag_ = false;
	    return 1;
      }
    private:
      std::list<PExpr*>*items_;
};

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
 * M3B-3: `disable soft <variable>;' inside a constraint block (IEEE
 * 1800-2017 18.5.14.1). Removes any soft constraint on the given
 * variable for this randomize() call. Only meaningful in constraint IR
 * emission, where it lowers to `(disable-soft <var>)'; in any other
 * elaboration context it delegates to the inner variable expression.
 */
class PEDisableSoft : public PExpr {
    public:
      explicit PEDisableSoft(PExpr* inner) : inner_(inner) {}
      ~PEDisableSoft() override { delete inner_; }
      PExpr* get_inner() const { return inner_; }
      void dump(std::ostream& out) const override {
            out << "(disable-soft "; inner_->dump(out); out << ")";
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
	// `foreach (array_name[prefix_names].member_name[loop_vars])':
	// IEEE 1800-2017 18.5.8 extended to a hierarchical target,
	// analogous to the plain-statement foreach of the same shape
	// (Statement.h PForeach). Unlike `loop_vars', `prefix_names' are
	// NOT fresh declarations -- each names an ALREADY-DECLARED
	// variable that selects one element of `array_name' along that
	// dimension, before `member_name's own dimension is iterated.
	// (Grammar note: the prefix positions are parsed through the
	// same `loop_variables' nonterminal as an ordinary loop-variable
	// list, not `expression' -- a bare identifier there is
	// indistinguishable from a loop-variable declaration with one
	// token of lookahead, so a dedicated `expression' alternative
	// only ever loses that reduce/reduce race and is simply never
	// reached; see ledger G65's identical finding for the
	// plain-statement form.)
      PEConstraintForeach(perm_string array_name,
			  std::list<perm_string>*prefix_names,
			  perm_string member_name,
			  std::list<perm_string>*loop_vars,
			  std::list<PExpr*>*items);
      ~PEConstraintForeach() override;

      perm_string array_name() const { return array_name_; }
      bool has_hierarchical_target() const { return !prefix_names_.empty(); }
      const std::vector<perm_string>& prefix_names() const { return prefix_names_; }
      perm_string member_name() const { return member_name_; }
      const std::vector<perm_string>& loop_vars() const { return loop_vars_; }
      const std::list<PExpr*>& items() const { return items_; }

      void dump(std::ostream&out) const override;
      unsigned test_width(Design*des, NetScope*scope,
			  width_mode_t&mode) override;
      NetExpr* elaborate_expr(Design*des, NetScope*scope,
			      unsigned w, unsigned flags) const override;

    private:
      perm_string array_name_;
      std::vector<perm_string> prefix_names_;
      perm_string member_name_;
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
      PEInside(PExpr* expr, std::list<inside_range_t>* ranges,
	       bool is_dist = false);
      ~PEInside() override;

      PExpr* get_expr() const { return expr_; }
      const std::vector<inside_range_t>& get_ranges() const { return ranges_; }

      // C7: PEInside doubles as the `dist` lowering target. Preserve the
	// source operator explicitly: an unweighted dist list is still dist,
	// and inferring it from optional range weights loses that distinction.
	bool is_dist() const { return is_dist_; }

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
      bool is_dist_;
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

/*
 * IEEE 1800-2017 6.23 type-operator support shared by expression and
 * statement elaboration. A type() operand is represented by a PETypename
 * that wraps a type_reference_t; matching elaborates the referenced types
 * without evaluating either source expression.
 */
const type_reference_t* type_operator_reference(const PExpr*expr);
bool elaborate_type_operator_match(Design*des, NetScope*scope,
				   const PExpr*left, const PExpr*right,
				   const LineInfo&loc, bool&match);

#endif /* IVL_PExpr_H */

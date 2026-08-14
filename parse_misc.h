#ifndef IVL_parse_misc_H
#define IVL_parse_misc_H
/*
 * Copyright (c) 1998-2024 Stephen Williams (steve@icarus.com)
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

# include  <list>
# include  <ostream>
# include  "compiler.h"
# include  "pform.h"

class PEventStatement;
class PExpr;
class Statement;

/* Randsequence parse tree (IEEE 1800-2017 18.17).  Keep production control
 * forms distinct until lowering; treating them as ordinary procedural
 * statements gives `break' and `return' the wrong enclosing target. */
struct rs_formal_t : public LineInfo {
      perm_string name;
      data_type_t* type = nullptr;
      NetNet::PortType direction = NetNet::PINPUT;
      PExpr* default_expr = nullptr;
};

struct rs_case_item_t;

struct rs_item_t : public LineInfo {
      enum kind_t { CALL, CODE, IF_ELSE, REPEAT, CASE, RAND_JOIN } kind = CALL;
      perm_string name;                    // CALL production name
      std::list<named_pexpr_t>* actuals = nullptr;
      Statement* code = nullptr;           // CODE block template
      PExpr* expr = nullptr;                // IF/REPEAT/CASE selector; join weight
      rs_item_t* first = nullptr;           // IF true / REPEAT body
      rs_item_t* second = nullptr;          // IF false
      std::vector<rs_case_item_t>* cases = nullptr;
      std::vector<rs_item_t>* join_items = nullptr;
};

struct rs_case_item_t : public LineInfo {
      std::list<PExpr*>* expressions = nullptr; // empty/null => default
      rs_item_t* item = nullptr;
};

struct rs_rule_t {
      std::vector<rs_item_t>* items = nullptr;  // sequence of items (>=1)
      PExpr* weight = nullptr;                    // `:= weight' (null => 1)
};
struct rs_production_t {
      perm_string name;
      bool explicit_void = false;
      data_type_t* return_type = nullptr;
      std::vector<rs_formal_t>* formals = nullptr;
      std::vector<rs_rule_t>* rules = nullptr;    // alternatives (>=1)
};

/*
 * M9: concurrent-assertion property capture (IEEE 1800-2017 clause 16).
 *
 * A sequence is represented as a linear chain of steps: each step is
 * a boolean expression preceded by a cycle-delay range. delay_lo ==
 * delay_hi encodes a fixed ##N; delay_lo < delay_hi encodes ##[m:n].
 * delay_lo == -1 marks an unbounded ##[m:$] (diagnosed sorry at
 * lowering); delay_lo == -2 marks a non-constant delay expression;
 * delay_lo == -4 with delay_genvar non-nil marks a fixed delay whose
 * value is the implicit localparam of a generated scope. The first
 * step's delay is relative to the sequence start (0 for a plain leading
 * boolean).
 */
struct sva_seq_step_t {
      long delay_lo = 0;    // -1: ##[m:$]; -2: non-constant; -3: an
			    // unsupported repetition shape (diagnosed)
      long delay_hi = 0;
      perm_string delay_genvar; // delay_lo/hi == -4: per-generate fixed ##n
      // delay_lo/hi == -5: bounded ##[lo:hi] expressions that depend on
      // overridable parameters and must be resolved per instance.
      PExpr* delay_lo_expr = nullptr;
      PExpr* delay_hi_expr = nullptr;
      long rep_tail = 0;    // e[*m:n] expands to [*m]; the final
			    // expanded step carries n-m here. Valid
			    // only in the last chain position
			    // (match-existence equivalence).
      PExpr* expr = nullptr;
      perm_string lv_name;  // M9-NFA LV-1: local-var assignment on this
      PExpr* lv_rhs = nullptr; //   step ((expr, lv_name = lv_rhs)); nil = none
      // IEEE 1800-2017 16.11: sequence match-item subroutine calls execute
      // in source order after the optional local-variable assignment above.
      // The bounded lowering diagnoses every unsupported placement/call
      // before an assertion engine can silently discard it.
      std::vector<PCallTask*> match_calls;
      bool fm = false;      // step is inside a first_match(...) wrapper
      // M9-NFA stage C.1: goto/nonconsecutive repetition of the boolean
      // `expr' (IEEE 1800-2017 16.9.2). rep_kind 0 = none; 1 = goto
      // `[->m:n]' (match ends ON the n-th occurrence); 2 = nonconsecutive
      // `[=m:n]' (match may extend past the last occurrence); 3 =
      // consecutive repetition with a zero lower bound (`[*0:n]'), whose
      // empty match cannot use rep_tail's concrete-first-step encoding.
      // rep_hi == -1 encodes an unbounded upper. delay_lo/hi is the leading
      // cycle gap before the repetition begins.
      int rep_kind = 0;
      long rep_lo = 0;
      long rep_hi = 0;
      // rep_kind 4 is a consecutive repetition whose bound depends on an
      // overridable module parameter.  Parse-time numeric folding would use
      // the declaration default, before an instance parameter override has
      // been applied.  Keep the original constant expressions owned by this
      // step so a focused checker lowering can put them in ordinary packed
      // ranges/expressions and let elaboration resolve each instance.
      // rep_hi_expr == nullptr with rep_hi == -1 denotes `[*lo:$]'.
      PExpr* rep_lo_expr = nullptr;
      PExpr* rep_hi_expr = nullptr;
};

/*
 * M9-NFA stage B: sequence-combinator tree over linear chains. A leaf
 * wraps a chain; interior nodes are the regular-language combinators
 * the linear IR cannot express. Only the automaton engine
 * (IVL_SVA_NFA=1) lowers trees; without it the assertion is a loud
 * sorry. Chains and expressions inside are OWNED by the tree.
 */
struct sva_stree_t {
      enum kind_t { LEAF = 0, SEQ_OR = 1, SEQ_AND = 2, SEQ_INTERSECT = 3,
		    SEQ_WITHIN = 4, SEQ_THROUGHOUT = 5,
		    SEQ_CONCAT = 6 };
      int kind = LEAF;
      std::vector<sva_seq_step_t>* chain = nullptr;  // LEAF only
      sva_stree_t* a = nullptr;
      sva_stree_t* b = nullptr;
      PExpr* gexpr = nullptr;    // SEQ_THROUGHOUT invariant (a = the seq)
      // SEQ_CONCAT: true for a ##0 b (the first tick of b is fused with
      // a's terminal tick), false for ##1-or-later continuation.
      bool concat_overlap = false;
};

// M9-7 residual: one further clock-flow segment past the first boundary
// (IEEE 1800-2017 16.13.1), e.g. the ` ##1 @(c3) c' in
//   @(c1) a ##1 @(c2) b ##1 @(c3) c
// `boundary' is the cycle-delay (0 or 1; -2 marks an illegal non-0/1
// delay) immediately BEFORE `clk_evt'; `chain' is the fixed-length
// boolean chain clocked by `clk_evt'. A property's `mc_more' list holds
// these in source order for every clock change after the second clock
// (the first is still carried by `seq_clk_evt'/`seq' below, unchanged,
// so a 2-domain property's representation and lowering are untouched).
struct sva_mc_seg_t {
      int boundary = -1;
      PEventStatement* clk_evt = nullptr;
      std::vector<sva_seq_step_t>* chain = nullptr;
};

struct sva_property_t {
      PEventStatement* clk_evt = nullptr;   // clocking event (may be null)
      // M9-NFA stage D.1: consequent clocking event for a multiclocked
      // implication `@(c1) a |=> @(c2) b' (IEEE 1800-2017 16.13.3). When
      // set, clk_evt clocks the antecedent and seq_clk_evt clocks the
      // consequent; the assertion is lowered by a race-free request/ack
      // counter handoff between the two clock domains.
      PEventStatement* seq_clk_evt = nullptr;
      // M9-7: sequence clock-flow boundary
      //   prefix ##0/##1 @(seq_clk_evt) seq
      // `mc_prefix' is evaluated on clk_evt before the boundary. It is
      // null for the direct implication forms
      //   antecedent |->/|=> @(seq_clk_evt) seq.
      // mc_boundary: 0 = nearest possibly-overlapping tick, 1 = nearest
      // strictly-subsequent tick, -1 = no explicit boundary metadata.
      std::vector<sva_seq_step_t>* mc_prefix = nullptr;
      int mc_boundary = -1;
      // M9-7 residual: further clock changes after `seq_clk_evt' chained
      // in source order (each element's clock differs from the one
      // before it, generally). Null/empty for every property with at
      // most one clock-flow boundary -- i.e. everything that worked
      // before this residual, unaffected. A dedicated N-domain lowering
      // (`pform_make_multiclock_chain_assertion_') handles a nonempty
      // list; the 2-domain `pform_make_multiclock_assertion_' is not
      // touched by it.
      std::vector<sva_mc_seg_t>* mc_more = nullptr;
      PExpr* disable_iff_expr = nullptr;    // disable iff expr (may be null)
      std::vector<sva_seq_step_t>* antecedent = nullptr;  // null for op 0
      std::vector<sva_seq_step_t>* seq = nullptr;         // consequent / plain sequence
      // A sequence combinator used as an implication antecedent cannot be
      // flattened without changing its match language. Keep it as a tree and
      // let the automaton implication builder compose it with `tree' (the
      // consequent). Null for ordinary flat implications and for standalone
      // combinator properties.
      sva_stree_t* ante_tree = nullptr;
      sva_stree_t* tree = nullptr;          // stage B combinator tree
					    // (seq/antecedent null when set)
      int tree_sorry = 0;                   // deferred no-NFA sorry text:
					    // 0 = or/and, 1 = intersect
      // M9-NFA stage C.2: sequence property strength (IEEE 1800-2017
      // 16.12.2). 0 = weak (the default for a sequence property: an
      // attempt still pending at end of simulation neither fails nor
      // succeeds); 1 = strong (`strong(seq)': a pending attempt at end of
      // simulation is a FAILURE). Automaton-engine-only.
      int strength = 0;
      // 0=plain sequence, 1=|->, 2=|=>; 4..17 the temporal/liveness/
      // abort operators (see pform_make_temporal_assertion_).
      // IEEE 1800-2017 A.2.10 makes an implication CONSEQUENT a full
      // property_expr. Recursive consequents are contextualized by
      // pform_sva_paren_conseq: ordinary/nested implications become a
      // composite automaton, while safety properties become a forbidden-
      // sequence automaton. 18/19 retain the compact s_eventually lowering.
      int op_type = 0;
      // The implication consequence is a forbidden sequence: accepting it
      // is a property failure, while its death after the antecedent matched
      // discharges the obligation. This is the exact automaton dual used by
      // `a |-> not(s)', `a |-> always p', and the `until' family.
      bool forbidden_consequent = false;
      // IEEE 1800-2017 16.12.2/16.12.5: bounded liveness window for the
      // unary liveness ops (nexttime[n]/s_nexttime[n]: win_lo==win_hi==n;
      // s_eventually[m:n]/eventually[m:n]: win_lo==m, win_hi==n). -1 on
      // both means "no explicit window" (the plain unbounded/next-cycle
      // form the existing lowering already handles).
      long win_lo = -1;
      long win_hi = -1;
      // IEEE 1800-2017 16.12.9: abort operators (accept_on/reject_on and
      // their sync_ variants, op_type 14..17). abort_cond is the abort
      // condition expression; null for every non-abort op.
      PExpr* abort_cond = nullptr;
};

/*
 * M9-3: one branch of a `case (expr) ... endcase' property (IEEE
 * 1800-2017 16.12.8). vals is the match-expression list (null marks the
 * `default' branch); prop is the branch property. The parser collects a
 * list of these and pform_sva_case() folds them into a boolean property.
 */
struct sva_prop_case_item_t {
      std::list<PExpr*>* vals = nullptr;   // null => default branch
      sva_property_t* prop = nullptr;
};

/*
 * The vlltype supports the passing of detailed source file location
 * information between the lexical analyzer and the parser. Defining
 * YYLTYPE compels the lexor to use this type and not something other.
 */
struct vlltype {
      int first_line;
      int first_column;
      int last_line;
      int last_column;
      unsigned lexical_pos;
      const char*text;
      std::string get_fileline() const;
};
# define YYLTYPE struct vlltype

class LineInfo;
inline void FILE_NAME(LineInfo*tmp, const struct vlltype&where)
{
      tmp->set_lineno(where.first_line);
      tmp->set_file(filename_strings.make(where.text));
}

/*
 * One `data_type name = expression' clause of a for_initialization
 * list. IEEE 1800-2017 12.7.1 allows several of these separated by
 * commas, each carrying its own data type:
 *
 *    for (int i = 0, state_e s = s.first(); i < s.num(); i += 1, s = s.next())
 *
 * The parser collects the clauses and the loop rule turns them into
 * declarations plus ordered initializing assignments inside the
 * synthetic block that already wraps a declaring for loop.
 */
class data_type_t;
class PExpr;
struct for_var_decl_t {
      data_type_t*type;
      char*name;
      PExpr*init;
      YYLTYPE loc;
};

  /* This for compatibility with new and older bison versions. */
#ifndef yylloc
# define yylloc VLlloc
#endif
extern YYLTYPE yylloc;

/*
 * Interface into the lexical analyzer. ...
 */
extern int  VLlex();
extern void VLerror(const char*msg);
extern void VLerror(const YYLTYPE&loc, const char*msg, ...) __attribute__((format(printf,2,3)));
#define yywarn VLwarn
extern void VLwarn(const char*msg);
extern void VLwarn(const YYLTYPE&loc, const char*msg);

extern void destroy_lexor();
extern void reset_parser_file_state(void);

extern std::ostream& operator << (std::ostream&, const YYLTYPE&loc);

extern unsigned error_count, warn_count;
extern unsigned long based_size;

extern bool in_celldefine;
enum UCDriveType { UCD_NONE, UCD_PULL0, UCD_PULL1 };
extern UCDriveType uc_drive;

/*
 * The parser signals back to the lexor that the next identifier
 * should be in the package scope. For example, if the source is
 *    <package> :: <foo>
 * Then the parser calls this function to set the package context so
 * that the lexor can interpret <foo> in the package context.
 */
extern void lex_in_package_scope(PPackage*pkg);

/*
 * Test if this identifier is a type identifier in the current
 * context. The pform code needs to help the lexor here because the
 * parser detects typedefs and marks the typedef'ed identifiers as
 * type names.
 */
extern typedef_t* pform_test_type_identifier(const YYLTYPE&loc, const char*txt);
extern typedef_t* pform_test_type_identifier(PPackage*pkg, const char*txt);

/*
 * Test if this identifier is a package name. The pform needs to help
 * the lexor here because the parser detects packages and saves them.
 */
extern PPackage* pform_test_package_identifier(const char*txt);

/*
 * Export these functions because we have to generate PENumber class
 * in pform.cc for user defparam definition from command file.
 */
extern verinum*make_unsized_dec(const char*txt);
extern verinum*make_undef_highz_dec(const char*txt);
extern verinum*make_unsized_binary(const char*txt);
extern verinum*make_unsized_octal(const char*txt);
extern verinum*make_unsized_hex(const char*txt);

extern char* strdupnew(char const *str);

#endif /* IVL_parse_misc_H */

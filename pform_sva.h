#ifndef IVL_pform_sva_H
#define IVL_pform_sva_H
/*
 * Copyright (c) 2026 Stephen Williams (steve@icarus.com)
 *
 *    This source code is free software; you can redistribute it
 *    and/or modify it in source code form under the terms of the GNU
 *    Library General Public License as published by the Free Software
 *    Foundation; either version 2 of the License, or (at your option)
 *    any later version.
 */

# include "StringHeap.h"
# include <vector>

class PExpr;
class Statement;

enum pform_sva_sample_kind {
      SVA_SAMPLE_PAST,
      SVA_SAMPLE_ROSE,
      SVA_SAMPLE_FELL,
      SVA_SAMPLE_STABLE,
      SVA_SAMPLE_CHANGED
};

struct pform_sva_capture_t {
      perm_string reg_name;
      PExpr*      captured_expr;
      unsigned    line;
      const char* file;
};

extern void pform_sva_rewrite_sampling(PExpr*&expr,
                                       std::vector<pform_sva_capture_t>&caps);

extern void pform_sva_emit_captures(const std::vector<pform_sva_capture_t>&caps,
                                    std::vector<Statement*>&stmts);

// S4: build the body for an `A ##N B` (op_type==3) assertion.
// Synthesizes a length-N shift register that captures A at each clock and
// fires `fail` when the shifted-out cell is 1 and B is false at cycle T+N.
//
// Returns the body statement (a PBlock containing check + shift NBA), or
// nullptr if N is out of range.  Caller is responsible for splicing into
// the always block (and for handling captures from S2 if any).
class Statement;
class PExpr;
struct sva_property_t;
extern Statement* pform_sva_build_seq_delay(PExpr*ant, PExpr*cons,
                                            unsigned n_cyc,
                                            Statement*fail,
                                            unsigned line, const char*file);

// S3: register a named `sequence ID; ...; endsequence` or
// `property ID; ...; endproperty` declaration.  The body is stored
// for later inline-substitution.  Re-registration with the same name
// is a hard error.
extern void pform_sva_register_named_property(perm_string name,
                                              sva_property_t*body);

// Look up a named sequence/property; returns the stored body (which
// the caller takes ownership of) or nullptr if no such name was
// registered or the name has already been consumed.  Marks the
// stored entry as consumed so a second use produces nullptr.
extern sva_property_t* pform_sva_take_named_property(perm_string name);

#endif /* IVL_pform_sva_H */

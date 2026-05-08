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

#endif /* IVL_pform_sva_H */

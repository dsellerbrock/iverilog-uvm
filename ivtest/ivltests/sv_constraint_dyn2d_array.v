// IEEE 1800-2017/2023 18.4, 18.5.8, 7.5: a rand dynamic array of dynamic arrays.
// The outer size is solved first, then the size of every row, then the elements
// (18.5.8.2). The shape is OpenTitan adc_ctrl's `rand adc_ctrl_filter_cfg_t
// filter_cfg[][]': packed-struct elements wider than 64 bits, rows sized by
// `foreach (f[ch]) f[ch].size == N', element ranges, a constant-row reference
// (`f[0][i]'), and a soft default taken from a package const dynamic array.
// Before the fix, the full shape was rejected and randomize() failed.
package adc_defaults_pkg;
  typedef enum bit { COND_IN = 0, COND_OUT = 1 } cond_e;
  typedef struct packed { cond_e cond; int min_v; int max_v; bit en; } fcfg_t; // 66 bits
  const fcfg_t DEF[] = '{
    '{cond: COND_IN,  min_v: 5,   max_v: 99,  en: 1'b1},
    '{cond: COND_OUT, min_v: -3,  max_v: 7,   en: 1'b0},
    '{cond: COND_IN,  min_v: 100, max_v: 200, en: 1'b1},
    '{cond: COND_OUT, min_v: 0,   max_v: 999, en: 1'b1}
  };
endpackage
import adc_defaults_pkg::*;

module main;
  localparam int ROWS = 2;
  localparam int COLS = 4;
  localparam int MAXV = 1000;
  class base_cfg;
    rand fcfg_t f[][];
    rand bit mode;
    constraint size_c { f.size == ROWS; foreach (f[ch]) f[ch].size == COLS; }
  endclass

  class range_cfg extends base_cfg;
    constraint range_c {
      solve mode before f;
      foreach (f[ch]) {
        foreach (f[ch][i]) {
          f[ch][i].en == mode;
          f[ch][i].min_v inside {[0:MAXV]};
          f[ch][i].max_v inside {[0:MAXV]};
          f[ch][i].max_v >= f[ch][i].min_v;
          if (ch > 0) {
            (f[ch][i].min_v - f[0][i].min_v) inside {[-16:16]};
            f[ch][i].cond == f[0][i].cond;
          }
        }
      }
    }
  endclass

  class range_graph_owner;
    rand range_cfg cfg;
    function new; cfg = new; endfunction
  endclass

  class soft_cfg extends base_cfg;
    constraint default_c { foreach (f[ch, i]) soft f[ch][i] == DEF[i]; }
  endclass

  class row_resize_cfg;
    rand fcfg_t f[][];
    constraint c {
      f.size == 2;
      foreach (f[ch]) if (ch == 0) f[ch].size == 2; else f[ch].size == 0;
      f[0][0].min_v == 90;
    }
  endclass

  class row_conflict_cfg;
    rand fcfg_t f[][];
    constraint c {
      f.size == 2;
      foreach (f[ch]) if (ch == 0) { f[ch].size == 2; f[ch].size == 3; }
                      else f[ch].size == 1;
    }
  endclass

  class var_cfg;
    rand int unsigned rows;
    rand bit [7:0] g[][];
    constraint c {
      rows inside {[1:4]};
      g.size == rows;
      foreach (g[r]) g[r].size == r + 2;
      foreach (g[r, k]) g[r][k] == r * 16 + k;
    }
  endclass

  int errors;

  initial begin
    range_cfg rc;
    range_graph_owner graph_rc;
    soft_cfg sc;
    var_cfg vc;
    row_resize_cfg rg;
    row_conflict_cfg rb;
    rc = new; graph_rc = new; sc = new; vc = new; rg = new; rb = new;

    if (!graph_rc.randomize()) begin
      $display("FAILED graph range randomize"); errors++;
    end else if (graph_rc.cfg.f.size() !== ROWS ||
                 graph_rc.cfg.f[0].size() !== COLS ||
                 graph_rc.cfg.f[1].size() !== COLS) begin
      $display("FAILED graph nested-array shape"); errors++;
    end

    rg.f = new[1]; rg.f[0] = new[1]; rg.f[0][0].min_v = 90;
    if (!rg.randomize()) begin $display("FAILED row resize randomize"); errors++; end
    else if (rg.f.size() != 2 || rg.f[0].size() != 2 || rg.f[1].size() != 0
             || rg.f[0][0].min_v != 90) begin
      $display("FAILED row resize/size/element result"); errors++;
    end

    rb.f = new[2]; rb.f[0] = new[1]; rb.f[1] = new[1];
    rb.f[0][0].min_v = 31; rb.f[1][0].min_v = 72;
    if (rb.randomize()) begin $display("FAILED contradictory row size accepted"); errors++; end
    else if (rb.f.size() != 2 || rb.f[0].size() != 1 || rb.f[1].size() != 1
             || rb.f[0][0].min_v != 31 || rb.f[1][0].min_v != 72) begin
      $display("FAILED contradictory row size rollback"); errors++;
    end

    for (int t = 0; t < 5; t++) begin
      if (!rc.randomize()) begin $display("FAILED range randomize"); errors++; end
      else begin
        if (rc.f.size() !== ROWS) begin $display("FAILED outer size %0d", rc.f.size()); errors++; end
        foreach (rc.f[ch]) begin
          if (rc.f[ch].size() !== COLS) begin $display("FAILED row %0d size %0d", ch, rc.f[ch].size()); errors++; end
          foreach (rc.f[ch][i]) begin
            if (rc.f[ch][i].min_v < 0 || rc.f[ch][i].max_v > MAXV
                || rc.f[ch][i].max_v < rc.f[ch][i].min_v) begin
              $display("FAILED range [%0d] [%0d]: %0d..%0d", ch, i, rc.f[ch][i].min_v, rc.f[ch][i].max_v); errors++;
            end
            if (ch > 0 && ((rc.f[ch][i].min_v - rc.f[0][i].min_v) > 16
                           || (rc.f[ch][i].min_v - rc.f[0][i].min_v) < -16
                           || rc.f[ch][i].cond !== rc.f[0][i].cond)) begin
              $display("FAILED cross-row [%0d] [%0d]", ch, i); errors++;
            end
          end
        end
      end
    end

    if (!sc.randomize()) begin $display("FAILED soft randomize"); errors++; end
    else foreach (sc.f[ch, i])
      if (sc.f[ch][i] !== DEF[i]) begin $display("FAILED soft default [%0d][%0d]", ch, i); errors++; end

    for (int t = 0; t < 8; t++) begin
      if (!vc.randomize()) begin $display("FAILED var randomize"); errors++; end
      else begin
        if (vc.g.size() !== vc.rows) begin $display("FAILED var outer %0d vs %0d", vc.g.size(), vc.rows); errors++; end
        foreach (vc.g[r]) begin
          if (vc.g[r].size() !== r + 2) begin $display("FAILED var row %0d size %0d", r, vc.g[r].size()); errors++; end
          foreach (vc.g[r][k])
            if (vc.g[r][k] !== r * 16 + k) begin $display("FAILED var element [%0d][%0d]=%0d", r, k, vc.g[r][k]); errors++; end
        end
      end
    end
    if (errors == 0) $display("PASSED");
  end
endmodule

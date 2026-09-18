// DD-043: a constraint `foreach' selected prefix (IEEE 1800-2017/2023
// 12.7.3 / 18.5.8) into a plain (not class/struct-member) multi-
// dimensional array had no UNDOTTED grammar form -- only the plain
// single-bracket form and the DOTTED hierarchical-member form
// (`arr[id].member[loopvars]') existed. `foreach (filter_cfg[channel]
// [filter])' (no `.member' between the brackets: `channel' selects one
// element of `filter_cfg' along its first dimension, `filter' iterates
// the remaining dimension) hit a raw `syntax error' -- confirmed against
// real, unmodified OpenTitan DV source
// (hw/ip/adc_ctrl/dv/env/adc_ctrl_env_cfg.sv:118-122).
//
// This is a real, discriminating-population runtime check: the
// constraint value depends on BOTH the outer (prefix-selected) and inner
// (freshly iterated) loop variables, producing 12 distinct values across
// 3 channels x 4 filters. If the selector prefix were dropped (as
// happened for the analogous plain-statement-foreach bug, DD-040) or the
// dimension offset were wrong, this would either fail to compile, crash,
// or produce systematically wrong values -- not just "does it parse".
class filter_cfg_c;
  rand int filter_cfg[3][4];
  constraint c1 {
    foreach (filter_cfg[channel]) {
      foreach (filter_cfg[channel][filter]) {
        filter_cfg[channel][filter] == channel * 100 + filter;
      }
    }
  }
endclass

module main;
  int fails;
  initial begin
    filter_cfg_c c;
    c = new;
    if (!c.randomize()) begin
      $display("FAILED, randomize() returned 0");
      $finish;
    end
    for (int ch = 0; ch < 3; ch++) begin
      for (int f = 0; f < 4; f++) begin
        int want;
        want = ch * 100 + f;
        if (c.filter_cfg[ch][f] != want) begin
          fails++;
          $display("MISMATCH ch=%0d f=%0d got=%0d want=%0d",
                    ch, f, c.filter_cfg[ch][f], want);
        end
      end
    end
    if (fails == 0) $display("PASSED");
    else $display("FAILED, fails=%0d", fails);
    $finish;
  end
endmodule

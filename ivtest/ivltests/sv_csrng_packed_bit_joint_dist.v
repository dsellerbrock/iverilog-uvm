// Minimal CSRNG cfg shape: a packed foreach bit-select distribution while
// randomizing a parent that owns a randomized child object.
class csrng_bit_leaf;
  rand bit seen;
endclass

class csrng_bit_root;
  rand csrng_bit_leaf child;
  rand bit [2:0] read_enable;
  int unsigned one_pct;

  function new;
    child = new;
  endfunction

  constraint read_enable_c {
    foreach (read_enable[i])
      read_enable[i] dist {1'b1 :/ one_pct,
                           1'b0 :/ (100 - one_pct)};
    child.seen == read_enable[0];
  }
endclass

class csrng_whole_root;
  rand csrng_bit_leaf child;
  rand bit [2:0] read_enable;

  function new;
    child = new;
  endfunction

  constraint read_enable_c {
    read_enable dist {3'b111 :/ 1, 3'b000 :/ 0};
    child.seen == read_enable[0];
  }
endclass

module csrng_packed_bit_joint_dist_repro;
  initial begin
    csrng_whole_root control;
    csrng_bit_root cfg;
    int bit_ones[3];
    int mixed_count;
    control = new;
    cfg = new;
    mixed_count = 0;
    for (int i = 0; i < 3; i++) bit_ones[i] = 0;

    if (!control.randomize() || control.read_enable !== 3'b111 ||
        control.child.seen !== 1'b1)
      $fatal(1, "whole-vector joint-dist control failed");

    cfg.one_pct = 100;
    if (!cfg.randomize() || cfg.read_enable !== 3'b111 ||
        cfg.child.seen !== 1'b1)
      $fatal(1, "packed bit-select joint-dist all-one failed");

    cfg.one_pct = 0;
    if (!cfg.randomize() || cfg.read_enable !== 3'b000 ||
        cfg.child.seen !== 1'b0)
      $fatal(1, "packed bit-select joint-dist all-zero failed");

    cfg.srandom(32'h4353524e);
    cfg.child.srandom(32'h4353524f);
    cfg.one_pct = 75;
    repeat (128) begin
      if (!cfg.randomize() || cfg.child.seen !== cfg.read_enable[0])
        $fatal(1, "packed bit-select joint-dist weighted solve failed");
      for (int i = 0; i < 3; i++) bit_ones[i] += cfg.read_enable[i];
      if (cfg.read_enable != 3'b000 && cfg.read_enable != 3'b111)
        mixed_count++;
    end
    for (int i = 0; i < 3; i++)
      if (bit_ones[i] < 76 || bit_ones[i] > 116)
        $fatal(1, "packed bit-select weight lost at bit %0d: %0d/128",
               i, bit_ones[i]);
    if (mixed_count < 45 || mixed_count > 100)
      $fatal(1, "packed bit-select bits lost independence: %0d/128 mixed",
             mixed_count);

    $display("PASS CSRNG packed bit-select joint dist");
  end
endmodule

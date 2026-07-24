// M12-7: covergroup drill-down through VPI — iterate coverpoints and
// crosses of a covergroup object, then each item's value bins, with
// per-instance and type-merged hit counts, at_least/weight metadata,
// and per-item instance coverage. Covers a standalone covergroup
// variable and a class-embedded covergroup reached through a nested
// member handle.
module top;
  bit [1:0] a; bit b;
  covergroup cg;
    cp_a: coverpoint a { option.weight = 3; option.at_least = 2;
                         bins x[] = {0,1,2,3}; }
    cp_b: coverpoint b { bins y[] = {0,1}; }
    axb: cross cp_a, cp_b;
  endgroup
  cg c1 = new;
  cg c2 = new;

  class Wrap;
    bit [1:0] v;
    covergroup wcg;
      cp_v: coverpoint v { bins w[] = {0,1,2,3}; }
    endgroup
    function new; wcg = new; endfunction
  endclass
  Wrap wr = new;

  initial begin
    a = 0; b = 0; c1.sample();
    a = 0; b = 1; c1.sample();   // cp_a bin0 count 2 (>= at_least)
    a = 1; b = 0; c1.sample();   // cp_a bin1 count 1 (below at_least 2)
    a = 3; b = 1; c2.sample();   // second instance: type-merge only
    wr.v = 2; wr.wcg.sample();
    $m12cd_probe;
    $finish(0);
  end
endmodule

// dist_test.sv - verify `dist` weighted constraint parses and randomize
//                doesn't crash. The actual distribution is NOT yet
//                enforced (Phase 8 work), but compile/run progresses.

class C;
  rand int x;
  // Weighted distribution: 60% [1:5], 40% == 6
  constraint c_dist { x dist {[1:5]:=60, 6:=40}; }
  // Soft variant
  constraint c_soft { soft x dist {[1:10]:=70, [11:20]:=30}; }
endclass

module top;
  initial begin
    C c = new;
    int ok = 0;
    for (int i = 0; i < 10; i++) begin
      if (c.randomize() == 1) ok++;
    end
    if (ok == 10) $display("PASS dist constraint parses, randomize succeeds %0d/10", ok);
    else          $display("FAIL only %0d/10 randomize calls succeeded", ok);
    $finish;
  end
endmodule

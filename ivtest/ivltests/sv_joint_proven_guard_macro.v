class proven_macro_leaf;
  rand bit [7:0] code;
  constraint c {
    if (8'hD3 > 8'h2C)
      code dist {8'hD3 := 9, 8'h2C := 1};
    else
      code dist {8'h77 := 1};
  }
endclass

class proven_macro_peer;
  rand bit [7:0] code;
endclass

class proven_macro_root;
  rand proven_macro_leaf a;
  rand proven_macro_peer b;
  constraint coupled_c {a.code == b.code;}
  function new(); a = new; b = new; endfunction
endclass

module sv_joint_proven_guard_macro;
  proven_macro_root root;
  int favored;
  initial begin
    root = new;
    for (int i = 0; i < 300; i++) begin
      if (!root.randomize()) $fatal(1, "constant-guard joint solve failed");
      if (root.a.code != root.b.code ||
          !(root.a.code inside {8'hD3, 8'h2C}))
        $fatal(1, "constant guard retained an inactive branch");
      if (root.a.code == 8'hD3) favored++;
    end
    if (favored < 240 || favored > 292)
      $fatal(1, "constant guarded dist lost its 9:1 weight: %0d/300", favored);
    $display("PASSED");
    $finish(0);
  end
endmodule

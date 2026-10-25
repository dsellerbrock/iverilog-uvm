module p05_lex;
  logic \bus+idx ; logic [7:0] u = 8'b1010_xz?0; logic signed [7:0] s = -8'sd3;
  logic [39:0] big = 'hFF_0000_0001; real r = 1.5e2;
  (* keep = 1, note = "x" *) logic attr_v = 1;
  string e = "a\tb\\c\"d\101\n";
  initial begin
    \bus+idx = 1'b1;
    $display("L1 %b %b", \bus+idx , u);         // 1 1010xzz0  (? is z)
    $display("L2 %0d %h", s, big);               // -3 ff00000001
    $display("L3 %0.1f %0d", r, e.len());        // 150.0 9
    $display("L4 %s", e);                        // a<TAB>b\c"dA<newline>
    /* outer /* not nested */ $display("L5 ok");
  end
endmodule

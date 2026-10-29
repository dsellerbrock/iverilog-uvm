module sv_assert_first_match_cut_isolation;
  bit clk, s, a, b, c, d, e;
  int fail_or, fail_two;
  localparam bit [31:0] S = 32'h00010101, A = 32'h00010101,
    C = 32'h00000101, B = 32'h00060202, D = 32'h00000004,
    E = 32'h00080000 | 32'h00000008;
  assert property (@(posedge clk) s |->
    ((first_match(a ##[1:2] b) ##1 e) or (c ##2 d ##1 e))) else fail_or++;
  assert property (@(posedge clk) s |->
    ((first_match(a ##[1:2] b) ##1 e) or (first_match(c ##[1:2] d) ##1 e)))
    else fail_two++;
  initial begin
    for (int i = 0; i < 24; i++) begin
      {s,a,b,c,d,e} = {S[i],A[i],B[i],C[i],D[i],E[i]};
      #5 clk = 1; #5 clk = 0;
    end
    if (fail_or != 2 || fail_two != 2)
      $fatal(1, "FAIL or=%0d two=%0d (want 2/2)", fail_or, fail_two);
    $display("PASS"); $finish(0);
  end
endmodule

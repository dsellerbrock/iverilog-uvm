module sv_assert_first_match_cut_entry_fixed;
  bit clk, s3, x, a, b, c, sr, ra, rb;
  int f3, frep;
  localparam bit [47:0]
    S3 = 48'h0000_0101,
    X  = 48'h0101_0101,
    A  = 48'h0101_0606_0606,
    B  = 48'h0206_0C0C_0C0C,
    C  = 48'h0101_0010_0010;
  assert property (@(posedge clk) s3 |-> x ##[1:2] first_match(a ##1 b) ##1 c)
    else f3++;
  assert property (@(posedge clk) sr |-> first_match(ra[*2] ##1 rb))
    else frep++;
  initial begin
    for (int i = 0; i < 48; i++) begin
      {s3,x} = {S3[i],X[i]};
      {a,b,c} = {A[i],B[i],C[i]};
      sr = (i == 40);
      ra = (i == 40 || i == 41);
      rb = (i == 42);
      #5 clk = 1; #5 clk = 0;
    end
    $display("f3=%0d frep=%0d (want 1/0)", f3, frep);
    if (f3 != 1 || frep != 0) $fatal(1, "FAIL");
    $display("PASS"); $finish(0);
  end
endmodule

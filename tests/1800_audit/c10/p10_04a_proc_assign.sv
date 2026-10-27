module p10_04a;
  int pass = 0, fail = 0;
  task automatic ck(input string id, input bit c);
    if (c) pass++; else begin fail++; $display("FAIL %s", id); end
  endtask
  logic a, b, c, d, e, f;  time ta, tb, tc, td, te, tf;
  logic sa, sb, oa, o6;  logic pa = 0, pb = 1, pc = 0;
  logic [7:0] rega, regb, mema [0:3];  logic carry;  logic [7:0] acc;  int ua [4];
  initial begin a = #10 1; ta = $time; b = #2 0; tb = $time; c = #4 1; tc = $time; end
  initial begin d <= #10 1; e <= #2 0; f <= #4 1; end
  always @(d) td = $time;  always @(e) te = $time;  always @(f) tf = $time;
  initial begin sa = 0; sb = 1; sa <= sb; sb <= sa; end
  initial begin oa <= #4 0; oa <= #4 1; end
  initial #8 o6 <= #8 1;
  initial #12 o6 <= #4 0;
  always #5 pc = ~pc;
  always @(posedge pc) begin pa <= pb; pb <= pa; end
  initial begin
    rega = 0; rega[3] = 1; rega[5:3] = 3'd7; mema[2] = 8'hff; regb = 8'h01; {carry, acc} = rega + regb;
    ua[1:2] = '{7, 8};
    #1 ck("nba_swap", sa == 1 && sb == 0);
    ck("lvalue_forms", rega == 8'h38 && mema[2] == 8'hff && acc == 8'h39 && carry == 0);
    ck("unpacked_slice_lhs", ua[1] == 7 && ua[2] == 8);
    #4 ck("nba_order_same_block", oa === 1'b1);
    #1 ck("nba_swap_posedge_1", pa == 1 && pb == 0);
    #11 ck("nba_order_cross_block", o6 === 1'b0);
    ck("nba_swap_posedge_2", pa == 0 && pb == 1);
    #3 ck("blocking_intra_delay", ta == 10 && tb == 12 && tc == 16);
    ck("nba_intra_delay", td == 10 && te == 2 && tf == 4);
    $display("RESULT pass=%0d fail=%0d", pass, fail);
    $finish;
  end
endmodule

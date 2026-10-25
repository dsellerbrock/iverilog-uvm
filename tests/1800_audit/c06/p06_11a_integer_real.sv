module p06_11a;
  int pass = 0, fail = 0;
  task automatic ck(input string id, input bit c);
    if (c) pass++; else begin fail++; $display("FAIL %s", id); end
  endtask
  shortint si; int ii; longint li; byte by; bit [3:0] b4; logic [3:0] l4; reg [3:0] r4; integer ig; time tm;
  int unsigned ui; int signed sg; int di; integer dg;
  real rv; shortreal sr; realtime rt; bit [7:0] b8; logic [7:0] l8 = 8'b1x0z1010;
  initial begin
    ck("widths", $bits(si) == 16 && $bits(ii) == 32 && $bits(li) == 64 && $bits(by) == 8 && $bits(ig) == 32 && $bits(tm) == 64);
    si = -1; ii = -1; li = -1; by = -1; ig = -1;
    ck("signed_default", si < 0 && ii < 0 && li < 0 && by < 0 && ig < 0);
    b4 = 4'hF; l4 = 4'hF; r4 = 4'hF; tm = 64'hFFFF_FFFF_FFFF_FFFF;
    ck("unsigned_default", b4 > 0 && l4 > 0 && r4 > 0 && tm > 0);
    ui = 32'hFFFF_FFFF; sg = 32'hFFFF_FFFF;
    ck("explicit_sign", ui > 0 && sg < 0);
    ck("defaults", di == 0 && dg === 32'bx);
    b8 = l8;  ck("x_to_zero", b8 == 8'b10001010);
    by = -2; ii = by;  ck("sign_ext", ii == -2);
    b8 = 8'hFE; ii = b8;  ck("zero_ext", ii == 254);
    ii = 32'h1234_5678; si = ii;  ck("trunc", si == 16'h5678);
    rv = 2.5; ii = rv;  ck("round_half_away", ii == 3);
    rv = -2.5; ii = rv;  ck("round_half_away_neg", ii == -3);
    rv = 2.4; ii = rv;  ck("round_down", ii == 2);
    rv = 2.6; ii = rv;  ck("round_up", ii == 3);
    rv = 7; ck("int_to_real", rv == 7.0);
    l4 = 4'b1x0z; rv = l4;  ck("xz_to_zero_real", rv == 8.0);
    ck("real_relational_1bit", $bits(rv > 1.0) == 1 && (rv > 1.0));
    sr = 1.5;  ck("shortreal", sr == 1.5);
    rt = 3.25; rv = rt;  ck("realtime_synonym", rv == 3.25);
    $display("INFO bits_real=%0d bits_shortreal=%0d", $bits(rv), $bits(sr));
    $display("RESULT pass=%0d fail=%0d", pass, fail);
  end
endmodule

module p11_04a;
  int pass = 0, fail = 0;
  task automatic ck(input string id, input bit c);
    if (c) pass++; else begin fail++; $display("FAIL %s", id); end
  endtask
  integer intS, a, b, c;  var logic [15:0] U;  var logic signed [15:0] S;
  int k, x, n, cnt = 0, idx = 0;  int arr [3];  real rr;  byte bb;  int ii;  logic [3:0] xz = 4'b1x01, r4;
  function logic sc(); cnt++; return 1; endfunction
  function int nx(); idx++; return idx - 1; endfunction
  initial begin
    ck("mod", 10 % 3 == 1 && 11 % 3 == 2 && 12 % 3 == 0 && -10 % 3 == -1 && 11 % -3 == 2);
    ck("mod_unsigned", -4'd12 % 3 == 1);
    ck("pow_int", 3 ** 2 == 9 && 2 ** 3 == 8 && 2 ** 0 == 1 && 0 ** 0 == 1);
    ck("pow_real", 2.0 ** -3'sb1 == 0.5 && 9 ** 0.5 == 3.0 && 9.0 ** (1/2) == 1.0 && -3.0 ** 2.0 == 9.0);
    ck("pow_int_neg_exp", (2 ** -3'sb1) == 0);
    ck("pow_zero_neg_x", $isunknown(0 ** -1));
    ck("pow_table", (-1) ** 3 == -1 && (-1) ** 2 == 1 && (-1) ** -3 == -1 && (-1) ** -2 == 1 && 2 ** -1 == 0 && (-2) ** -1 == 0 && 1 ** -5 == 1 && 0 ** 3 == 0);
    ck("div_trunc", 7 / 2 == 3 && -7 / 2 == -3);
    ck("div_zero_x", $isunknown(5 / 0) && $isunknown(5 % 0));
    r4 = xz + 1;  ck("arith_x", r4 === 4'bxxxx);
    intS = -4'd12; U = intS / 3;  ck("sg1", U == 65532);
    U = -4'd12;  ck("sg_u", U == 65524);
    intS = U / 3;  ck("sg2", intS == 21841);
    intS = -4'd12 / 3;  ck("sg3", intS == 1431655761);
    U = -12 / 3;  ck("sg4", U == 65532);
    S = -12 / 3;  ck("sg5", S == -4);
    S = -4'sd12 / 3;  ck("sg6", S == 1);
    k = 5;  ck("postinc", k++ == 5 && k == 6);
    ck("preinc", ++k == 7);
    ck("postdec", k-- == 7 && k == 6);
    ck("predec", --k == 5);
    rr = 1.5; rr++;  ck("real_inc", rr == 2.5);
    x = 12; x += 3; x -= 1; x *= 2; x /= 4; x %= 4; x &= 2; x |= 5; x ^= 3; x <<= 2; x >>= 1; x <<<= 1; x >>>= 2;
    ck("assign_ops", x == 4);
    n = -16; n >>>= 2;  ck("arith_shift_assign", n == -4);
    arr[nx()] += 2;  ck("lhs_index_once", idx == 1 && arr[0] == 2);
    cnt = 0; a = 0 && sc(); a = 1 || sc(); a = 0 -> sc(); a = 1 ? 1 : sc();  ck("short_circuit", cnt == 0);
    a = 0 & sc();  ck("no_short_circuit_bitwise", cnt == 1);
    a = (b = (c = 5));  ck("assign_in_expr", a == 5 && b == 5 && c == 5);
    ii = (bb = 300);  ck("assign_expr_type", ii == 44);
    $display("RESULT pass=%0d fail=%0d", pass, fail);
  end
endmodule

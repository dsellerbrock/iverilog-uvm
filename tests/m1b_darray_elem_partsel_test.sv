// M1B (Phase 4): assignment to a bit/part-select of a dynamic-array or
// queue element whose base type is a packed vector, e.g. d[i][b] = v and
// q[i][m:l] = v. Previously the bit index was silently dropped (writing the
// whole element) for darrays, and a part-select crashed the compiler with
// an assertion. Both now lower to a correct read-modify-write, including
// elements with a non-zero-based packed range.
module m1b_darray_elem_partsel_test;
  int         d[];
  bit  [7:0]  q[];
  logic [15:8] r[];   // non-zero-based element range
  bit  [7:0]  qq[$];  // queue of vectors
  int errors = 0;

  task check(string nm, int got, int exp);
    if (got !== exp) begin
      $display("FAIL %s: got %0d exp %0d", nm, got, exp);
      errors++;
    end
  endtask

  initial begin
    d = new[4];
    q = new[4];
    r = new[2];

    d[1] = 0;      d[1][3]     = 1'b1;        // set bit 3 -> 8
    check("d[1][3]", d[1], 8);

    q[2] = 8'h00;  q[2][5:2]   = 4'hA;        // bits 5..2 = 1010 -> 0x28
    check("q[2][5:2]", q[2], 8'h28);

    r[0] = '0;     r[0][10]    = 1'b1;        // bit 10 of [15:8] -> offset 2 -> 0x04
    check("r[0][10]", r[0], 8'h04);

    r[1] = '0;     r[1][13:11] = 3'b101;      // offset 3, width 3 -> 0x28
    check("r[1][13:11]", r[1], 8'h28);

    qq.push_back(8'h00);
    qq[0][5:2] = 4'hA;                        // queue element part-select -> 0x28
    check("qq[0][5:2]", qq[0], 8'h28);

    if (errors == 0) $display("PASS m1b_darray_elem_partsel_test");
    else             $display("FAIL m1b_darray_elem_partsel_test (%0d errors)", errors);
    $finish;
  end
endmodule

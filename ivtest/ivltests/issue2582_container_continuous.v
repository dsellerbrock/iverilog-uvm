// Issue #2582: a continuous assignment whose right-hand side reads a queue,
// dynamic array, associative array or string (IEEE 1800-2017/2023 10.3:
// any expression, re-evaluated when an operand changes). Also the implicit
// sensitivity of always_comb for a constant-index element of a queue.
module test;
  int q[$]; int d[]; int aa[int] = '{1:0}; string s;
  int qs, q0, dz, d0, an, a1, sl;
  logic [7:0] s0;
  wire [31:0] wq0;
  int cq0;
  bit failed = 0;

  assign qs = q.size();
  assign q0 = q[0];
  assign wq0 = q[0];
  assign dz = $size(d);
  assign d0 = d[0];
  assign an = aa.num();
  assign a1 = aa[1];
  assign sl = s.len();
  assign s0 = s[0];
  always_comb cq0 = q[0];

  task check(input string tag, input int eqs, eq0, edz, ed0, ean, ea1, esl,
             input logic [7:0] es0);
    if (qs !== eqs || q0 !== eq0 || wq0 !== eq0 || cq0 !== eq0 || dz !== edz
        || d0 !== ed0 || an !== ean || a1 !== ea1 || sl !== esl || s0 !== es0) begin
      $display("FAILED %s: qs=%0d q0=%0d wq0=%0d cq0=%0d dz=%0d d0=%0d an=%0d a1=%0d sl=%0d s0=%h",
               tag, qs, q0, wq0, cq0, dz, d0, an, a1, sl, s0);
      failed = 1;
    end
  endtask

  initial begin
    #1 check("t1", 0, 0, 0, 0, 1, 0, 0, 8'h00);
    q.push_back(5); d = new[2]; aa[1] = 11; s = "ab";
    #1 check("t2", 1, 5, 2, 0, 1, 11, 2, "a");
    q[0] = 9; d[0] = 4; aa[2] = 22; s = "xyz";
    #1 check("t3", 1, 9, 2, 4, 2, 11, 3, "x");
    d = new[5](d); aa.delete(2); aa[1] = 7; q.push_front(3);
    #1 check("t4", 2, 3, 5, 4, 1, 7, 3, "x");
    q.delete(); d.delete(); s = "";
    #1 check("t5", 0, 0, 0, 0, 1, 7, 0, 8'h00);
    if (!failed) $display("PASSED");
  end
endmodule

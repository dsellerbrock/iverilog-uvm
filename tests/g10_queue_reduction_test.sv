// G10: queue reduction methods — sum, product, and, or, xor, min, max
`timescale 1ns/1ps

module top;
  initial begin
    int q[$] = '{1, 2, 3, 4, 5};
    int s, p;
    int mn[$], mx[$];
    int fail = 0;

    s = q.sum();
    if (s !== 15) begin
      $display("FAIL q.sum: got %0d, expected 15", s);
      fail = 1;
    end

    p = q.product();
    if (p !== 120) begin
      $display("FAIL q.product: got %0d, expected 120", p);
      fail = 1;
    end

    mn = q.min();
    if (mn.size() !== 1 || mn[0] !== 1) begin
      $display("FAIL q.min: got size=%0d val=%0d, expected size=1 val=1", mn.size(), mn[0]);
      fail = 1;
    end

    mx = q.max();
    if (mx.size() !== 1 || mx[0] !== 5) begin
      $display("FAIL q.max: got size=%0d val=%0d, expected size=1 val=5", mx.size(), mx[0]);
      fail = 1;
    end

    if (!fail)
      $display("PASS: G10 queue reduction methods (sum=%0d product=%0d min=%0d max=%0d)",
               s, p, mn[0], mx[0]);
    $finish;
  end
endmodule

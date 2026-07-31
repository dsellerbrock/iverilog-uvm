// Run-time index in a leading packed dimension with a part-select tail.
// Every result is checked against the identical shape reached through a
// struct member, which already took the canonical-offset path.
module top;

  typedef struct packed { logic [3:0][63:0] d; } wrap_t;

  logic [3:0][63:0] d;
  logic [0:3][0:63] a;   // ascending in both dimensions
  wrap_t s;

  int errors = 0;
  int i, b;

  task check(input string tag, input [63:0] got, input [63:0] exp);
    if (got !== exp) begin
      $display("FAIL %0s: got %h expected %h", tag, got, exp);
      errors = errors + 1;
    end
  endtask

  initial begin
    for (int k = 0; k < 4; k++) begin
      d[k] = 64'h1122_3344_5566_7788 + (k * 64'h0101_0101_0101_0101);
      a[k] = 64'h1122_3344_5566_7788 + (k * 64'h0101_0101_0101_0101);
    end
    s.d = d;

    // ---- r-value: constant part tail over a run-time element index ----
    for (i = 0; i < 4; i++) begin
      check("lo32",  {32'h0, d[i][31:0]},  {32'h0, s.d[i][31:0]});
      check("hi32",  {32'h0, d[i][63:32]}, {32'h0, s.d[i][63:32]});
      check("mid",   {48'h0, d[i][39:24]}, {48'h0, s.d[i][39:24]});
      // absolute value, not just agreement with the struct path
      check("lo32abs", {32'h0, d[i][31:0]},
            {32'h0, 32'h5566_7788 + (i * 32'h0101_0101)});
    end

    // ---- r-value: indexed part tail, run-time base ----
    for (i = 0; i < 4; i++)
      for (b = 0; b <= 56; b = b + 8) begin
        check("idxup", {56'h0, d[i][b +: 8]}, {56'h0, s.d[i][b +: 8]});
        check("idxdo", {56'h0, d[i][(b+7) -: 8]}, {56'h0, s.d[i][(b+7) -: 8]});
      end

    // ---- ascending declared ranges ----
    for (i = 0; i < 4; i++) begin
      check("asc32", {32'h0, a[i][0:31]}, {32'h0, d[i][63:32]});
      check("ascup", {56'h0, a[i][8 +: 8]}, {56'h0, d[i][55 -: 8]});
    end

    // ---- l-value: same shape on the left ----
    for (i = 0; i < 4; i++) begin
      d[i][31:0] = 32'hDEAD_0000 + i;
      check("lval", d[i], {32'h1122_3344 + (i * 32'h0101_0101),
                           32'hDEAD_0000 + i});
    end
    for (i = 0; i < 4; i++) begin
      d[i][8 +: 8] = 8'hA5;
      check("lvalup", {56'h0, d[i][15:8]}, {56'h0, 8'hA5});
      check("lvalup_keep", {56'h0, d[i][7:0]},
            {56'h0, 8'h00 + i[7:0]});
    end

    if (errors == 0) $display("PASSED");
    else $display("FAILED with %0d errors", errors);
  end

endmodule

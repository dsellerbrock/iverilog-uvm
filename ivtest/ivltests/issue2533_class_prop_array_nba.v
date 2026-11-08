// Issue #2533: a nonblocking assignment to an element (or a select of an
// element) of an unpacked-array class property with a run-time index.
// IEEE 1800-2017/2023 10.4.2: the index and select expressions are
// evaluated when the statement executes; the update is scheduled for the
// NBA region. 7.4.6: a write to an invalid index has no effect.
module test;
  class holder;
    logic [3:0][7:0] data [4];
    logic [1:0][7:0] v [2];
    logic [7:0] m [2][3];
  endclass

  holder h;
  int i;
  integer j;
  bit failed = 0;

  task check(input logic [31:0] got, input logic [31:0] exp, input string what);
    if (got !== exp) begin
      $display("FAILED: %s = %h, expected %h", what, got, exp);
      failed = 1;
    end
  endtask

  initial begin
    h = new;
    foreach (h.data[k]) h.data[k] = '0;
    h.v[0] = '0; h.v[1] = '0;

    // The case from the issue.
    i = 2;
    h.data[i][1][7:0] <= 8'hAA;
    check(h.data[2], 32'h0, "data[2] before NBA");
    #1 check(h.data[2], 32'h0000aa00, "data[2]");

    // Whole element, packed sub-select and dynamic part select.
    i = 1;
    h.v[i] <= 16'h1234;
    #1 check(h.v[1], 16'h1234, "v[1] whole");
    h.v[i][1] <= 8'h56; h.v[i][0][3:0] <= 4'h7;
    #1 check(h.v[1], 16'h5637, "v[1] selects");
    j = 1; h.v[j][0][j*4 +: 4] <= 4'h9;
    #1 check(h.v[1], 16'h5697, "v[1] dynamic part select");

    // The index is captured when the statement executes.
    h.v[i] <= 16'hbeef;
    i = 0;
    check(h.v[1], 16'h5697, "v[1] before NBA");
    #1 check(h.v[1], 16'hbeef, "v[1] captured index");
    check(h.v[0], 16'h0, "v[0] untouched");

    // Invalid indices write nothing.
    j = 'x;  h.v[j] <= 16'h1111;
    j = 5;   h.v[j] <= 16'h2222;
    j = -1;  h.v[j][1] <= 8'h33;
    #1 check(h.v[1], 16'hbeef, "v[1] after invalid");
    check(h.v[0], 16'h0, "v[0] after invalid");

    // Two unpacked dimensions.
    foreach (h.m[a, b]) h.m[a][b] = '0;
    i = 1; j = 2;
    h.m[i][j] <= 8'h5a; h.m[0][j] <= 8'h11;
    #1 check(h.m[1][2], 8'h5a, "m[1][2]");
    check(h.m[0][2], 8'h11, "m[0][2]");
    check(h.m[1][1], 8'h00, "m[1][1]");

    if (!failed) $display("PASSED");
  end
endmodule

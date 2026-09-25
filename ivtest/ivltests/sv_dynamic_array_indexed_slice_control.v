// Neighboring supported forms: scalar dynamic-array indexing and a direct
// constant-colon slice. Neither uses the new indexed-slice path.
module test;
  logic data[];
  logic selected[];
  int base;

  initial begin
    data = new[4];
    data[0] = 0;
    data[1] = 1;
    data[2] = 1;
    data[3] = 0;
    base = 1;
    if (data[base] !== 1'b1)
      $fatal(1, "scalar dynamic-array read");
    data[base] = 1'b0;
    selected = data[1:2];
    if (selected.size() != 2 || selected[0] !== 1'b0
        || selected[1] !== 1'b1 || data.size() != 4)
      $fatal(1, "direct constant-colon control");
    $display("PASS dynamic-array slice control");
  end
endmodule

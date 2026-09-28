module sv_short_packed_slice_load;
  logic [3:0][1:0] value;
  logic signed [31:0] index;
  logic [1:0] got;

  task automatic check(input logic [1:0] expected, input string label);
    got = value[index];
    if (got !== expected)
      $fatal(1, "%s: expected %b, got %b", label, expected, got);
  endtask

  function automatic integer mutate_index;
    value = '1;
    return 0;
  endfunction

  initial begin
    value = 8'b1110x10z;
    index = 0;  check(2'b0z, "first two-bit element");
    index = 1;  check(2'bx1, "four-state element");
    index = 3;  check(2'b11, "last element");
    index = -1; check(2'bxx, "negative index");
    index = 4;  check(2'bxx, "index beyond end");
    index = 32'h7fffffff; check(2'bxx, "maximum positive index");
    index = 32'h80000000; check(2'bxx, "minimum negative index");
    index = 'x; check(2'bxx, "X index");
    index = 'z; check(2'bxx, "Z index");

    force value = 8'h03;
    index = 0; check(2'b11, "forced value");
    release value;

    value = 0;
    got = value[mutate_index()];
    if (got !== 2'b00 || value !== '1)
      $fatal(1, "side-effecting selector evaluation order");

    value = 8'b1110x10z;
    #1;
    for (int j = 1; j < 4; j++)
      value[j] <= value[j-1];
    #1;
    if (value !== 8'b10x10z0z)
      $fatal(1, "ordered two-bit nonblocking shifts");
    $display("PASSED");
  end
endmodule

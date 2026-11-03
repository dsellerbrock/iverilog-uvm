// IEEE 1800-2017/2023 11.5.1: an indexed part-select that crosses a
// non-leaf packed dimension reads X for the out-of-range elements.
module issue2335_packed_nonleaf_part_oob;
  logic [1:0][2:0][7:0] words;
  integer outer, inner;

  initial begin
    words = 48'h0123456789ab;

    outer = 0;
    inner = 2;
    if (words[outer][inner +: 2] !== 16'hxx67)
      $fatal(1, "upper boundary: got %h expected xx67",
             words[outer][inner +: 2]);

    inner = 0;
    if (words[outer][inner +: 2] !== 16'h89ab)
      $fatal(1, "in range: got %h expected 89ab",
             words[outer][inner +: 2]);

    inner = 3;
    if (words[outer][inner +: 2] !== 16'hxxxx)
      $fatal(1, "fully out of range: got %h expected xxxx",
             words[outer][inner +: 2]);

    outer = 2;
    inner = 2;
    if (words[outer][inner +: 2] !== 16'hxxxx)
      $fatal(1, "outer index out of range: got %h expected xxxx",
             words[outer][inner +: 2]);

    $display("PASSED");
  end
endmodule

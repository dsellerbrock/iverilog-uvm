`begin_keywords "1800-2012"

module main;
  logic       enable;
  logic [2:0] data;
  logic [2:0] stored;

  // Repeated assignments under the same enable have one vector-wide latch
  // enable. Combining more than two statements must preserve that identity
  // instead of manufacturing independent bit-level enables.
  always_latch begin
    if (enable)
      stored[0] = data[0];
    if (enable)
      stored[1] = data[1];
    if (enable)
      stored[2] = data[2];
  end

  task automatic check(input logic en, input logic [2:0] value,
                       input logic [2:0] expected);
    enable = en;
    data = value;
    #1;
    if (stored !== expected) begin
      $display("FAILED -- enable=%b data=%b stored=%b expected=%b",
               enable, data, stored, expected);
      $finish;
    end
  endtask

  (* ivl_synthesis_off *)
  initial begin
    check(1'b1, 3'b010, 3'b010);
    check(1'b0, 3'b101, 3'b010);
    check(1'b1, 3'b101, 3'b101);
    check(1'b0, 3'b000, 3'b101);
    $display("PASSED");
    $finish;
  end
endmodule

`end_keywords

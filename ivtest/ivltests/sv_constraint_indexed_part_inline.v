class C;
  localparam int BASE = 2;
  localparam int WIDTH = 1 + 2;
  rand bit [7:0] down;
  rand bit [0:7] up;
  task probe();
    bit [0:7] observed_up;
    if (!randomize(down) with {
      down == 8'hA6;
      down[BASE+:WIDTH] == 3'b001;
      down[5-:WIDTH] == 3'b100;
      down[(5 & 3)+:(2 | 0)] == 2'b11;
    }) $fatal(1, "descending solve failed");
    if (down != 8'hA6 || down[BASE+:WIDTH] != 3'b001
        || down[5-:WIDTH] != 3'b100
        || down[(5 & 3)+:(2 | 0)] != 2'b11)
      $fatal(1, "descending selected bits changed");
    if (!randomize(up) with {
      up == 8'hA6;
      up[BASE+:WIDTH] == 3'b100;
      up[5-:WIDTH] == 3'b001;
    }) $fatal(1, "ascending solve failed");
    observed_up = up;
    if (observed_up != 8'hA6 || observed_up[BASE+:WIDTH] != 3'b100
        || observed_up[5-:WIDTH] != 3'b001)
      $fatal(1, "ascending selected bits changed");
    if (randomize(down) with {
      down == 8'hA6;
      down[BASE+:WIDTH] == 3'b111;
    }) $fatal(1, "contradictory inline select was dropped");
  endtask
endclass
module top;
  C c;
  initial begin
    c = new;
    c.probe();
    $display("PASSED");
  end
endmodule

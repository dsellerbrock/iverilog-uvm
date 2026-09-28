typedef struct packed {
  bit [2:0] prefix;
  bit [7:0] addr;
  bit [3:0] suffix;
} op_t;
class Good;
  localparam int BASE = 2;
  localparam int WIDTH = 1 + 2;
  rand op_t op;
  constraint c {
    op == {3'h3, 8'hA6, 4'h5};
    op.addr[BASE+:WIDTH] == 3'b001;
    op.addr[5-:WIDTH] == 3'b100;
    op.addr[(5 & 3)+:(2 | 0)] == 2'b11;
    op.suffix == 4'h5;
    op.suffix < 8 - op.addr[BASE+:WIDTH];
  }
endclass
class Bad;
  localparam int BASE = 2;
  localparam int WIDTH = 1 + 2;
  rand op_t op;
  constraint c {
    op.addr == 8'hA6;
    op.addr[BASE+:WIDTH] == 3'b111;
  }
endclass
class BadArithmetic;
  rand op_t op;
  constraint c {
    op.addr == 8'hA6;
    op.suffix == 4'd7;
    op.suffix < 8 - op.addr[2+:3];
  }
endclass
module top;
  Good good;
  Bad bad;
  BadArithmetic arithmetic;
  initial begin
    good = new;
    bad = new;
    arithmetic = new;
    if (!good.randomize()) $fatal(1, "class solve failed");
    if (good.op != {3'h3, 8'hA6, 4'h5}
        || good.op.addr[2+:3] != 3'b001)
      $fatal(1, "class selected bits changed");
    if (bad.randomize()) $fatal(1, "contradictory class select was dropped");
    if (arithmetic.randomize())
      $fatal(1, "contradictory arithmetic constraint was dropped");
    $display("PASSED");
  end
endmodule

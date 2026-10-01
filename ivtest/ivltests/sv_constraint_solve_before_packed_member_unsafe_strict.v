// Without -gcommercial-unsafe a `solve ... before' operand that names a
// packed-struct member is not silently dropped: the constraint block is
// reported as unrepresentable and randomize() fails instead of ignoring it.
typedef struct packed { bit [3:0] part; bit [7:0] addr; } op_t;

class cfg;
  rand op_t op;
  rand bit [3:0] fractions;
  constraint k {
    solve fractions before op.addr;
    op.addr > 8'd10;
  }
endclass

module main;
  initial begin
    cfg c;
    c = new;
    if (c.randomize()) $display("FAILED randomize succeeded");
    else $display("PASSED");
  end
endmodule

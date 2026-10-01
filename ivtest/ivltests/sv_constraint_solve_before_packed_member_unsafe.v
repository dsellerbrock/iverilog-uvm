// -gcommercial-unsafe: `solve ... before' naming a member of a packed struct
// (rejected by strict tools: a packed member is not itself a random
// variable) only orders the distribution (IEEE 1800-2017 18.5.10), so the
// unnameable operand is omitted with a warning and the constraints still
// solve (OpenTitan flash_ctrl rand_op.addr).
typedef struct packed { bit [3:0] part; bit [7:0] addr; bit [3:0] other; } op_t;

class cfg;
  rand op_t op;
  rand bit [3:0] fractions;
  constraint k {
    solve fractions before op.addr;
    solve op.part before op.addr, op.other;
    op.part inside {[1:3]};
    op.addr > 8'd10;
  }
endclass

module main;
  int errors;
  initial begin
    cfg c;
    c = new;
    repeat (20) begin
      if (!c.randomize()) begin
        $display("FAILED randomize");
        errors++;
      end else begin
        if (!(c.op.part inside {[1:3]})) begin $display("FAILED part=%0d", c.op.part); errors++; end
        if (!(c.op.addr > 8'd10)) begin $display("FAILED addr=%0d", c.op.addr); errors++; end
      end
    end
    if (errors == 0) $display("PASSED");
  end
endmodule

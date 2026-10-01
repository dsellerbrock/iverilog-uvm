// -gcommercial-unsafe: `solve ... before' naming a struct array, a queue
// inside a multidimensional fixed array or another non-integral aggregate
// only orders the distribution (IEEE 1800-2017 18.5.10), so the unorderable
// operand is omitted with a warning and the constraints still solve. The
// strict diagnostics stay in sv_constraint_solve_before_fixed_array_neg.
typedef struct packed { bit [3:0] a; bit b; } st_t;

class cfg;
  rand bit [3:0] en;
  rand bit [3:0] other;
  rand st_t regs[3];
  rand st_t info[2][2][$];
  constraint all_c {
    solve en before regs, info, other;
    en inside {[1:3]};
    other > en;
    foreach (regs[i]) regs[i].a == en;
  }
  constraint only_agg_c { solve en before regs; }
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
        if (!(c.en inside {[1:3]})) begin $display("FAILED en=%0d", c.en); errors++; end
        if (!(c.other > c.en)) begin $display("FAILED other=%0d en=%0d", c.other, c.en); errors++; end
        foreach (c.regs[i])
          if (c.regs[i].a !== c.en) begin $display("FAILED regs[%0d].a", i); errors++; end
      end
    end
    if (errors == 0) $display("PASSED");
  end
endmodule

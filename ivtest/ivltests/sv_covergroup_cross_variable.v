// IEEE 1800-2017 19.6: a variable named directly by a cross creates an
// implicit coverpoint. Exercise with-function sample formals, standalone
// scope signals, and class properties. A binsof select must be able to name
// the implicit coverpoint by the variable identifier.
module main;
  bit failed = 0;

  task check(string label, bit ok);
    if (!ok) begin
      $display("FAILED -- %0s", label);
      failed = 1;
    end
  endtask

  function automatic bit near(real got, real want);
    return got > want - 0.1 && got < want + 0.1;
  endfunction

  covergroup argument_cg with function sample(bit a, bit b);
    cb: coverpoint b { bins zero = {0}; bins one = {1}; }
    axb: cross a, cb {
      bins a_one_b_zero = binsof(a) intersect {1} && binsof(cb.zero);
    }
  endgroup
  argument_cg argument_cov = new;

  bit clk = 0;
  bit scope_a = 0;
  bit scope_b = 0;
  covergroup scope_cg @(posedge clk);
    cb: coverpoint scope_b { bins zero = {0}; bins one = {1}; }
    axb: cross scope_a, cb;
  endgroup
  scope_cg scope_cov = new;

  class holder;
    bit a;
    bit b;
    covergroup cg;
      cb: coverpoint b { bins zero = {0}; bins one = {1}; }
      axb: cross a, cb;
    endgroup
    function new();
      cg = new;
    endfunction
  endclass
  holder held = new;

  initial begin
    // One of two bins in each coverpoint and one of four cross bins:
    // (50 + 50 + 25) / 3 = 41.666... percent.
    argument_cov.sample(1, 0);
    check("sample-formal implicit coverpoint",
          near(argument_cov.get_inst_coverage(), 41.6667));
    argument_cov.sample(0, 0);
    argument_cov.sample(0, 1);
    argument_cov.sample(1, 1);
    check("sample-formal implicit cross complete",
          argument_cov.get_inst_coverage() == 100.0);

    scope_a = 1;
    scope_b = 0;
    #1 clk = 1;
    #1;
    check("scope-signal implicit coverpoint",
          near(scope_cov.get_inst_coverage(), 41.6667));

    held.a = 1;
    held.b = 0;
    held.cg.sample();
    check("class-property implicit coverpoint",
          near(held.cg.get_inst_coverage(), 41.6667));

    if (!failed) $display("PASSED");
    $finish(0);
  end
endmodule

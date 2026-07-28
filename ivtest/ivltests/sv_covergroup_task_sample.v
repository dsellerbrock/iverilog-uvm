// A covergroup's synthesized metadata must exist before an ordinary
// package/module/interface task or function body containing sample() is
// lowered. Previously all of these calls compiled without diagnostics but
// emitted a zero-input sample operation and left coverage at 0%.
package cov_pkg;
  bit [1:0] pv;
  covergroup pcg;
    cp: coverpoint pv { bins each[] = {0,1,2,3}; }
  endgroup
  task automatic package_sample(pcg target, input bit [1:0] next);
    pv = next;
    target.sample();
  endtask
endpackage

interface cov_if;
  bit [1:0] value;
  covergroup if_cg;
    cp: coverpoint value { bins each[] = {0,1,2,3}; }
  endgroup
  if_cg cov = new;
  task automatic take_sample(input bit [1:0] next);
    value = next;
    cov.sample();
  endtask
endinterface

module main;
  import cov_pkg::*;
  int fails = 0;
  bit [1:0] value;
  cov_if cif();

  covergroup cg;
    cp: coverpoint value { bins each[] = {0,1,2,3}; }
  endgroup
  cg cov = new;

  covergroup arg_cg with function sample(bit [1:0] item);
    cp: coverpoint item { bins each[] = {0,1,2,3}; }
  endgroup
  arg_cg arg_cov = new;

  class holder;
    bit [1:0] member;
    covergroup nested;
      cp: coverpoint member { bins each[] = {0,1,2,3}; }
    endgroup
    function new;
      nested = new;
    endfunction
  endclass
  holder h = new;
  pcg p = new;

  task automatic module_sample(input bit [1:0] next);
    value = next;
    cov.sample();
  endtask

  task automatic argument_sample(input bit [1:0] next);
    arg_cov.sample(next);
  endtask

  function void function_sample(input bit [1:0] next);
    arg_cov.sample(next);
  endfunction

  task automatic nested_sample(input bit [1:0] next);
    h.member = next;
    h.nested.sample();
  endtask

  task check(string label, real got, real expected);
    if (got != expected) begin
      $display("FAILED -- %s got=%0.2f expected=%0.2f",
               label, got, expected);
      fails++;
    end
  endtask

  initial begin
    module_sample(1);
    module_sample(2);
    argument_sample(1);
    function_sample(2);
    nested_sample(1);
    nested_sample(2);
    package_sample(p, 1);
    package_sample(p, 2);
    cif.take_sample(1);
    cif.take_sample(2);
    check("module task", cov.get_inst_coverage(), 50.0);
    check("with-sample task/function", arg_cov.get_inst_coverage(), 50.0);
    check("nested receiver task", h.nested.get_inst_coverage(), 50.0);
    check("package task", p.get_inst_coverage(), 50.0);
    check("interface task", cif.cov.get_inst_coverage(), 50.0);
    if (fails == 0) $display("PASSED");
    $finish(0);
  end
endmodule

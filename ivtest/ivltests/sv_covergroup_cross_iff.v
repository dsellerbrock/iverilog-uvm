// IEEE 1800-2017 19.6: an iff clause on a cross gates only that cross.
// Coverpoints still sample while the cross guard is 0 or X. Exercise the
// explicit with-function sample path, standalone declaration-event path,
// class-embedded declaration-event path, and both labeled and unlabeled
// cross syntax (including a cross body).
module main;
  bit failed = 0;

  task check(string label, bit ok);
    if (!ok) begin
      $display("FAILED -- %0s", label);
      failed = 1;
    end
  endtask

  function automatic bit two_thirds(real cov);
    return cov > 66.0 && cov < 67.0;
  endfunction

  covergroup explicit_cg with function sample(bit a, bit b, logic gate);
    ca: coverpoint a { bins zero = {0}; }
    cb: coverpoint b { bins zero = {0}; }
    cx: cross ca, cb iff (gate);
  endgroup
  explicit_cg direct = new;

  // Parse and elaborate the unlabeled/body form too. It is deliberately
  // not sampled so it does not complicate the runtime percentages below.
  covergroup syntax_cg with function sample(bit a, bit b, logic gate);
    ca: coverpoint a { bins zero = {0}; }
    cb: coverpoint b { bins zero = {0}; }
    cross ca, cb iff (gate) {
      bins zero_zero = binsof(ca.zero) && binsof(cb.zero);
    }
  endgroup
  syntax_cg syntax_only = new;

  logic clk = 0;
  bit event_a = 0;
  bit event_b = 0;
  logic event_gate = 0;
  covergroup event_cg @(posedge clk);
    ca: coverpoint event_a { bins zero = {0}; }
    cb: coverpoint event_b { bins zero = {0}; }
    cx: cross ca, cb iff (event_gate);
  endgroup
  event_cg event_cov = new;

  class event_holder;
    bit a = 0;
    bit b = 0;
    logic gate = 0;
    covergroup cg @(posedge clk);
      ca: coverpoint a { bins zero = {0}; }
      cb: coverpoint b { bins zero = {0}; }
      cx: cross ca, cb iff (gate);
    endgroup
    function new(); cg = new; endfunction
  endclass
  event_holder held = new;

  initial begin
    // False and X cross guards leave both one-bin coverpoints at 100%,
    // while the one-bin cross remains at 0%: mean = 2/3.
    direct.sample(0, 0, 1'b0);
    check("direct false gates cross only",
          two_thirds(direct.get_inst_coverage()));
    direct.sample(0, 0, 1'bx);
    check("direct X gates cross only",
          two_thirds(direct.get_inst_coverage()));
    direct.sample(0, 0, 1'b1);
    check("direct true samples cross", direct.get_inst_coverage() == 100.0);

    // One declaration-event sample with false guards, for both the
    // standalone sampler and the class-instance registry sampler.
    #1 clk = 1;
    #1;
    check("standalone event false gates cross only",
          two_thirds(event_cov.get_inst_coverage()));
    check("class event false gates cross only",
          two_thirds(held.cg.get_inst_coverage()));

    clk = 0;
    event_gate = 1;
    held.gate = 1;
    #1 clk = 1;
    #1;
    check("standalone event true samples cross",
          event_cov.get_inst_coverage() == 100.0);
    check("class event true samples cross",
          held.cg.get_inst_coverage() == 100.0);

    if (!failed) $display("PASSED");
    $finish(0);
  end
endmodule

package static_seed_pkg;
  function automatic logic [95:0] sample();
    logic [95:0] draws;
    for (int i = 0; i < 3; i++)
      draws[32*i +: 32] = $urandom;
    return draws;
  endfunction
endpackage

module static_seed_worker #(parameter bit EXTRA_INIT = 0)(input bit tick);
  import static_seed_pkg::*;

  if (1) begin : startup
    if (EXTRA_INIT) begin : padding
      int constant_only = 42;
    end
    logic [95:0] draws;
    initial draws = sample();
  end

  if (1) begin : watching
    logic [95:0] plain_draws, comb_draws, latch_draws, ff_draws;
    always @(tick) if (tick) plain_draws = sample();
    always_comb begin
      if (tick) comb_draws = sample();
      else comb_draws = 'x;
    end
    always_latch if (tick) latch_draws = sample();
    always_ff @(posedge tick) ff_draws = sample();
  end
endmodule

interface static_seed_if;
  logic [95:0] draws;
  initial draws = static_seed_pkg::sample();
endinterface

program static_seed_program(output logic [95:0] draws);
  initial begin
    #1 draws = static_seed_pkg::sample();
    #100; // Keep the program alive through the comparison.
  end
endprogram

module test;
  bit tick;
  wire [95:0] left_program_draws, right_program_draws;
  static_seed_worker left(tick);
  static_seed_worker #(.EXTRA_INIT(1)) right(tick);
  static_seed_if left_if(), right_if();
  static_seed_program left_prog(left_program_draws), right_prog(right_program_draws);

  task automatic check_pair(input string kind, input logic [95:0] lhs, rhs);
    if ($isunknown(lhs) || lhs !== rhs)
      $fatal(1, "%s streams differ or did not complete: %h %h", kind, lhs, rhs);
  endtask

  initial begin
    #1 tick = 1;
    #1;
    if (right.startup.padding.constant_only !== 42)
      $fatal(1, "extra declaration initializer did not execute");
    check_pair("initial", left.startup.draws, right.startup.draws);
    check_pair("always", left.watching.plain_draws, right.watching.plain_draws);
    check_pair("always_comb", left.watching.comb_draws, right.watching.comb_draws);
    check_pair("always_latch", left.watching.latch_draws, right.watching.latch_draws);
    check_pair("always_ff", left.watching.ff_draws, right.watching.ff_draws);
    check_pair("interface", left_if.draws, right_if.draws);
    check_pair("program", left_program_draws, right_program_draws);
    if (left.startup.draws === left.watching.plain_draws)
      $fatal(1, "procedures in sibling generate scopes reused the same seed");
    $display("PASSED");
    $finish(0);
  end
endmodule

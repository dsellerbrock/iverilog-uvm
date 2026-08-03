`begin_keywords "1800-2012"

module comb_pass(
  input  logic d_i,
  output logic d_o
);
  always_comb d_o = d_i;
endmodule

module main;
  logic input_data;
  logic source;
  logic stage_one;
  logic stage_two;

  // Each assignment owns a different variable. Synthesis must retain a
  // structural boundary when the result feeds another process through a
  // module port; directly merging result and input nexuses makes this legal
  // chain look like multiple procedural drivers of the same variable.
  always_comb source = ~input_data;
  comb_pass u_stage_one(.d_i(source), .d_o(stage_one));
  comb_pass u_stage_two(.d_i(stage_one), .d_o(stage_two));

  task automatic check(input logic value);
    input_data = value;
    #1;
    if (source !== ~value || stage_one !== ~value || stage_two !== ~value) begin
      $display("FAILED -- input=%b source=%b stage_one=%b stage_two=%b",
               input_data, source, stage_one, stage_two);
      $finish;
    end
  endtask

  (* ivl_synthesis_off *)
  initial begin
    check(1'b0);
    check(1'b1);
    check(1'bx);
    $display("PASSED");
    $finish;
  end
endmodule

`end_keywords

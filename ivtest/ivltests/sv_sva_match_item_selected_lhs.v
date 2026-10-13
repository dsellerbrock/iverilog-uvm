// Functional regression for IEEE 1800-2017/2023 A.2.10 match-item lvalues.
// The second selected write must preserve bits written by the first.
module main;
  bit clk = 0;
  integer part_pass_count = 0;
  integer bit_pass_count = 0;

  always #5 clk = ~clk;
  default clocking cb @(posedge clk); endclocking

  property p_part_select;
    logic [7:0] accumulator;
    (1'b1, accumulator[3:0] = 4'h5) ##1
    (1'b1, accumulator[7:4] = 4'ha) ##1
    (accumulator == 8'ha5);
  endproperty
  ap_part_select: assert property (p_part_select)
    begin part_pass_count = part_pass_count + 1; end
    else $fatal(1, "part-select match-item update lost untouched bits");

  property p_bit_select;
    logic [7:0] accumulator;
    (1'b1, accumulator[3] = 1'b1) ##1
    (1'b1, accumulator[6] = 1'b1) ##1
    (accumulator == 8'h48);
  endproperty
  ap_bit_select: assert property (p_bit_select)
    begin bit_pass_count = bit_pass_count + 1; end
    else $fatal(1, "bit-select match-item update lost untouched bits");

  initial begin
    repeat (8) @(negedge clk);
    if (part_pass_count == 0 || bit_pass_count == 0)
      $fatal(1, "selected local-variable properties were vacuous");
    $display("PASS sv_sva_match_item_selected_lhs");
    $finish;
  end
endmodule

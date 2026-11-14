// Provisional IEEE_RULINGS.md row (31.8 is silent): a vector transition
// is a posedge if any bit makes a posedge transition and a negedge if any
// bit makes a negedge transition; for $width a both-edges transition ends
// the current pulse (check) before it starts the next one (stamp).
`timescale 1ns/1ns
module issue3288_vector_tchk_mixed_dut(input [1:0] c, input [1:0] w, input d);
  specify
    $width(posedge c, 5);
    $setup(d, posedge w, 3);
  endspecify
endmodule

module issue3288_vector_tchk_mixed;
  reg [1:0] c = 0, w = 0;
  reg d = 0;
  issue3288_vector_tchk_mixed_dut u(c, w, d);
  initial begin
    #10 c = 2'b01; #7 c = 2'b10;   // 17: ends a 7 ns pulse, starts one
    #2  c = 2'b00;                 // 19: 2 ns pulse: violation
    #11 w = 2'b01;                 // 30: posedge, d is stable
    #10 d = 1; #1 w = 2'b10;       // 41: bit 1 rises, bit 0 falls: violation
    #9  d = 0; #1 w = 2'b01;       // 51: bit 0 rises, bit 1 falls: violation
    #9  d = 1; #1 w = 2'b00;       // 61: falls only: no violation
    #10 $finish;
  end
endmodule

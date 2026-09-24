module unique_case_pair;
  logic [1:0] selector_x;
  logic [1:0] selector_match;
  logic x_out, match_out;
  always_comb begin
    unique case (selector_x)
      2'b01: x_out = 1'b1;
      2'b10: x_out = 1'b0;
    endcase
  end
  always_comb begin
    unique case (selector_match)
      2'b01: match_out = 1'b1;
      2'b10: match_out = 1'b0;
    endcase
  end
  initial begin
    selector_x = 2'bxx;
    selector_match = 2'b01;
    #1;
    $display("PAIR x=%b match=%b", selector_x, selector_match);
    $finish;
  end
endmodule

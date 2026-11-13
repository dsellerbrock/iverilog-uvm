module top;
  for (genvar i = 0; i < 2; i++) begin : g
    wire bit_value = 1;
  end
  if (1) begin
    wire other = 1;
  end
  for (genvar j = 0; j < 2; j++) begin
    wire x = 1;
  end
  if (1) begin : genblk999
    wire y = 1;
  end
  case (1)
    1: begin
      wire z = 1;
    end
  endcase
  if (0) begin : not_selected
  end else begin : selected
    wire z = 1;
  end
  case (1)
    1: begin : named_case
      wire z = 1;
    end
  endcase
  if (0) begin : absent
  end else begin
    wire z = 1;
  end
  initial begin $inspect_3053; $finish; end
endmodule

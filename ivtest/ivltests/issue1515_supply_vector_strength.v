module issue1515_supply_vector_strength;
  wire scalar_net;
  wire [1:0] default_vector;
  wire [1:0] selected_vector;
  supply0 [1:0] supply_zero;
  supply1 [1:0] supply_one;

  assign (strong1, strong0) scalar_net = 1'b1;
  assign default_vector = 2'b10;
  assign (weak1, weak0) selected_vector[0] = 1'b1;
  assign (weak1, weak0) selected_vector[1] = 1'b0;
  assign (strong1, strong0) supply_zero = 2'b11;
  assign (strong1, strong0) supply_one = 2'b00;

  initial begin
    #1;
    if (scalar_net !== 1'b1 || default_vector !== 2'b10 ||
        selected_vector !== 2'b01 || supply_zero !== 2'b00 ||
        supply_one !== 2'b11)
      $fatal(1, "scalar/supply strength result mismatch");
    $display("PASSED");
    $finish(0);
  end
endmodule

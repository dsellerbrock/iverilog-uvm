interface same_name_if;
  logic member;
endinterface

module minimal_red;
  wire [1:0] observed;
  same_name_if same_name_if[2]();
  for (genvar i = 0; i < 2; i++) begin : g
    assign observed[i] = same_name_if[i].member;
  end
endmodule

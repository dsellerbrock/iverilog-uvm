interface issue1164_mem_if;
  logic [1:0][6:0] ecc;
  logic [1:0][31:0] dout;
  modport sink (output ecc, output dout);
endinterface

module issue1164_ram (output logic [38:0] Q);
  assign Q = 39'h12_3456_789A;
endmodule

module issue1164_sink (issue1164_mem_if.sink m);
  for (genvar i = 0; i < 2; i++) begin: g
    wire [38:0] q;
    issue1164_ram r (.Q(q));
    assign {m.ecc[i][6:0], m.dout[i][31:0]} = q;
  end
endmodule

module issue1164_continuous_interface_concat;
  issue1164_mem_if m();
  issue1164_sink s(.m(m));

  initial begin
    #1;
    if (m.ecc[0] !== 7'h12 || m.dout[0] !== 32'h3456789a)
      $fatal(1, "interface member concatenation selected wrong bits");
    if (m.ecc[1] !== 7'h12 || m.dout[1] !== 32'h3456789a)
      $fatal(1, "generated interface member concatenation selected wrong bits");
    $display("ecc0=%h dout0=%h", m.ecc[0], m.dout[0]);
  end
endmodule

interface issue1165_mem_if;
  logic [1:0][6:0] ecc;
  logic [1:0][31:0] dout;
  modport sink (output ecc, output dout);
endinterface

module issue1165_ram (output logic [38:0] Q);
  assign Q = 39'h12_3456_789A;
endmodule

module issue1165_sink (issue1165_mem_if.sink m);
  for (genvar i = 0; i < 2; i++) begin: g
    wire [38:0] q;
    issue1165_ram r (.Q(q));
    assign m.ecc[i][6:0] = q[38:32];
    assign m.dout[i][31:0] = q[31:0];
  end
endmodule

module issue1165_interface_member_contassign_select;
  issue1165_mem_if m();
  issue1165_sink s(.m(m));

  initial begin
    #1;
    $display("ecc0=%h dout0=%h", m.ecc[0], m.dout[0]);
  end
endmodule

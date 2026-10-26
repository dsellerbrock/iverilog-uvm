interface mem_if;
  logic [1:0][6:0] ecc;
  logic [1:0][31:0] dout;
  modport sink (output ecc, output dout);
endinterface

module ram #(parameter logic [38:0] VALUE = 39'h12_3456_789A)
  (output logic [38:0] Q);
  assign Q = VALUE;
endmodule

module sink (mem_if.sink m);
  for (genvar i = 0; i < 2; i++) begin: g
    wire [38:0] q;
    ram #(.VALUE(i == 0 ? 39'h12_3456_789A : 39'h5a_abcdef01)) r (.Q(q));
    assign {m.ecc[i][6:0], m.dout[i][31:0]} = q;
  end
endmodule

module test;
  mem_if m();
  sink s(.m(m));
  initial begin
    #1;
    $display("ecc0=%h dout0=%h", m.ecc[0], m.dout[0]);
    $display("ecc1=%h dout1=%h", m.ecc[1], m.dout[1]);
    if (m.ecc[0] !== 7'h12 || m.dout[0] !== 32'h3456789a
        || m.ecc[1] !== 7'h5a || m.dout[1] !== 32'habcdef01)
      $fatal(1, "continuous concatenation l-value mismatch");
  end
endmodule

// IEEE 1800-2017/2023 25.5.4: continuous assignment drives the selected
// interface expression exported through each named modport port.
interface modport_contassign_if;
  wire [7:0] w;
  modport NET (output .T(w[7:4]), output .U(w[3:0]));
endinterface

module modport_contassign_driver(interface i);
  assign i.T = 4'h3;
  assign i.U = 4'he;
endmodule

module sv_modport_expression_contassign;
  modport_contassign_if i();
  modport_contassign_driver dut(i.NET);

  initial begin
    #1;
    if (i.w !== 8'h3e) begin
      $display("FAILED w=%h expected=3e", i.w);
      $fatal(1);
    end
    $display("w=%h", i.w);
  end
endmodule

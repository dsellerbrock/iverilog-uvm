interface itf;
  logic c, q, d;
  modport flop (input c, d, output q);
endinterface

module dtype (itf.flop ch);
  specify
    (posedge ch.c => (ch.q+:ch.d)) = (5,6);
  endspecify
endmodule

module sv_specify_interface_terminals;
  itf bus();
  dtype dut(bus);

  initial begin
    $display("PASS");
    $finish;
  end
endmodule

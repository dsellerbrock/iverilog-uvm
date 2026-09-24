interface forwarding_if;
  logic [7:0] value;
  modport observe(input value);
endinterface

module forward_leaf(forwarding_if.observe bus, output logic [7:0] observed);
  assign observed = bus.value;
endmodule

module forward_mid(forwarding_if.observe bus, output logic [7:0] observed);
  forward_leaf leaf(.bus(bus), .observed(observed));
endmodule

module forward_outer(forwarding_if.observe bus, output logic [7:0] observed);
  forward_mid mid(.bus(bus), .observed(observed));
endmodule

module forward_chain_red;
  logic [7:0] observed;
  forwarding_if physical();
  forward_outer outer(.bus(physical), .observed(observed));
  initial begin
    physical.value = 8'h5a;
    #1;
    if (observed !== 8'h5a) $fatal(1, "forwarded port lost physical interface");
    physical.value = 8'ha5;
    #1;
    if (observed !== 8'ha5) $fatal(1, "forwarded port lost member sensitivity");
    $display("PASSED forwarded interface port");
  end
endmodule

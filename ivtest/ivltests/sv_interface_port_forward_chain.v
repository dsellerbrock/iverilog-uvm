// IEEE 1800-2017/2023 25.3, 25.9: a physical interface stays bound when
// forwarded through multiple module interface ports before time-zero waits.
interface forward_chain_if;
  logic [7:0] value;
  modport observe(input value);
endinterface

module forward_chain_leaf(forward_chain_if.observe bus,
                          output logic [7:0] observed);
  assign observed = bus.value;
endmodule

module forward_chain_mid(forward_chain_if.observe bus,
                         output logic [7:0] observed);
  forward_chain_leaf leaf(.bus(bus), .observed(observed));
endmodule

module forward_chain_outer(forward_chain_if.observe bus,
                           output logic [7:0] observed);
  forward_chain_mid mid(.bus(bus), .observed(observed));
endmodule

module sv_interface_port_forward_chain;
  logic [7:0] observed;
  forward_chain_if physical();
  forward_chain_outer outer(.bus(physical), .observed(observed));
  initial begin
    physical.value = 8'h5a;
    #1;
    if (observed !== 8'h5a) $fatal(1, "forwarded initial value lost");
    physical.value = 8'ha5;
    #1;
    if (observed !== 8'ha5) $fatal(1, "forwarded sensitivity lost");
    $display("PASSED");
  end
endmodule

module sv_interface_port_forward_direct;
  logic [7:0] observed;
  forward_chain_if physical();
  forward_chain_leaf leaf(.bus(physical), .observed(observed));
  initial begin
    physical.value = 8'h5a;
    #1;
    if (observed !== 8'h5a) $fatal(1, "direct interface binding lost");
    $display("PASSED");
  end
endmodule

module sv_interface_port_forward_onehop;
  logic [7:0] observed;
  forward_chain_if physical();
  forward_chain_mid mid(.bus(physical), .observed(observed));
  initial begin
    physical.value = 8'h5a;
    #1;
    if (observed !== 8'h5a) $fatal(1, "one-hop interface binding lost");
    $display("PASSED");
  end
endmodule

module sv_interface_port_forward_null;
  virtual forward_chain_if vif;
  initial @(vif.value);
endmodule

interface itf;
  logic c, q, d, hidden;
  modport flop (input c, d, output q);
endinterface

module dtype (itf.flop ch);
  specify
    (posedge ch.c => (ch.q+:ch.d)) = (5,6);
  endspecify
endmodule

module dtype_generic (itf ch);
  specify
    (ch.c => ch.q) = (1,1);
  endspecify
endmodule

module dtype_default (itf ch);
  specify
    (ch.c => ch.q) = (1,1);
  endspecify
endmodule

module sv_specify_interface_terminals;
  itf bus();
  dtype dut(bus);
  initial $display("PASSED");
endmodule

module sv_specify_interface_no_modport;
  itf bus();
  dtype_default dut(bus);
  initial $display("PASSED");
endmodule

module sv_specify_interface_modport_actual;
  itf bus();
  dtype_generic dut(bus.flop);
  initial $display("PASSED");
endmodule

module bad_output_source (itf.flop ch);
  specify (ch.q => ch.q) = (1,1); endspecify
endmodule
module sv_specify_interface_bad_source;
  itf bus();
  bad_output_source dut(bus);
endmodule

module bad_input_destination (itf.flop ch);
  specify (ch.c => ch.c) = (1,1); endspecify
endmodule
module sv_specify_interface_bad_destination;
  itf bus();
  bad_input_destination dut(bus);
endmodule

module bad_modport_member (itf.flop ch);
  specify (ch.c => ch.hidden) = (1,1); endspecify
endmodule
module sv_specify_interface_bad_modport_member;
  itf bus();
  bad_modport_member dut(bus);
endmodule

module sv_specify_interface_bad_plain (input logic a, b);
  specify (a.b => b) = (1,1); endspecify
endmodule

module bad_unknown_member (itf.flop ch);
  specify (ch.missing => ch.q) = (1,1); endspecify
endmodule
module sv_specify_interface_bad_unknown_member;
  itf bus();
  bad_unknown_member dut(bus);
endmodule

module bad_actual_modport_typed (itf ch);
  specify (ch.q => ch.c) = (1,1); endspecify
endmodule
module sv_specify_interface_actual_modport_typed_fail;
  itf bus();
  bad_actual_modport_typed dut(bus.flop);
endmodule

module bad_actual_modport_generic (interface ch);
  specify (ch.q => ch.c) = (1,1); endspecify
endmodule
module sv_specify_interface_actual_modport_generic_fail;
  itf bus();
  bad_actual_modport_generic dut(bus.flop);
endmodule

module specify_forward_leaf (itf ch);
  specify (ch.c => ch.q) = (1,1); endspecify
endmodule
module specify_forward_leaf_bad (itf ch);
  specify (ch.q => ch.c) = (1,1); endspecify
endmodule
module specify_forward_mid (itf ch);
  specify_forward_leaf leaf(ch);
endmodule
module specify_forward_mid_bad (itf ch);
  specify_forward_leaf_bad leaf(ch);
endmodule
module sv_specify_interface_forward_chain;
  itf bus();
  specify_forward_mid mid(bus.flop);
  initial $display("PASSED");
endmodule
module sv_specify_interface_forward_chain_bad;
  itf bus();
  specify_forward_mid_bad mid(bus.flop);
endmodule

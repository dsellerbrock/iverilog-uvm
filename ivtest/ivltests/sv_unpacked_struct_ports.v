typedef struct {
  bit [7:0] op;
} bit_op_t;

typedef struct {
  logic [7:0] op;
} logic_op_t;

module input_var_port(input var bit_op_t a);
  initial begin
    #1;
    if (a.op !== 8'h5a)
      $fatal(1, "input variable unpacked struct port mismatch");
  end
endmodule

module input_net_port(input logic_op_t a);
  initial begin
    #1;
    if (a.op !== 8'ha5)
      $fatal(1, "input net unpacked struct port mismatch");
  end
endmodule

module output_var_port(output var bit_op_t a);
  initial a.op = 8'hc3;
endmodule

module sv_unpacked_struct_ports;
  bit_op_t var_source;
  logic_op_t net_source;
  bit_op_t var_sink;

  input_var_port u_var_in(.a(var_source));
  input_net_port u_net_in(.a(net_source));
  output_var_port u_var_out(.a(var_sink));

  initial begin
    var_source.op = 8'h5a;
    net_source.op = 8'ha5;
    #2;
    if (var_sink.op !== 8'hc3)
      $fatal(1, "output variable unpacked struct port mismatch");
    $display("PASSED");
    $finish;
  end
endmodule

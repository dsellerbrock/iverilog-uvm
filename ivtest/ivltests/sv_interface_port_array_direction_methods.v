interface port_array_direction_if #(parameter int WIDTH = 8);
  logic [WIDTH-1:0] data;

  task automatic put(input logic [WIDTH-1:0] value);
    data = value;
  endtask

  modport access(import put);
endinterface

module port_array_ascending_formal(
  port_array_direction_if.access ports [0:1],
  input logic [15:0] left_value,
  input logic [15:0] right_value
);
  initial begin
    #0;
    ports[0].put(left_value);
    ports[1].put(right_value);
  end
endmodule

module port_array_descending_formal(
  port_array_direction_if.access ports [1:0],
  input logic [15:0] left_value,
  input logic [15:0] right_value
);
  initial begin
    #0;
    ports[1].put(left_value);
    ports[0].put(right_value);
  end
endmodule

module sv_interface_port_array_direction_methods;
  port_array_direction_if #(.WIDTH(16)) aa [2:3] ();
  port_array_direction_if #(.WIDTH(16)) ad [3:2] ();
  port_array_direction_if #(.WIDTH(16)) da [2:3] ();
  port_array_direction_if #(.WIDTH(16)) dd [3:2] ();

  port_array_ascending_formal u_aa(
    .ports(aa), .left_value(16'ha201), .right_value(16'ha302));
  port_array_ascending_formal u_ad(
    .ports(ad), .left_value(16'hb301), .right_value(16'hb202));
  port_array_descending_formal u_da(
    .ports(da), .left_value(16'hc201), .right_value(16'hc302));
  port_array_descending_formal u_dd(
    .ports(dd), .left_value(16'hd301), .right_value(16'hd202));

  initial begin
    #1;
    if ({aa[2].data, aa[3].data} !== {16'ha201, 16'ha302})
      $fatal(1, "ascending formal/actual mapped incorrectly: %h %h",
             aa[2].data, aa[3].data);
    if ({ad[3].data, ad[2].data} !== {16'hb301, 16'hb202})
      $fatal(1, "ascending formal/descending actual mapped incorrectly: %h %h",
             ad[3].data, ad[2].data);
    if ({da[2].data, da[3].data} !== {16'hc201, 16'hc302})
      $fatal(1, "descending formal/ascending actual mapped incorrectly: %h %h",
             da[2].data, da[3].data);
    if ({dd[3].data, dd[2].data} !== {16'hd301, 16'hd202})
      $fatal(1, "descending formal/actual mapped incorrectly: %h %h",
             dd[3].data, dd[2].data);

    $display("PASSED interface-port array directions and task dispatch");
  end
endmodule

`timescale 1ns/1ps
module issue1561_source(output reg y);
  initial begin
    y = 1'b0;
    #10 y = 1'b1;
  end
endmodule

module issue1561_load(input wire a, output wire y);
  assign y = a;
endmodule

module top;
  wire port_link, net_link, port_netdelay_link, unrelated_link;
  wire multi_port_link, multi_net_link;
  wire port_result, net_result_a, net_result_b, port_netdelay_result;
  wire multi_port_result, multi_net_result_a, multi_net_result_b;
  wire unrelated_result;

  issue1561_source u1(.y(port_link));
  issue1561_load u2(.a(port_link), .y(port_result));

  issue1561_source u3(.y(net_link));
  issue1561_load u4(.a(net_link), .y(net_result_a));
  issue1561_load u5(.a(net_link), .y(net_result_b));

  issue1561_source u8(.y(port_netdelay_link));
  issue1561_load u9(.a(port_netdelay_link), .y(port_netdelay_result));

  issue1561_source u10(.y(multi_port_link));
  issue1561_source u11(.y(multi_port_link));
  issue1561_load u12(.a(multi_port_link), .y(multi_port_result));

  issue1561_source u13(.y(multi_net_link));
  issue1561_source u14(.y(multi_net_link));
  issue1561_load u15(.a(multi_net_link), .y(multi_net_result_a));
  issue1561_load u16(.a(multi_net_link), .y(multi_net_result_b));

  issue1561_source u6(.y(unrelated_link));
  issue1561_load u7(.a(unrelated_link), .y(unrelated_result));

  initial begin
    $sdf_annotate("ivltests/issue1561_sdf_port.sdf", top);
    $sdf_annotate("ivltests/issue1561_sdf_netdelay.sdf", top);
    $monitor("t=%0t port=%b net=%b,%b netport=%b multiport=%b multinet=%b,%b unrelated=%b",
             $realtime, port_result, net_result_a, net_result_b,
             port_netdelay_result, multi_port_result, multi_net_result_a,
             multi_net_result_b, unrelated_result);
    #20 $finish;
  end
endmodule

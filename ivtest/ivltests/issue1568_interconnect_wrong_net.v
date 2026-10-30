`timescale 1ns/1ps
module issue1568_source(output wire y);
  reg value = 0;
  assign y = value;
  initial begin
    #10 value = 1;
  end
endmodule

module issue1568_sink(input wire a, output wire y);
  assign y = a;
endmodule

module tb;
  wire good_net, wrong_net, load, result;
  issue1568_source u1(good_net);
  issue1568_source u4(wrong_net);
  issue1568_sink u2(load, result);
  assign load = good_net;

  initial begin
    $sdf_annotate("ivltests/issue1568_interconnect_wrong_net.sdf", tb);
    $monitor("t=%0t good=%b wrong=%b load=%b result=%b",
             $time, good_net, wrong_net, load, result);
    #30 $finish;
  end
endmodule

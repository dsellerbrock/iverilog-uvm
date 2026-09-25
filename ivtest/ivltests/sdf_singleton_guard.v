`timescale 1ns/1ps

module sdf_singleton_guard;
  reg in, contender;
  wire plain_out, competing_out, wrong;
  plain_chain plain_dut(plain_out, wrong, in);
  competing_chain competing_dut(competing_out, in, contender);

  initial begin
    in = 0;
    contender = 1'bz;
    $sdf_annotate("ivltests/sdf_singleton_guard.sdf");
    #1;
    if ({plain_out, competing_out, wrong} !== 3'b000)
      $fatal(1, "initial chain output is wrong");
    in = 1;
    #0.1;
    if ({plain_out, competing_out, wrong} !== 3'b111)
      $fatal(1, "invalid SDF path delayed a chain output");
    $display("PASSED");
    $finish;
  end
endmodule

module plain_chain(output wire out, wrong, input wire in);
  wire [2:0] chain;
  assign chain[0] = in;
  buff i0(.Y(wrong), .A(chain[0]));
  buff i1(.Y(chain[1]), .A(chain[0]));
  buff i2(.Y(chain[2]), .A(chain[1]));
  assign out = chain[2];
endmodule

module competing_chain(output wire out, input wire in, contender);
  wire [2:0] chain;
  assign chain[0] = in;
  buff i1(.Y(chain[1]), .A(chain[0]));
  assign chain[1] = contender;
  buff i2(.Y(chain[2]), .A(chain[1]));
  assign out = chain[2];
endmodule

`celldefine
module buff(output wire Y, input wire A);
  buf (Y, A);
  specify (A => Y) = 0; endspecify
endmodule
`endcelldefine

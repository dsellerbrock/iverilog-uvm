parameter logic [7:0] My_DataIn = 8'hFF;
module bus_conn(output logic [7:0] dataout, input [7:0] datain = My_DataIn); assign dataout = datain; endmodule
module bus_connect1(output logic [31:0] dataout, input [7:0] datain);
 parameter logic [7:0] My_DataIn = 8'h00;
 bus_conn bconn0(dataout[31:24], 8'h0F); bus_conn bconn1(dataout[23:16]);
 bus_conn bconn2(dataout[15:8], My_DataIn); bus_conn bconn3(dataout[7:0]);
endmodule
module test(a,b,c,d,e,f,g,h); input [7:0] a; input [7:0] b; input signed [7:0] c; input signed [7:0] d;
 output [7:0] e; output [7:0] f; output signed [7:0] g; output signed [7:0] h;
 wire signed [7:0] b; wire [7:0] c; logic signed [7:0] f; logic [7:0] g;
 assign e=a; assign g=c; assign h=d; always_comb f=b; endmodule
module complex_ports({c,d}, .e(f)); input c,d; output f; assign f=c&d; endmodule
module split_ports(a[7:4], a[3:0]); input [7:0] a; endmodule
module same_port(.a(i),.b(i)); inout i; endmodule
module renamed_concat(.a({b,c}), f, .g(h[1])); input b,c; output f; output [1:0] h; assign f=b|c; assign h={b,c}; endmodule
module same_input(a,a); input a; endmodule
module mh3([5:0] x); initial $display("MH3 %0d", $bits(x)); endmodule
module mh19(output signed [5:0] x, integer y); assign x=-1; initial begin y=7; $display("MH19 %0d", $bits(y)); end endmodule
module mh22(input wire integer p_a, .p_b(s_b), p_c); logic [5:0] s_b; initial $display("MH22 %0d", $bits(p_a)); endmodule
module top;
 wire [31:0] d32; bus_connect1 bc(d32, 8'h00);
 wire [7:0] e8,f8; wire signed [7:0] g8,h8; reg [7:0] a8=8'hFF, b8=8'hFF; reg signed [7:0] c8=8'shFF;
 test t(a8,b8,c8,c8,e8,f8,g8,h8); wire [15:0] ext_e=e8, ext_g=g8, ext_h=h8; wire cf; wire [1:0] hh;
 complex_ports cp(2'b11, cf); renamed_concat rc(.a(2'b10), .f(cf), .g(hh[1]));
 mh3 m3(.x(6'h2a)); wire signed [5:0] m19x; mh19 m19(m19x, ); mh22 m22(.p_a(5), .p_b(), .p_c());
 initial begin #1; $display("D32 %h", d32); $display("EXT %h %h %h", ext_e, ext_g, ext_h); $display("F %h", f8); $display("CF %b", cf); end
endmodule

module ansi_input(input wire #5 i); endmodule
module ansi_output(output wire #5 o); endmodule
module ansi_inout(inout wire #5 io); endmodule

module nonansi_input(i);
  input wire #5 i;
endmodule

module nonansi_output(o);
  output wire #5 o;
endmodule

module nonansi_inout(io);
  inout wire #5 io;
endmodule

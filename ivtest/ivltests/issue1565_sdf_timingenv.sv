`timescale 1ns/1ns

module issue1565_buf(input wire a, output wire y, output wire \y) );
  assign y = a;
  assign \y) = a;
endmodule

module issue1565_path #(parameter SDF_FILE = "") (input wire a, output wire y);
  wire link;
  issue1565_buf u1(.a(a), .y(link));
  issue1565_buf u2(.a(link), .y(y));

  initial $sdf_annotate(SDF_FILE);
endmodule

module issue1565_sdf_timingenv;
  reg a = 0;
  wire [4:0] y;
  time rise[5];

  issue1565_path #("ivltests/issue1565_timingenv_plain.sdf") plain(a, y[0]);
  issue1565_path #("ivltests/issue1565_timingenv_block.sdf") block_comment(a, y[1]);
  issue1565_path #("ivltests/issue1565_timingenv_line.sdf") line_comment(a, y[2]);
  issue1565_path #("ivltests/issue1565_timingenv_ident.sdf") escaped_ident(a, y[3]);
  issue1565_path #("ivltests/issue1565_timingenv_name.sdf") quoted_name(a, y[4]);

  for (genvar i = 0; i < 5; i = i+1) begin : watch
    always @(posedge y[i]) rise[i] = $time;
  end

  initial begin
    #10 a = 1;
    #10;
    $display("plain          %0d %b", rise[0], y[0]);
    $display("block comment  %0d %b", rise[1], y[1]);
    $display("line comment   %0d %b", rise[2], y[2]);
    $display("escaped ident  %0d %b", rise[3], y[3]);
    $display("quoted name    %0d %b", rise[4], y[4]);
  end
endmodule

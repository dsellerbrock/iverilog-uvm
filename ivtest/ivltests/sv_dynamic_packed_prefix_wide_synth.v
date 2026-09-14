module asc_dut(input logic clk, reset, input logic signed [127:0] o,m,b,
               output logic [0:1][3:5][0:7] words);
  always @(posedge clk)
    if (reset) words <= 48'ha5a5a5a5a5a5;
    else words[o][m][b +: 4] <= 4'h3;
endmodule
module neg_dut(input logic clk, reset, input logic signed [127:0] o,m,b,
               output logic [-1:-2][-3:-1][-2:-9] words);
  always @(posedge clk)
    if (reset) words <= 48'ha5a5a5a5a5a5;
    else words[o][m][b -: 4] <= 4'h3;
endmodule
module test;
  logic clk=0, reset=0;
  logic signed [127:0] ao,am,ab,no,nm,nb;
  wire [47:0] aw,nw;
  asc_dut a(clk,reset,ao,am,ab,aw);
  neg_dut n(clk,reset,no,nm,nb,nw);
  task automatic tick; #1 clk=1; #1 clk=0; endtask
  initial begin
    reset=1; tick(); reset=0;
    ao=1; am=5; ab=2; no=-2; nm=-1; nb=-8; tick();
    if (aw!==48'ha5a5a5a5a58d || nw!==48'ha5a5a5a5a5a4)
      $fatal(1,"valid wide selects wrote %h/%h",aw,nw);
    reset=1; tick(); reset=0;
    ao=128'd1<<100; am=5; ab=2;
    no=-(128'sd1<<100); nm=-1; nb=-8; tick();
    if (aw!==48'ha5a5a5a5a5a5 || nw!==48'ha5a5a5a5a5a5)
      $fatal(1,"wide invalid prefix wrote %h/%h",aw,nw);
    $display("PASSED");
  end
endmodule

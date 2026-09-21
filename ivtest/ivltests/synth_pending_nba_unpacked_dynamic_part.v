module unpacked_dynamic_part(input logic clk, rst,
                             input logic [1:0] word,
                             input logic [2:0] part,
                             input logic [3:0] hi, lo,
                             output logic [7:0] observe0, observe1);
  logic [7:0] mem [0:1];
  always_ff @(posedge clk) begin
    if (rst) begin
      mem[0] <= 8'h12;
      mem[1] <= 8'h34;
    end else begin
      mem[word][part +: 4] <= hi; // runtime word and packed part NBA
      mem[word][3:0] = lo;        // B write after NBA must not hide scheduled bits
    end
  end
  assign observe0=mem[0];
  assign observe1=mem[1];
endmodule
module tb_unpacked_dynamic_part;
  logic clk=0,rst=1; logic [1:0] word; logic [2:0] part; logic [3:0] hi,lo;
  logic [7:0] observe0,observe1;
  unpacked_dynamic_part dut(.*); always #5 clk=~clk;
  task step(input logic [1:0] w,input logic [2:0] p,input logic [3:0] h,l,
            input logic [7:0] want0,want1);
    word=w; part=p; hi=h; lo=l; @(posedge clk); #1;
    if(observe0!==want0 || observe1!==want1)
      $fatal(1,"mem=%h,%h want=%h,%h",observe0,observe1,want0,want1);
  endtask
  initial begin
    word=0;part=0;hi=0;lo=0;
    @(negedge clk); rst=0;
    step(1,3'd4,4'ha,4'h5,8'h12,8'ha5); // write high nibble of word 1
    step(0,3'd0,4'hc,4'h9,8'h1c,8'ha5); // overlapping NBA wins over later B
    step(2,3'd4,4'hf,4'h0,8'h1c,8'ha5); // OOB word is no write
    word='x; part=3'd0; hi=4'hf; lo=4'h0; @(posedge clk); #1;
    if(observe0!==8'h1c || observe1!==8'ha5) $fatal(1,"X word wrote memory");
    word=0; part='x; hi=4'hf; lo=4'h0; @(posedge clk); #1;
    if(observe0!==8'h10 || observe1!==8'ha5) $fatal(1,"X part NBA wrote memory or blocking write lost");
    $display("PASS"); $finish(0);
  end
endmodule

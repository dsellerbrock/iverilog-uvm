module compact_nba_old_read(
  input  logic       clk,
  input  logic       word,
  input  logic [7:0] d,
  output logic [7:0] q,
  output logic [7:0] mem0,
  output logic [7:0] mem1
);
  logic [7:0] mem [0:1];

  always_ff @(posedge clk) begin
    mem[word] <= d;
    q <= mem[word];
  end

  assign mem0 = mem[0];
  assign mem1 = mem[1];
endmodule

module tb_compact_nba_old_read;
  logic clk = 0;
  logic word = 0;
  logic [7:0] d = 8'ha1;
  logic [7:0] q, mem0, mem1;

  compact_nba_old_read dut(.*);

  task tick;
    #1 clk = 1;
    #1 clk = 0;
  endtask

  initial begin
    tick();
    if (mem0 !== 8'ha1 || mem1 !== 8'hxx || q !== 8'hxx)
      $fatal(1, "first write/read mem=%h,%h q=%h", mem0, mem1, q);

    d = 8'hb2;
    tick();
    if (mem0 !== 8'hb2 || mem1 !== 8'hxx || q !== 8'ha1)
      $fatal(1, "word0 old-value read mem=%h,%h q=%h", mem0, mem1, q);

    word = 1;
    d = 8'hc3;
    tick();
    if (mem0 !== 8'hb2 || mem1 !== 8'hc3 || q !== 8'hxx)
      $fatal(1, "first word1 write/read mem=%h,%h q=%h", mem0, mem1, q);

    d = 8'hd4;
    tick();
    if (mem0 !== 8'hb2 || mem1 !== 8'hd4 || q !== 8'hc3)
      $fatal(1, "word1 old-value read mem=%h,%h q=%h", mem0, mem1, q);

    $display("PASS");
    $finish(0);
  end
endmodule

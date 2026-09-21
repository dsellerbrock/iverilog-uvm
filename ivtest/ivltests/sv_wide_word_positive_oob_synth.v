module pending_nba_wide_positive_oob(
  input  logic       clk,
  input  logic [7:0] d,
  output logic [7:0] mem0,
  output logic [7:0] mem1
);
  logic [7:0] mem [0:1];

  always_ff @(posedge clk) begin
    mem[0] <= d;
    // IEEE invalid-index assignment: no word is selected.
    mem[80'h1_0000_0000_0000_0000] <= 8'hff;
  end

  assign mem0 = mem[0];
  assign mem1 = mem[1];
endmodule

module tb_pending_nba_wide_positive_oob;
  logic clk = 0;
  logic [7:0] d = 8'h35;
  logic [7:0] mem0, mem1;

  pending_nba_wide_positive_oob dut(.*);

  task tick;
    #1 clk = 1;
    #1 clk = 0;
  endtask

  initial begin
    tick();
    if (mem0 !== 8'h35 || mem1 !== 8'hxx)
      $fatal(1, "positive wide OOB selector wrote mem=%h,%h", mem0, mem1);
    d = 8'h7a;
    tick();
    if (mem0 !== 8'h7a || mem1 !== 8'hxx)
      $fatal(1, "positive wide OOB selector disturbed mem=%h,%h", mem0, mem1);
    $display("PASS");
    $finish(0);
  end
endmodule

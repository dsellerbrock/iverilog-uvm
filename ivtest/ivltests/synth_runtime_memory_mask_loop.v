module sv_masked_memory_descending_bounds;
  reg clk = 0;
  reg [2:0] addr = 0;
  reg [1:0] mask = 0;
  reg [7:0] data = 0;
  reg [7:0] mem [5:3];
  integer i;

  always @(posedge clk) begin
    for (int j=0; j<2; j=j+1)
      if(mask[j]) mem[addr][j*4 +: 4] <= data[j*4 +: 4];
  end

  task tick;
    #1 clk = 1; #1 clk = 0;
  endtask

  (* ivl_synthesis_off *) initial begin
    mask = 3;
    for (i = 3; i <= 5; i = i + 1) begin
      addr = i; data = i * 8'h11; tick();
    end
    addr = 4; data = 8'ha5; mask = 1; tick();
    if (mem[4] !== 8'h45 || mem[3] !== 8'h33 || mem[5] !== 8'h55)
      $fatal(1, "descending-bound low mask changed unrelated bits/words");
    data = 8'hb0; mask = 2; tick();
    if (mem[4] !== 8'hb5) $fatal(1, "descending-bound high mask");
    mask = 0; data = 8'h00; addr = 3; tick();
    if (mem[3] !== 8'h33) $fatal(1, "disabled descending-bound write");
    $display("PASSED");
    $finish(0);
  end
endmodule

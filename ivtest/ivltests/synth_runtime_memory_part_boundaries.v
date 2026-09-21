module sv_masked_memory_runtime_part_boundaries;
  integer i;
  reg clk = 0;
  reg [2:0] addr = 0;
  reg [3:0] base = 0;
  reg [3:0] data = 0;
  reg [7:0] mem [0:2];

  always @(posedge clk) mem[addr][base -: 4] <= data;

  task tick;
    #1 clk = 1; #1 clk = 0;
  endtask

  (* ivl_synthesis_off *) initial begin
    for(i=0;i<3;i=i+1) begin
      addr=i;data=0;base=3;tick();base=7;tick();
    end
    data = 4'ha;
    addr = 0; base = 7; tick();
    addr = 1; data = 4'h5; base = 3; tick();
    addr = 2; data = 4'hf; base = 1; tick();
    if (mem[0] !== 8'ha0 || mem[1] !== 8'h05 || mem[2] !== 8'h03)
      $fatal(1, "runtime packed part write");
    addr = 0; data = 4'hf; base = 0; tick();
    addr = 1; base = 4'd15; tick();
    addr = 2; base = 4'bx; tick();
    if (mem[0] !== 8'ha1 || mem[1] !== 8'h05 || mem[2] !== 8'h03)
      $fatal(1, "partial/full/X packed part changed memory");
    addr = 3'bz; base = 4'd3; tick();
    if (mem[0] !== 8'ha1 || mem[1] !== 8'h05 || mem[2] !== 8'h03)
      $fatal(1, "Z word index changed memory");
    $display("PASSED");
    $finish(0);
  end
endmodule

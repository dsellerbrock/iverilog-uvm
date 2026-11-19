package issue1166_pkg;
  function automatic void spawn();
    fork
      begin
        #8 $display("%0t nested child alive", $time);
        #16 $display("%0t ERROR: nested child survived program completion", $time);
      end
    join_none
  endfunction
endpackage

program issue1166_worker(input logic clk);
  initial begin
    fork
      begin
        #1 $display("%0t child started", $time);
        repeat (3) @(posedge clk);
        $display("%0t ERROR: child survived program completion", $time);
      end
      issue1166_pkg::spawn();
    join_none
    @(posedge clk);
    $display("%0t initial done", $time);
  end

  if (1) begin : generated
    initial #12 $display("%0t generated initial done", $time);
  end
endprogram

program issue1166_keeper;
  // Keep simulation alive after the worker's last initial ends at 12.
  initial #32 $display("%0t keeper done", $time);
endprogram

module issue1166_program_completion;
  logic clk = 0;
  always #5 clk = ~clk;
  issue1166_worker worker(clk);
  issue1166_keeper keeper();
  initial #60 $fatal(1, "program completion watchdog");
  final $display("%0t final", $time);
endmodule

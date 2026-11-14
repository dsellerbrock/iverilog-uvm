`timescale 1ns/1ns
module issue3249_cover_timed_call;
  logic clk = 0, fire = 0;
  int cover_t = -1, starts = 0, resumes = 0;
  always #5 clk = ~clk;

  task automatic waits_for_edge;
    starts++;
    @(negedge clk);
    resumes++;
  endtask

  sequence observed;
    @(posedge clk) (fire, waits_for_edge());
  endsequence
  c1: cover property (observed);
  c2: cover property (observed) cover_t = $time;

  initial begin
    @(negedge clk); fire = 1;
    @(negedge clk); fire = 0;
    #1;
    if (cover_t !== 15 || starts !== 2 || resumes !== 2)
      $display("FAIL cover=%0d starts=%0d resumes=%0d", cover_t, starts, resumes);
    else
      $display("PASS");
    $finish(0);
  end
endmodule

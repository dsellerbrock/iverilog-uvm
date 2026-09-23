// Exact timing control without overlapping true antecedents. The literal
// checkers use the established NFA; symbolic checkers use the new path.
module consequent_timing_checker #(parameter int W = 2)(
    input logic clk, start, ready);
  integer symbolic_pass = 0, symbolic_fail = 0;
  integer literal_pass = 0, literal_fail = 0;

  symbolic: assert property (@(posedge clk)
      start |=> !ready[*W] ##1 ready)
    symbolic_pass++;
  else symbolic_fail++;

  generate
    if (W == 0) begin : zero
      literal: assert property (@(posedge clk)
          start |=> !ready[*0] ##1 ready)
        literal_pass++;
      else literal_fail++;
    end else if (W == 2) begin : two
      literal: assert property (@(posedge clk)
          start |=> !ready[*2] ##1 ready)
        literal_pass++;
      else literal_fail++;
    end else if (W == 3) begin : three
      literal: assert property (@(posedge clk)
          start |=> !ready[*3] ##1 ready)
        literal_pass++;
      else literal_fail++;
    end
  endgenerate

  always @(negedge clk) begin
    #1;
    if (symbolic_pass != literal_pass || symbolic_fail != literal_fail) begin
      $display("FAILED W=%0d: symbolic %0d/%0d literal %0d/%0d at %0t",
          W, symbolic_pass, symbolic_fail, literal_pass, literal_fail, $time);
      $finish_and_return(1);
    end
  end
endmodule

module parameter_consequent_repeat_timing;
  logic clk = 0, start = 0, ready = 0;
  always #5 clk = ~clk;
  consequent_timing_checker #(.W(0)) zero (.*);
  consequent_timing_checker #(.W(2)) two (.*);
  consequent_timing_checker #(.W(3)) three (.*);

  task automatic drive(input logic s, r);
    @(negedge clk);
    start = s;
    ready = r;
  endtask

  initial begin
    drive(1, 0);
    drive(0, 1); // W=0 finishes at the first consequent tick.
    drive(0, 0);
    drive(0, 0);
    drive(0, 0);
    drive(0, 0);
    drive(1, 0);
    drive(0, 0);
    drive(0, 0);
    drive(0, 1); // W=2 finishes; W=3 fails its third keep sample.
    drive(0, 0);
    drive(0, 0);
    drive(0, 0);
    @(negedge clk);
    #2;
    $display("PASSED");
    $finish;
  end
endmodule

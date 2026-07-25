// Each check gets a stimulus that VIOLATES it. Any check that prints
// nothing is either unimplemented or not firing.
module m_nochange(input clk, d); specify $nochange(posedge clk, d, 0, 0); endspecify endmodule
module m_timeskew(input clk, d); specify $timeskew(posedge clk, posedge d, 5); endspecify endmodule
module m_fullskew(input clk, d); specify $fullskew(posedge clk, posedge d, 5, 5); endspecify endmodule
module m_width(input clk);       specify $width(posedge clk, 5);  endspecify endmodule
module m_period(input clk);      specify $period(posedge clk, 20); endspecify endmodule
module tb;
  reg c=0, d=0;
  m_nochange un(c,d);
  m_timeskew ut(c,d);
  m_fullskew uf(c,d);
  m_width    uw(c);
  m_period   up(c);
  initial begin
    // clk pulse of width 2 (violates $width 5) and period 6 (violates 20)
    #10 c=1;
    #2  c=0;
    #4  c=1;          // period 10->16 = 6 < 20
    #2  c=0;
    // d rises 20 after the clk edge -> violates timeskew/fullskew limit 5
    #10 c=1;
    #20 d=1;
    #10 $display("DONE fires");
    $finish(0);
  end
endmodule

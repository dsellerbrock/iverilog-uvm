module p19v;
 bit [2:0] p1; bit signed [2:0] p2;
 covergroup g;
  cpA : coverpoint p1 { bins t = {1, [2:5], [6:10]}; bins ctl = {0}; }
  cpC : coverpoint p1 { bins t = {-1, 3}; bins ctl = {0}; }
  cpD : coverpoint p1 { bins t = {15, 3}; bins ctl = {0}; }
  cpE : coverpoint p2 { bins t = {1, [6:10]}; bins ctl = {-4}; }
  cpF : coverpoint p2 { bins t = {0, [2:5]}; bins ctl = {-4}; }
 endgroup
 g cg = new;
 initial begin
  p1 = 7; p2 = -2; cg.sample();
  p1 = 0; p2 = 3;  cg.sample();
  p2 = -4; cg.sample();
  $display("V A=%0.1f C=%0.1f D=%0.1f E=%0.1f F=%0.1f", cg.cpA.get_coverage(), cg.cpC.get_coverage(), cg.cpD.get_coverage(), cg.cpE.get_coverage(), cg.cpF.get_coverage());
 end
endmodule

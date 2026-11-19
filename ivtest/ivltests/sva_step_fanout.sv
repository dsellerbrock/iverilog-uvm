// IEEE 1800-2017/2023 39.4.2 and 39.5.2: one step per parent attempt.
module sva_step_fanout;
  bit clk, oclk, eclk;
  bit a, b, c, x, y, d, e, f;
  bit tag, observed, immediate_ok = 1;

  // The child accepts at t=25 while the second antecedent branch dies.
  fan: assert property (@(posedge clk) a ##[1:2] b |=> c) else ;

  // Two live siblings at t=75: the older reaches f, the younger passes
  // the guard on its own saved value and then fails e.
  property siblings;
    bit saved;
    x ##[1:2] y |-> (d, saved = tag) ##1 (saved == observed) ##0 e ##1 f;
  endproperty
  sib: assert property (@(posedge oclk) siblings) else ;

  // The only child passes at t=105. The parent accepts at t=115.
  early: assume property (@(posedge eclk) a ##[1:2] b |-> immediate_ok) else ;

  initial repeat (7) #5 clk = ~clk;
  initial begin
    #40;
    repeat (9) #5 oclk = ~oclk;
  end
  initial begin
    #90;
    repeat (5) #5 eclk = ~eclk;
  end

  initial begin
    #1 $fanout_steps;
    a = 1;
    #10 a = 0; b = 1;
    #10 b = 0; c = 1;
    #10 c = 0;
    #10 x = 1;
    #10 x = 0; y = 1; d = 1;
    #10 e = 1; tag = 1;
    #10 y = 0; d = 0; e = 0; f = 1; observed = 1;
    #10 f = 0;
    #10 a = 1;
    #10 a = 0; b = 1;
    #10 b = 0;
    #10 $finish(0);
  end
endmodule

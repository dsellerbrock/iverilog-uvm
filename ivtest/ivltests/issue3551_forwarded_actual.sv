`timescale 1ns/1ns
module issue3551_sequence_source(input bit prefix, b, suffix);
  sequence body(q);
    prefix ##[1:2] q ##1 suffix;
  endsequence

  sequence relay(q);
    body(.q(q));
  endsequence

  sequence build(x);
    relay(x ##[1:2] b);
  endsequence
endmodule

module issue3551_forwarded_actual;
  bit clk, a, prefix, child_b, suffix;
  always #5 clk = ~clk;

  issue3551_sequence_source source(prefix, child_b, suffix);

  if (1) begin : caller
    bit a, b;
    int passes[4];
    time tick[4];

    task automatic matched(int which);
      passes[which]++;
      tick[which] = $time;
    endtask

    cover sequence (@(posedge clk) source.relay(((a) ##[1:2] b))) matched(0);
    cover sequence (@(posedge clk)
        source.prefix ##[1:2] a ##[1:2] b ##1 source.suffix) matched(1);
    cover sequence (@(posedge clk) source.build(a)) matched(2);
    cover sequence (@(posedge clk)
        source.prefix ##[1:2] a ##[1:2] source.b ##1 source.suffix) matched(3);

    initial begin
      #1  prefix = 1;
      #9  prefix = 0;
      #10 a = 1;
      #10 a = 0; b = 1;
      #10 b = 0; child_b = 1; suffix = 1;
      #10 child_b = 0;
      #10 suffix = 0; prefix = 1;
      #10 prefix = 0;
      #10 a = 1;
      #10 a = 0; b = 1;
      #10 b = 0; child_b = 1;
      #10 child_b = 0;
      #10;
      for (int i = 0; i < 4; i++) begin
        if (passes[i] != 1 || tick[i] != (i < 2 ? 45 : 55))
          $fatal(1, "case %0d had %0d matches, last at %0t", i, passes[i], tick[i]);
      end
      $display("PASSED");
      $finish(0);
    end
  end
endmodule

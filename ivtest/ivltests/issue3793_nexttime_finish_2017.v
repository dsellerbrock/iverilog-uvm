module main;
  bit clk, b;

  assert property (@(posedge clk) nexttime[2] b[=2])
    $error("unexpected weak success"); else $error("unexpected weak failure");
  assert property (@(posedge clk) s_nexttime[2] b[=2])
    $error("unexpected indexed success"); else $display("missing indexed target");
  assume property (@(posedge clk) s_nexttime b[->1])
    $error("unexpected unindexed success"); else $display("missing next target");
  assert property (@(posedge clk) nexttime strong(b[=2:4]))
    $error("unexpected strong child success"); else $display("pending strong child");
  assert property (@(posedge clk) s_nexttime[0] weak(b[->2]))
    $error("unexpected aligned success"); else $error("unexpected aligned failure");

  killed: assert property (@(posedge clk) s_nexttime[2] strong(b[->2]))
    $error("unexpected killed success"); else $error("unexpected killed failure");

  initial begin
    repeat (3) begin
      #1 clk = 1;
      #1 clk = 0;
    end
    $assertkill(0, killed);
    $asserton(0, killed);
    #1 $finish(0);
  end
endmodule

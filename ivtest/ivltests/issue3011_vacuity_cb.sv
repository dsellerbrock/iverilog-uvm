// Verify VPI success classification independently of pass action control.
module issue3011_vacuity_cb;
  bit clk = 0;
  bit a = 0, b = 1;
  always #5 clk = ~clk;
  ai: assert property (@(posedge clk) if (a) b);
  ae: assert property (@(posedge clk) if (a) b else b);
  am: assert property (@(posedge clk) a implies b);
  ac: assert property (@(posedge clk) case (a) 1'b1: b; endcase);
  ad: assert property (@(posedge clk) case (a) 1'b1: b; default: b; endcase);
  an: assert property (@(posedge clk) if (b) (if (a) b));
  ax: assert property (@(posedge clk) b);
  initial begin
    $vac_setup;
    @(negedge clk) a = 1;
    #6 $vac_dump;
    $finish;
  end
endmodule

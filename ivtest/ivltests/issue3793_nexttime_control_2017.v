module main;
  bit clk, dis;
  logic b;
  int tick, passes, failures, procedural_passes;

  controlled: assert property (@(posedge clk) disable iff (dis)
                               nexttime[2] b[->2])
    passes++; else failures++;

  initial begin
    repeat (3)
      assert property (@(posedge clk) nexttime b[=1])
        procedural_passes++; else $fatal(1, "procedural assertion failed");
  end

  initial begin
    for (tick = 1; tick <= 16; tick++) begin
      case (tick)
        3: $assertoff(0, controlled);
        5: $asserton(0, controlled);
        7: begin
          $assertkill(0, controlled);
          $asserton(0, controlled);
        end
        13: $assertcontrol(7, 1, 1, 0, controlled);
        14: $assertcontrol(6, 1, 1, 0, controlled);
        15: $assertcontrol(9, 1, 1, 0, controlled);
        16: $assertcontrol(8, 1, 1, 0, controlled);
      endcase

      case (tick)
        1, 2, 5, 6: b = 0;
        15, 16: b = 1'bx;
        default: b = 1;
      endcase
      #2 clk = 1;
      #1 clk = 0;
      if (passes != (tick == 4 || tick == 14 ? 1 : 0) ||
          failures != (tick == 16 ? 1 : 0) ||
          procedural_passes != (tick == 3 ? 3 : 0))
        $fatal(1, "tick %0d pass=%0d fail=%0d procedural=%0d",
               tick, passes, failures, procedural_passes);
      if (passes || failures || procedural_passes)
        $display("tick %0d pass=%0d fail=%0d procedural=%0d",
                 tick, passes, failures, procedural_passes);
      passes = 0;
      failures = 0;
      procedural_passes = 0;

      if (tick == 9) begin
        // Abort a searching child and two starts awaiting their targets.
        #1 dis = 1;
        #1 dis = 0;
      end
    end
    $display("PASSED");
  end
endmodule

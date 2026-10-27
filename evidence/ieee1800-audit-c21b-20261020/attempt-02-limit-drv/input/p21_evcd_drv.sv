`timescale 1ns/1ps

module p21_evcd_drv_dut(
    inout wire p,
    input wire out_weak_enable,
    input wire out_strong_enable
);
  assign (weak1, weak0) p = out_weak_enable ? 1'b0 : 1'bz;
  assign (strong1, strong0) p = out_strong_enable ? 1'b0 : 1'bz;
endmodule

module p21_evcd_drv;
  logic in_weak_enable = 0;
  logic in_strong_enable = 0;
  logic out_weak_enable = 0;
  logic out_strong_enable = 0;
  tri p;

  assign (weak1, weak0) p = in_weak_enable ? 1'b0 : 1'bz;
  assign (strong1, strong0) p = in_strong_enable ? 1'b0 : 1'bz;
  p21_evcd_drv_dut u(p, out_weak_enable, out_strong_enable);

  initial begin
    $dumpports(u, "drv.evcd");
    $dumpportslimit(2000, "drv.evcd");
    #1 begin
      in_weak_enable = 0;
      in_strong_enable = 1;
    end
    #1 out_weak_enable = 1;
    #1 begin
      in_strong_enable = 0;
      in_weak_enable = 1;
      out_weak_enable = 0;
      out_strong_enable = 1;
    end
    #1 in_strong_enable = 1;
    #1 begin
      in_strong_enable = 0;
      in_weak_enable = 1;
      out_strong_enable = 0;
      out_weak_enable = 1;
    end
    #1 begin
      in_weak_enable = 0;
      out_weak_enable = 0;
    end
    #1 $finish;
  end
endmodule

`timescale 1ns/1ps

module p21_evcd_leaf(input wire d);
endmodule

module p21_evcd_limit;
  logic limited_value = 0;
  logic control_value = 0;
  p21_evcd_leaf limited(limited_value);
  p21_evcd_leaf control(control_value);

  initial begin
    $dumpports(limited, "lim.evcd");
    $dumpports(control, "control.evcd");
    $dumpportslimit(200, "lim.evcd");
    #1 begin
      limited_value = 1;
      control_value = 1;
    end
    #1 $dumpportsoff("unmatched.evcd");
    repeat (50) begin
      #1 begin
        limited_value = ~limited_value;
        control_value = ~control_value;
      end
    end
    $finish;
  end
endmodule

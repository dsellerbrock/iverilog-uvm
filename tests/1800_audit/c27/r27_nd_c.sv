module top #(parameter p=1, q=2); wire a=1, b=0, c; initial #1 $display("NC %b", a); endmodule

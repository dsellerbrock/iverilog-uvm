module top #(parameter WIDTH=2);
 case (WIDTH) 1: begin:adder wire y=1; end 2: begin:adder wire y=0; end default: begin:adder wire y=1; end endcase
 initial #1 $display("G7 %b", adder.y);
endmodule

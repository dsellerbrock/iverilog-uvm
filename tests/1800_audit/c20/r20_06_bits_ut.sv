module m; typedef struct {logic valid; bit [8:1] data;} MyType; initial $display("ut %0d", $bits(MyType)); endmodule

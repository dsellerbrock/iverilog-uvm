module m; typedef struct {logic valid; bit [8:1] data;} MyType; MyType mt; initial $display("uv %0d", $bits(mt)); endmodule

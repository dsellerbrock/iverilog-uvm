module m; typedef struct packed {logic valid; bit [8:1] data;} PT; initial $display("pt %0d", $bits(PT)); endmodule

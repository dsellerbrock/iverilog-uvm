class box; static int state=9; static function int f; return state; endfunction endclass
module test; localparam int X=box::f(); endmodule

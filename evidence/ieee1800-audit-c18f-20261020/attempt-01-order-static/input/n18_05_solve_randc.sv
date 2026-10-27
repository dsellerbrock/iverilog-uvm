class C; randc bit [3:0] a; rand int b; constraint o { solve a before b; } endclass module t; endmodule

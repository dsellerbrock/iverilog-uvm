class C; rand int a, b; constraint o { solve a before b; solve b before a; } endclass module t; endmodule

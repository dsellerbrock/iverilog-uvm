typedef struct { int values[2]; } row_t;
module main;
 row_t rows[2];
 initial foreach(rows[missing].values[j]) $display("%0d", j);
endmodule

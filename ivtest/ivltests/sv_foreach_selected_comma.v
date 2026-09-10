typedef struct { int values[2]; } row_t;
module main;
 row_t rows[2];
 int a,b;
 initial foreach(rows[a,b].values[j]) $display("%0d",j);
 initial foreach(rows[].values[j]) $display("%0d",j);
endmodule

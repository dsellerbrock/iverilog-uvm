typedef enum {X, Y} e_t; typedef struct {int a;} s_t; class K; endclass
module s #(type struct S = s_t); endmodule module m; s u(); endmodule

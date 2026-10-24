typedef enum {X, Y} e_t; typedef struct {int a;} s_t; class K; endclass
module s #(type class C = K); endmodule module m; s u(); endmodule

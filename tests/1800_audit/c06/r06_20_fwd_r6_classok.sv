typedef enum {X, Y} e_t; typedef struct {int a;} s_t; class K; endclass
class P #(type enum E = e_t); E v; endclass module m; P#(e_t) p = new; endmodule

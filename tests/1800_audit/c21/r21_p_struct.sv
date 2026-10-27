module m;
typedef enum {ON,OFF} e_t;
typedef struct {e_t sw; string s;} pr_t;
pr_t x;
initial begin
  x.sw=OFF; x.s="hi";
  $display("struct [%p]", x);
end
endmodule

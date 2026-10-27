module m;
typedef enum {ON,OFF} e_t;
typedef struct {e_t sw; string s;} pr_t;
pr_t va[int];
initial begin
  va[10].sw=OFF; va[10].s="s10";
  $display("assoc_struct [%p]", va);
end
endmodule

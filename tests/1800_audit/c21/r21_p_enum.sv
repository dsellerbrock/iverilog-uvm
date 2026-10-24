module m;
typedef enum {ON,OFF} e_t;
e_t e;
initial begin
  e=OFF;
  $display("enum [%p]", e);
end
endmodule

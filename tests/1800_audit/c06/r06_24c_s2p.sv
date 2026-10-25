module t;
typedef struct {byte a; byte b;} s_t; s_t s; typedef bit [15:0] p16_t; p16_t v;
initial begin s.a=8'h12; s.b=8'h34; v=p16_t'(s); $display("s2p %h (expect 1234)",v); end
endmodule

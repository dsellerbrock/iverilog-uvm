module top;
 typedef enum {E0,E1} e_t; typedef enum bit [3:0] {F0,F1} f_t; typedef struct packed {logic [3:0] a; bit [1:0] b;} ps_t;
 typedef struct {int x; logic [1:0] y;} us_t;
 bit [3:0] vb; logic [7:0] vl; int vi; shortint vs; longint vq; byte vy; e_t ve; f_t vf; shortreal vr; ps_t vp; logic [1:0][3:0] vm; us_t vu;
 initial begin $dumpfile("typemap.vcd"); $dumpvars(0,top); #1 vb=1; vi=2; ve=E1; vf=F1; vp='{4'h5,2'h1}; vu.x=3; #1 $finish; end
endmodule

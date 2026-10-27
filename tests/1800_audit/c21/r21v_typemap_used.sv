module top;
 typedef enum {E0,E1} e_t; typedef enum bit [3:0] {F0,F1} f_t; typedef struct packed {logic [3:0] a; bit [1:0] b;} ps_t;
 typedef struct {int x; logic [1:0] y;} us_t;
 bit [3:0] vb; logic [7:0] vl; int vi; shortint vs; longint vq; byte vy; e_t ve; f_t vf; shortreal vr; ps_t vp; logic [1:0][3:0] vm; us_t vu;
 initial begin
  $dumpfile("typemap-used.vcd"); $dumpvars(0,top);
  #1 vb=1; vl=2; vi=3; vs=4; vq=5; vy=6; ve=E1; vf=F1; vr=1.5; vp='{4'h5,2'h1}; vm=8'hab; vu.x=3; vu.y=2'b10;
  $display("%0d %0d %0d %0d %0d %0d %0d %0d %0.2f %0d %0d %0d %0d",vb,vl,vi,vs,vq,vy,ve,vf,vr,vp,vm,vu.x,vu.y);
  #1 $finish;
 end
endmodule

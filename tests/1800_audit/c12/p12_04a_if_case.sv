module p12a;
int p=0,f=0; task automatic ck(input string i,input bit c); if(c)p++; else begin f++;$display("FAIL %s",i); end endtask
int cnt=0,hit,r; logic [3:0] a; logic [1:0] sel; logic [7:0] s8; logic signed [3:0] sg;
function int ev(int v); cnt++; return v; endfunction
initial begin
a=4'bx; hit=0; if (a) hit=1; else hit=2; ck("if_x",hit==2);
r=9; if (0) if (1) r=1; else r=2; ck("dangling",r==9);
cnt=0; hit=0; if (ev(0)) hit=1; else if (ev(1)) hit=2; else if (ev(1)) hit=3; ck("chain",hit==2&&cnt==2);
cnt=0; case (ev(2)) 1: hit=1; 2: hit=2; 2: hit=3; default: hit=4; endcase ck("case_once",hit==2&&cnt==1);
cnt=0; case (2) ev(1): hit=1; ev(2): hit=2; ev(2): hit=3; endcase ck("case_items",hit==2&&cnt==2);
sel=2'bx0; case (sel) 2'b00: hit=0; 2'bx0: hit=5; default: hit=9; endcase ck("case_xz",hit==5);
case (1'bz) 1'bx: hit=2; 1'bz: hit=1; default: hit=3; endcase ck("case_z",hit==1);
hit=7; case (3) 1: hit=1; endcase ck("case_nodef",hit==7);
s8=8'h0F; case (s8) 4'hF: hit=1; default: hit=2; endcase ck("case_ext",hit==1);
sg=-1; case (sg) 8'b0000_1111: hit=1; default: hit=2; endcase ck("case_unsigned_mix",hit==1);
case (sg) 8'sb1111_1111: hit=1; default: hit=2; endcase ck("case_signed",hit==1);
$display("RESULT pass=%0d fail=%0d",p,f);
a=3; $display("V1 unique no match"); unique if ((a==0)||(a==1)) $display("0or1"); else if (a==2) $display("2"); else if (a==4) $display("4");
#1 $display("V2 priority covered"); a=5; priority if (a[2:1]==0) $display("a"); else if (a[2]==0) $display("b"); else $display("c");
#1 $display("V3 unique0 no match"); a=3; unique0 if ((a==0)||(a==1)) $display("0or1"); else if (a==2) $display("2");
#1 $display("V4 unique overlap"); a=0; unique if (a==0) $display("first"); else if (a<2) $display("second");
#1 $display("V5 end"); end endmodule

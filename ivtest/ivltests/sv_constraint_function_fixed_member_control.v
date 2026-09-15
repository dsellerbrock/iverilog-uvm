class leaf;
 rand int x;
endclass
class holder;
 rand leaf q[2];
 constraint c {foreach(q[i]) q[i].x==i+3;}
 function new; q[0]=new; q[1]=new; endfunction
endclass
module test;
 holder h; int ok;
 initial begin
 h=new;ok=h.randomize();
 if(ok!=1 || h.q[0].x!=3 || h.q[1].x!=4) $fatal(1,"fixed member control");
 $display("PASSED");end
endmodule

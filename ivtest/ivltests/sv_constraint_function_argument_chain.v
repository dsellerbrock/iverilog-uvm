// IEEE 1800-2017 18.5.12 / 1800-2023 18.5.11: functions in constraints.
class C;
 rand bit[7:0] a,b,c;
 function bit[7:0] f(input bit[7:0] v); return v+1; endfunction
 constraint order_c {a==3; b==f(a); c==f(b);}
endclass
module test;
 C obj; int ok;
 initial begin obj=new; ok=obj.randomize();
 if(ok!=1 || obj.a!==3 || obj.b!==4 || obj.c!==5) $fatal(1,"priority chain");
 $display("PASSED"); end
endmodule

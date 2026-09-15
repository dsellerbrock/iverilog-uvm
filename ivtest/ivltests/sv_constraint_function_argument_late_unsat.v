// IEEE 1800-2017 18.5.12 / 1800-2023 18.5.11: functions in constraints.
class C;
 rand bit[7:0] x,y;
 int posts;
 function bit[7:0] f(input bit[7:0] v); return v+1; endfunction
 function void post_randomize(); posts++; endfunction
 constraint c {y==9; x==f(y);}
 constraint clash {x==11;}
endclass
module test;
 C c; int ok;
 initial begin c=new; c.x=37; c.y=42;
 ok=c.randomize(); if(ok!=0 || c.x!==37 || c.y!==42 || c.posts!=0) $fatal(1,"late unsat rollback");
 c.clash.constraint_mode(0); ok=c.randomize();
 if(ok!=1 || c.x!==10 || c.y!==9 || c.posts!=1) $fatal(1,"retry after rollback");
 $display("PASSED"); end
endmodule

class C;
 rand bit[7:0] x;
 bit[7:0] state_value;
 function bit[7:0] f(output bit[7:0] v); return 7; endfunction
 constraint c { x==f(state_value); }
endclass
module test;
 C c; int ok;
 initial begin c=new; ok=c.randomize(); end
endmodule

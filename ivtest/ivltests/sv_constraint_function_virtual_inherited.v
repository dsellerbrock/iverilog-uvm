// IEEE 1800-2017 18.5.12 / 1800-2023 18.5.11: functions in constraints.
class Base;
 rand bit[7:0] x;
 virtual function bit[7:0] value(); return 7; endfunction
 constraint c {x==value();}
endclass
class Derived extends Base; endclass
module test;
 Derived d; int ok;
 initial begin d=new; ok=d.randomize();
 if(ok!=1 || d.x!==7) $fatal(1,"inherited virtual result ok=%0d x=%0d",ok,d.x);
 ok=d.randomize();
 if(ok!=1 || d.x!==7) $fatal(1,"inherited virtual second solve");
 $display("PASSED"); end
endmodule

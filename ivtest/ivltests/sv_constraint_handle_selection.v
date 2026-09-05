// IEEE1800-2017/2023 18.8,18.11; 2017 18.5.13 / 2023 18.5.12.
class sel_leaf; int value; endclass
class sel_guard;
  rand bit enable, x; sel_leaf absent;
  constraint c { if(enable) x == absent.value; }
endclass
class pow_guard;
  rand bit x; sel_leaf absent;
  constraint c { if ((absent.value == 0) || (x ** 0)) x == 1; }
endclass
module main;
  sel_guard a=new; pow_guard b=new;
  initial begin
    a.enable=0; a.enable.rand_mode(0);
    if(!a.randomize() || a.enable!=0) $fatal(1,"disabled rand guard");
    a.enable.rand_mode(1);
    if(!a.randomize(x) || a.enable!=0) $fatal(1,"explicit selector guard");
    if(!a.randomize(null) || a.enable!=0) $fatal(1,"checker selector guard");
    a.enable=1; a.x=0;
    if(a.randomize(x) || a.x!=0) $fatal(1,"enabled invalid read or rollback");
    if(b.randomize()) $fatal(1,"x**0 ceased to be RANDOM");
    $display("PASSED");
  end
endmodule

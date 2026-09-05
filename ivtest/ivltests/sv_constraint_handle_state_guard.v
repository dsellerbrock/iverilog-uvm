// IEEE 1800-2017 18.5.13 / 1800-2023 18.5.12: state and RANDOM guards.
class leaf; int value; endclass
class state_guard;
  bit enable=0; leaf missing; rand bit x;
  constraint c { if(enable) x == missing.value; }
endclass
class random_guard;
  leaf missing; rand bit x;
  constraint c { if ((missing.value == 0) || (x == x)) x==0; }
endclass
module main;
  state_guard a=new; random_guard b=new;
  initial begin
    if(!a.randomize()) $fatal(1,"inactive state guard did not exclude null read");
    if(b.randomize()) $fatal(1,"RANDOM expression masked ERROR");
    $display("PASSED");
  end
endmodule

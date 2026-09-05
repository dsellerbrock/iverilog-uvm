// IEEE1800-2017/2023 18.3; 2017 18.5.13 / 2023 18.5.12: E dominates R.
class guard_xz;
  rand bit r, y; logic state_x=1'bx; bit excluded;
  constraint c { if (!excluded) (r == state_x) -> y == 1; }
endclass
module main;
  guard_xz c=new;
  initial begin
    c.r=1; c.y=0;
    if(c.randomize()) $fatal(1,"RANDOM hid state X");
    if(c.r!=1 || c.y!=0) $fatal(1,"X failure changed values");
    c.excluded=1;
    if(!c.randomize()) $fatal(1,"false outer guard did not exclude ERROR");
    $display("PASSED");
  end
endmodule

int side_effects;
function automatic bit impure(input bit value);
  side_effects++;
  return value;
endfunction
class item;
  rand bit [1:0] enable;
  rand bit region[2];
  constraint c {
    foreach (region[i]) region[i] == impure(enable[i]);
  }
endclass
module test;
  item x;
  initial begin
    x = new;
    if (x.randomize()) $fatal(1, "impure foreach function was accepted");
  end
endmodule

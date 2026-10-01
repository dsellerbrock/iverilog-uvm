// A reversed packed select on an array-method iterator must not become
// an unconstrained bit in a class constraint.
class c;
  rand logic [1:0] a[1];
  constraint k { a.sum() with (item[0:1]) == 1; }
endclass
module test;
  initial begin
    c o;
    o = new;
    if (o.randomize()) $fatal(1, "reversed iterator select succeeded");
  end
endmodule

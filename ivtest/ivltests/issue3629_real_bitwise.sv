module test;
  covergroup cg with function sample(real r, shortreal s, bit [3:0] b);
    a: coverpoint (r & b) { bins z = {0}; }
    o: coverpoint (b | r) { bins z = {0}; }
    x: coverpoint ((s + 1.0) ^ b) { bins z = {0}; }
    n: coverpoint (~r) { bins z = {0}; }
    nested: coverpoint ((r & b) + 1) { bins z = {0}; }
  endgroup
  cg c;
  initial c = new;
endmodule

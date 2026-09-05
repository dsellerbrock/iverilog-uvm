// IEEE 1800-2017/2023 18.5.1: a second prototype is not an external body.
class C;
  extern constraint c;
  constraint c;
endclass
module main;
  C obj = new;
endmodule

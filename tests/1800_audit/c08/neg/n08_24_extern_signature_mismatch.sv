// IEEE 1800-2017/2023 §8.24: an out-of-block declaration must match its prototype.
class O;
  extern function int f(int a);
endclass

function int O::f(int a, int b);
  return a + b;
endfunction

module n08_24_extern_signature_mismatch;
endmodule

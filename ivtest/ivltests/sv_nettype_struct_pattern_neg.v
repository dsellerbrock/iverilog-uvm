// A user-defined nettype over an unpacked structure (IEEE 1800-2017/2023
// 6.6.7 d) may have a single continuous driver even without a resolution
// function; only multiple drivers are an error. An assignment pattern is a
// valid driver. This used to abort the compiler on an assertion, then was
// a diagnosed unsupported form; issue #923 implements it.
typedef struct { real v; int n; } sig_t;
nettype sig_t sig_net;
module top;
  sig_net w;
  assign w = '{1.5, 3};
  initial begin
    #1;
    if (w.v == 1.5 && w.n == 3) $display("PASSED");
    else $display("FAILED: w.v=%f w.n=%0d", w.v, w.n);
  end
endmodule

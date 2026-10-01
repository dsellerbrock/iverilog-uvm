// A user-defined nettype over an unpacked structure cannot be given a driver
// from an assignment pattern: there is no net representation for it (IEEE
// 1800-2017/2023 6.6.7). This used to abort the compiler on an assertion;
// it is now a diagnosed unsupported form.
typedef struct { real v; int n; } sig_t;
nettype sig_t sig_net;
module top;
  sig_net w;
  assign w = '{1.5, 3};
endmodule

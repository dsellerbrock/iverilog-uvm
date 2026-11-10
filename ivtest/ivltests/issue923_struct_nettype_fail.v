// IEEE 1800-2017/2023 6.6.7: a net of a nettype without a resolution
// function shall not have multiple drivers, and a net is never a
// procedural assignment target. Forcing an unpacked struct (net or
// variable) is not supported yet and is reported instead of crashing.
module top;
  typedef struct { int a; } st_t;
  nettype st_t ns;
  st_t v1, v2;
  ns w;
  ns p;
  assign w = v1;
  assign w = v2;
  initial p = v1;
  ns f;
  assign f = v1;
  initial force f = v2;
  initial force v1.a = 3;
endmodule

// A resolved struct nettype net driven through a port is not supported yet.
package pk923;
  typedef struct { real r; } R;
  function automatic R Rsum (input R d[]);
    Rsum.r = 0.0;
    foreach (d[i]) Rsum.r += d[i].r;
  endfunction
  nettype R wR with Rsum;
endpackage

module src923(output pk923::R o);
  assign o = '{1.0};
endmodule

module port_top;
  import pk923::*;
  wR w;
  src923 u(.o(w));
endmodule

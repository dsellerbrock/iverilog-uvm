interface bus; logic x; modport mp(input x); endinterface
module top;
  typedef int ordinary_t;
  typedef virtual interface bus vif_t;
  typedef virtual interface bus.mp vif_mp_t;
  ordinary_t ordinary;
endmodule

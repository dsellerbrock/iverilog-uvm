// IEEE 1800-2023 25.7.3: an extern task needs a module that defines it, and
// an extern task prototype belongs in an interface.
interface fb;
  extern task inc();
  modport slave(export inc);
endinterface

module top;
  fb i();
  initial i.inc();
endmodule

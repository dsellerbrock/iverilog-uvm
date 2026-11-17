module tb;
  bit a, b;
  covergroup cg;
    ca: coverpoint a;
    cb: coverpoint b;
    cx: cross ca, cb {
      ignore_bins bad = !(binsof(ca) with (ca == 0));
    }
  endgroup
  cg c;
  initial c = new;
endmodule

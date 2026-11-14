// Issue #1202 (IEEE 1800-2023 19.5.1.1): "Only the name of the coverpoint
// containing the bin being defined shall be allowed; no other coverpoint
// names shall be permitted." This bin names another coverpoint.
module top;
  bit [3:0] v, w;
  covergroup cg;
    cp: coverpoint v;
    cq: coverpoint w { bins other = cp with (item < 2); }
  endgroup
  cg c;
  initial c = new;
endmodule

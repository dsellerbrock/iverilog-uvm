// An unpacked slice cannot reverse its declaration direction.
module test;
  bit [7:0] down [7:2];
  bit [23:0] got;
  initial begin
    got = {>>8{down[4:6]}};
  end
endmodule

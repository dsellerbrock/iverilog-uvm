// IEEE 1800-2023 38.34: vpiStringVal and vpiStrengthVal are illegal formats
// for putting a value to a real object; the put fails and leaves it alone.
module top;
  real r = 1.5;
  real ra [0:1];
  initial begin
    ra[0] = 2.5; ra[1] = 3.5;
    #1 $probe;
    $display("r=%.1f ra0=%.1f DONE", r, ra[0]);
  end
endmodule

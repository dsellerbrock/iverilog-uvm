// M14 negative: randcase (IEEE 1800-2017 18.16) is not implemented and
// must be diagnosed loudly (previously a silent empty block that ran
// no branch).
module top;
  int c1=0;
  initial begin
    randcase 1: c1++; 1: c1++; endcase
    $finish(0);
  end
endmodule

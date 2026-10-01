// $bitstoreal/$bitstoshortreal convert the low 64/32 bits of a wider
// vector. UVM's uvm_field_real macro passes its 4096-bit bitstream to
// $bitstoreal, and the argument width was rejected as a run-time error.
class status_container;
  logic [4095:0] bitstream;
endclass

module main;
  logic [4095:0] wide;
  logic [127:0] mid;
  status_container sc = new;
  real r;
  shortreal s;
  int errors;

  initial begin
    wide = {4032'hdead_beef_cafe_f00d, $realtobits(3.5)};
    r = $bitstoreal(wide);
    if (r != 3.5) begin $display("FAILED wide real %f", r); errors++; end

    mid = {64'h1234_5678_9abc_def0, $realtobits(-0.25)};
    r = $bitstoreal(mid);
    if (r != -0.25) begin $display("FAILED mid real %f", r); errors++; end

    sc.bitstream = {4032'h1, $realtobits(1024.0)};
    r = $bitstoreal(sc.bitstream);
    if (r != 1024.0) begin $display("FAILED property real %f", r); errors++; end

    wide = {4064'h7, $shortrealtobits(2.5)};
    s = $bitstoshortreal(wide);
    if (s != 2.5) begin $display("FAILED shortreal %f", s); errors++; end

    r = $bitstoreal($realtobits(6.25));
    if (r != 6.25) begin $display("FAILED exact width %f", r); errors++; end

    if (errors == 0) $display("PASSED");
  end
endmodule

module i2c_acq_transition_bins_repro;
  covergroup acq_cg with function sample(bit [2:0] token);
    cp: coverpoint token {
      bins ack_before_stop = (3'b011 => 3'b100);
      bins nack_before_rstart = (3'b011 => 3'b111);
    }
  endgroup
  acq_cg cg;
  initial begin
    cg = new;
    cg.sample(3'b011);
    cg.sample(3'b101);  // Impossible NACK before STOP is not a coverage bin.
    if (cg.get_coverage() != 0) $fatal(1, "impossible transition covered");
    cg.sample(3'b011);
    cg.sample(3'b100);
    if (cg.get_coverage() != 50) $fatal(1, "ACK/STOP bin missing");
    cg.sample(3'b011);
    cg.sample(3'b111);
    if (cg.get_coverage() != 100) $fatal(1, "NACK/RSTART bin missing");
    $display("PASS I2C ACQ transitions");
  end
endmodule

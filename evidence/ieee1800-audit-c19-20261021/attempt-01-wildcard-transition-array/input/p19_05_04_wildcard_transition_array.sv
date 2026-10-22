module p19_05_04_wildcard_transition_array;
  covergroup cg with function sample(input bit [1:0] event_value);
    cp: coverpoint event_value {
      wildcard bins T0_3_array[] = (2'b0x => 2'b1x);
    }
  endgroup

  cg cov = new;

  initial begin
    cov.sample(2'b00); cov.sample(2'b10);
    cov.sample(2'b00); cov.sample(2'b11);
    cov.sample(2'b01); cov.sample(2'b10);
    cov.sample(2'b01); cov.sample(2'b11);
    $display("observed inst_coverage=%0f", cov.get_inst_coverage());
    $finish;
  end
endmodule

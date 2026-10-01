interface bit_if;
  task automatic sample_bit(output bit sampled);
    sampled = 1'b1;
  endtask
endinterface

class bit_monitor;
  virtual bit_if vif;
  function new(virtual bit_if vif);
    this.vif = vif;
  endfunction
  task sample_byte(output bit [7:0] data);
    bit sampled;
    data = '0;
`ifdef SCALAR_TEMP
    for (int i = 7; i >= 0; i--) begin
      vif.sample_bit(sampled);
      data[i] = sampled;
    end
`else
    for (int i = 7; i >= 0; i--)
      vif.sample_bit(data[i]);
`endif
  endtask
endclass

module i2c_output_packed_bit_repro;
  bit_if vif();
  bit_monitor monitor;
  bit [7:0] observed;
  initial begin
    monitor = new(vif);
    monitor.sample_byte(observed);
    if (observed !== 8'hff) $fatal(1, "copy-out lost bits: %h", observed);
    $display("PASS output packed bit");
  end
endmodule

module top;
`line 100 "mapped_source.sv" 0
  logic signal_var;
  wire signal_net;
  logic [3:0] selected_var;
  class item;
    int value;
  endclass
  item class_var;

  generate
    if (1) begin : genblk
      logic generated_signal;
    end
  endgenerate

  assign signal_net = signal_var;
  initial begin
    $vpi_check_source(signal_var, "mapped_source.sv", 100);
    $vpi_check_source(signal_net, "mapped_source.sv", 101);
    $vpi_check_source(selected_var[2], "mapped_source.sv", 102);
    $vpi_check_source(selected_var[3:1], "mapped_source.sv", 102);
    $vpi_check_source(class_var, "mapped_source.sv", 106);
    $vpi_check_source(genblk.generated_signal, "mapped_source.sv", 110);
    $display("PASS VPI source locations");
    $finish;
  end
endmodule

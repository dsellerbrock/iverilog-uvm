module m12_force_cb_regbit;
  reg [7:0] data;
  reg [7:0] part_data;
  reg drive;
  wire [7:0] net_data = {8{drive}};

  initial begin
    data = 0;
    part_data = 0;
    drive = 0;
    $m12_force_cb_setup(data, part_data[5:2]);
    #1 force data = 8'h12;
    #1 release data;
    #1 force part_data[5:2] = 4'hf;
    #1 release part_data[5:2];
    #1 force net_data[3] = 1'b1;
    #1 release net_data[3];
    #1 $m12_force_cb_check;
    $finish(0);
  end
endmodule

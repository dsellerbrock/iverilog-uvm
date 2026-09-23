module m12_force_cb_stmt_obj;
  reg [3:0] data;
  reg drive;
  wire [3:0] net_data = {4{drive}};

  initial begin
    data = 0;
    drive = 0;
    $m12_force_cb_stmt_setup(data, net_data);
    #1 force data = 4'h1;
    #1 force data = 4'h2;
    #1 release data;
    #1 force net_data = 4'hc;
    #1 release net_data;
    #1 force {data, net_data} = 8'h5a;
    #1 release {data, net_data};
    #1 $m12_force_cb_stmt_check;
    $finish(0);
  end
endmodule

module dumpports_activity_leaf(input wire value);
endmodule

module dumpports_activity_cb;
  reg value = 0;
  reg second = 1;
  tri dumped_net, control_net;

  assign dumped_net = value;
  assign dumped_net = second ? value : 1'bz;
  assign control_net = value;
  assign control_net = second ? value : 1'bz;

  dumpports_activity_leaf dumped(dumped_net);
  dumpports_activity_leaf control(control_net);

  initial begin
    $dumpports(dumped, "work/dumpports_activity_cb.evcd");
    #1 second = 0;
    #1 second = 1;
    #1 value = 1;
    #1 $check_dumpports_activity_callbacks;
  end
endmodule

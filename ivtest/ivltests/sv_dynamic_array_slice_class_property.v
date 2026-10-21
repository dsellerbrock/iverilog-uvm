typedef enum logic [1:0] {
  IDLE = 2'b00,
  BUSY = 2'b01
} activity_t;

class configuration;
  string interface_names[];
  activity_t interface_activity[];

  function void copy_from(input string names[], input activity_t activity[]);
    interface_names = new[2];
    interface_activity = new[2];
    interface_names = names[0:0];
    interface_activity = activity[0:0];
  endfunction
endclass

module test;
  string names[];
  activity_t activity[];
  configuration cfg;

  initial begin
    names = new[2];
    names[0] = "ahb_slave";
    names[1] = "ignored";
    activity = new[2];
    activity[0] = BUSY;
    activity[1] = IDLE;

    cfg = new;
    cfg.copy_from(names, activity);
    names[0] = "changed";
    activity[0] = IDLE;
    if (cfg.interface_names.size() != 1
        || cfg.interface_names[0] != "ahb_slave"
        || cfg.interface_activity.size() != 1
        || cfg.interface_activity[0] != BUSY) begin
      $display("FAILED: class properties did not receive the slices");
      $finish(1);
    end
    $display("PASSED");
  end
endmodule

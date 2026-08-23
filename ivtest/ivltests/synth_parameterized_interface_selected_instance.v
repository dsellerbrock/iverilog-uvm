`begin_keywords "1800-2012"

interface selected_instance_if #(parameter int W = 8);
  wire [W-1:0] value;
endinterface

module selected_instance_child (
  selected_instance_if port,
  input  logic [15:0] drive,
  output logic [15:0] seen
);
  assign port.value = drive;
  assign seen = port.value;
endmodule

module synth_parameterized_interface_selected_instance_netlist (
  input  logic [15:0] descending_drive,
  input  logic [15:0] ascending_drive,
  output logic [15:0] descending_seen,
  output logic [15:0] ascending_seen,
  output logic [15:0] descending_left,
  output logic [15:0] descending_selected,
  output logic [15:0] descending_right,
  output logic [15:0] ascending_left,
  output logic [15:0] ascending_selected,
  output logic [15:0] ascending_right
);
  function automatic int descending_middle();
    return 4;
  endfunction

  function automatic int ascending_middle();
    return -1;
  endfunction

  selected_instance_if #(.W(16)) descending [5:3] ();
  selected_instance_if #(.W(16)) ascending [-2:0] ();

  assign descending[5].value = 16'hd505;
  selected_instance_child descending_child(
    descending[descending_middle()], descending_drive, descending_seen
  );
  assign descending[3].value = 16'hd303;

  assign ascending[-2].value = 16'hae02;
  selected_instance_child ascending_child(
    ascending[ascending_middle()], ascending_drive, ascending_seen
  );
  assign ascending[0].value = 16'ha000;

  assign descending_left = descending[5].value;
  assign descending_selected = descending[4].value;
  assign descending_right = descending[3].value;
  assign ascending_left = ascending[-2].value;
  assign ascending_selected = ascending[-1].value;
  assign ascending_right = ascending[0].value;
endmodule

module synth_parameterized_interface_selected_instance;
  logic [15:0] descending_drive;
  logic [15:0] ascending_drive;
  logic [15:0] descending_seen;
  logic [15:0] ascending_seen;
  logic [15:0] descending_left;
  logic [15:0] descending_selected;
  logic [15:0] descending_right;
  logic [15:0] ascending_left;
  logic [15:0] ascending_selected;
  logic [15:0] ascending_right;

  synth_parameterized_interface_selected_instance_netlist dut(.*);

  (* ivl_synthesis_off *)
  initial begin
    descending_drive = 16'hde4d;
    ascending_drive = 16'hae1d;
    #1;
    if ({descending_seen, descending_left, descending_selected,
         descending_right, ascending_seen, ascending_left,
         ascending_selected, ascending_right} !==
        {16'hde4d, 16'hd505, 16'hde4d, 16'hd303,
         16'hae1d, 16'hae02, 16'hae1d, 16'ha000})
      $fatal(1, "FAILED descending=%h/%h/%h/%h ascending=%h/%h/%h/%h",
             descending_seen, descending_left, descending_selected,
             descending_right, ascending_seen, ascending_left,
             ascending_selected, ascending_right);
    $display("PASSED descending=%h/%h/%h/%h ascending=%h/%h/%h/%h",
             descending_seen, descending_left, descending_selected,
             descending_right, ascending_seen, ascending_left,
             ascending_selected, ascending_right);
  end
endmodule

`end_keywords

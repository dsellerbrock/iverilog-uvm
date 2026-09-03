// IEEE 1800-2017/2023 25.5/25.10: selecting a modport in a physical
// connection restricts the connected formal even when its header is
// unqualified. Both direction and membership restrictions must survive.
interface selected_access_if;
  logic listed_input;
  logic hidden;
  modport restricted(input listed_input);
endinterface

module write_selected_input(selected_access_if bus);
  initial bus.listed_input = 1'b1;
endmodule

module read_unlisted_member(selected_access_if bus);
  initial $display("hidden=%b", bus.hidden);
endmodule

module sv_interface_port_selected_actual_access_fail;
  selected_access_if bus();
  write_selected_input write_bad(.bus(bus.restricted));
  read_unlisted_member read_bad(.bus(bus.restricted));
endmodule

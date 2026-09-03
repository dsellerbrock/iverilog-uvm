// IEEE 1800-2017/2023 25.7: a modport selected on the actual retains its
// export-provider obligation when connected to an unqualified named formal.
interface selected_export_if;
  modport provider(export transmit);
endinterface

module selected_export_consumer(selected_export_if bus);
endmodule

module sv_interface_port_selected_actual_export_missing_fail;
  selected_export_if bus();
  selected_export_consumer consumer(.bus(bus.provider));
endmodule

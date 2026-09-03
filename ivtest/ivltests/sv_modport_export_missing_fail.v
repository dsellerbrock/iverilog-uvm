// IEEE 1800-2017/2023 25.7: an export names a provider subroutine in the
// connected module. It must not be silently accepted or routed to an
// interface-local method when the provider supplies no implementation.
interface export_missing_if;
  modport provider(export send);
endinterface

module export_missing_provider(export_missing_if.provider bus);
endmodule

module sv_modport_export_missing_fail;
  export_missing_if bus();
  export_missing_provider provider(.bus(bus.provider));
endmodule

// A grammar error inside a full modport prototype bypasses the normal ')'
// reduction. Recovery must clear the active item before the next legal
// modport begins; this test used to assert in pform_start_modport_item().
interface syntax_recovery_if;
  task invoke(input int value);
  endtask

  modport broken(import task invoke(input int value]));
  modport recovered(import task invoke(input int value));
endinterface

module sv_modport_tf_prototype_syntax_recovery_fail;
  syntax_recovery_if bus();
endmodule

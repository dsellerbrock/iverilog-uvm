// This is intentionally a second source file, not an `include. Before the
// file-boundary cleanup, its legal modport asserted because the preceding
// source left pform_cur_modport active.
interface recovered_file_if;
  task invoke(input int value); endtask
  modport recovered(import task invoke(input int value));
endinterface

module sv_modport_tf_prototype_file_recovery_fail;
  recovered_file_if bus();
endmodule

// A prototype that follows a non-task/function modport declaration is
// illegal. Each malformed continuation must diagnose independently; the
// first rejected prototype must not leave pending parser state that asserts
// while the second is parsed.
interface modport_tf_prototype_recovery_if;
  logic signal;
  modport broken(
      input signal,
      task first(),
      function int second()
  );
endinterface

module sv_modport_tf_prototype_recovery_fail;
endmodule

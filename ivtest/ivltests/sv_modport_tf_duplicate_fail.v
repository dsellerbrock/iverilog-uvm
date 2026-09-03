// IEEE 1800-2017/2023 25.7: a task/function name is declared once per
// modport and cannot appear with both import and export polarity.
interface duplicate_tf_if;
  task invoke(); endtask

  modport duplicate_identifier(import invoke, invoke);
  modport duplicate_prototype(import task invoke(), task invoke());
  modport cross_polarity(import invoke, export invoke);
endinterface

module sv_modport_tf_duplicate_fail;
  duplicate_tf_if bus();
endmodule

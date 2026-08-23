import uvm_pkg::*;
`include "uvm_macros.svh"

class m1_named_sequence extends uvm_sequence;
  `uvm_object_utils(m1_named_sequence)

  function new(string name = "m1_named_sequence");
    super.new(name);
  endfunction
endclass

module m1_uvm_sequence_factory_by_name_test;
  initial begin
    uvm_object obj;
    uvm_sequence seq;
    m1_named_sequence named_seq;

    obj = uvm_factory::get().create_object_by_name(
        "m1_named_sequence", "", "seq");
    if (obj == null)
      $fatal(1, "factory returned null");
    if (!$cast(seq, obj))
      $fatal(1, "factory object did not preserve uvm_sequence ancestry");
    if (!$cast(named_seq, obj))
      $fatal(1, "factory object did not preserve its concrete type");
    $display("PASS");
  end
endmodule

package packed_parameter_foreach_pkg;
  parameter bit [3:1] DESC = 3'b101;
  parameter bit [1:3] ASC = 3'b110;
  parameter bit [0:0] ONE = 1'b1;
  parameter UNTYPED = 7;
  parameter signed SIGNED = 7;

  class model;
    task run();
      int desc_count = 0;
      int desc_order = 0;
      int desc_bits = 0;
      int asc_count = 0;
      int asc_order = 0;
      int asc_bits = 0;
      int one_count = 0;
      int one_index = -1;
      int inferred_count = 0;
      int inferred_first = -1;
      int inferred_last = -1;
      int inferred_bits = 0;
      int signed_count = 0;
      int signed_first = -1;
      int signed_last = -1;
      foreach (DESC[i]) begin
        desc_count++;
        desc_order = desc_order * 10 + i;
        desc_bits += DESC[i];
      end
      foreach (ASC[i]) begin
        asc_count++;
        asc_order = asc_order * 10 + i;
        asc_bits += ASC[i];
      end
      foreach (ONE[i]) begin
        one_count++;
        one_index = i;
        if (ONE[i] !== 1'b1) $fatal(1, "wrong one-bit value");
      end
      foreach (UNTYPED[i]) begin
        inferred_count++;
        if (inferred_count == 1) inferred_first = i;
        inferred_last = i;
        inferred_bits += UNTYPED[i];
      end
      foreach (SIGNED[i]) begin
        signed_count++;
        if (signed_count == 1) signed_first = i;
        signed_last = i;
      end
      if (desc_count != 3 || desc_order != 321 || desc_bits != 2
          || asc_count != 3 || asc_order != 123 || asc_bits != 2
          || one_count != 1 || one_index != 0
          || inferred_count != 32 || inferred_first != 31
          || inferred_last != 0 || inferred_bits != 3
          || signed_count != 32 || signed_first != 31 || signed_last != 0)
        $fatal(1, "packed parameter foreach indices or values wrong");
      $display("PASSED");
    endtask
  endclass
endpackage

module main;
  packed_parameter_foreach_pkg::model obj;
  initial begin
    obj = new;
    obj.run();
  end
endmodule

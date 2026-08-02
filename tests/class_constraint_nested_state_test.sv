class class_constraint_nested_state_field;
  int m_size = 4;

  function int get_n_bits();
    return m_size;
  endfunction
endclass

class class_constraint_nested_state_cfg;
  int limit = 10;
  class_constraint_nested_state_field field = new;
endclass

class class_constraint_nested_state_item;
  rand int value;
  class_constraint_nested_state_cfg cfg = new;

  constraint nested_state_c {
    value < cfg.limit;
    value < (2 ** cfg.field.get_n_bits());
    (2 ** cfg.field.get_n_bits()) == 16;
    (value == 0) ? 16'hffff : (value < cfg.limit);
  }
endclass

module class_constraint_nested_state_test;
  initial begin
    class_constraint_nested_state_item item = new;

    repeat (20) begin
      if (!item.randomize()) $fatal(1, "nested-state constraint is unsatisfiable");
      if (item.value < 0 || item.value >= item.cfg.limit) begin
        $fatal(1, "nested-state constraint produced value %0d", item.value);
      end
    end

    $display("PASSED: nested class-state paths and get_n_bits constrain randomize");
    $finish;
  end
endmodule

class soft_defaults_item;
  rand bit preferred_one;
  rand bit preferred_zero;

  constraint defaults_c {
    soft preferred_one == 1'b1;
    soft preferred_zero == 1'b0;
  }
endclass

class soft_priority_item;
  rand bit value;

  constraint priority_c {
    soft value == 1'b0;
    soft value == 1'b1;
  }
endclass

module class_soft_candidate_fastpath_test;
  initial begin
    soft_defaults_item defaults;
    soft_priority_item prio;

    defaults = new;
    prio = new;

    repeat (100) begin
      if (!defaults.randomize())
        $fatal(1, "soft-default randomization failed");
      if (defaults.preferred_one != 1'b1 ||
          defaults.preferred_zero != 1'b0)
        $fatal(1, "soft defaults were not preferred");

      if (!prio.randomize())
        $fatal(1, "conflicting-soft randomization failed");
      if (prio.value != 1'b1)
        $fatal(1, "later soft constraint did not take priority");
    end

    $display("PASS: soft candidate fast path preserves priority");
  end
endmodule

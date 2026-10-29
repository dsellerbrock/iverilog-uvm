module top;
  int values[string];
  int defaults[string] = '{default: 9};

  task automatic observe(ref int slot);
  endtask

  task automatic update(ref int slot);
    slot = 17;
  endtask

  initial begin
    observe(values["missing"]);
    if (!values.exists("missing") || values.num() != 1
        || values["missing"] !== 0)
      $fatal(1, "ref actual did not allocate its default associative entry");

    observe(defaults["inherited"]);
    if (!defaults.exists("inherited") || defaults.num() != 1
        || defaults["inherited"] !== 9)
      $fatal(1, "ref actual did not allocate its user-default value");

    update(values["written"]);
    if (!values.exists("written") || values.num() != 2
        || values["written"] !== 17)
      $fatal(1, "ref formal did not update its associative actual");

    $display("ISSUE1485 PASS");
    $finish;
  end
endmodule

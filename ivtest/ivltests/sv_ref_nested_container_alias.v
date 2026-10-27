module sv_ref_nested_container_alias;
  class nested_holder;
    int queues[$][$];
  endclass

  class holder;
    int values[$];
    nested_holder nested;
  endclass

  holder h;
  int errors = 0;

  task automatic update(ref int value);
    value = 21;
    if (value != 21) begin
      $display("FAIL ref write not visible in task"); errors++;
    end
  endtask

  task automatic delete_property_element(ref int value);
    h.values.delete();
    value = 31;
    if (h.values.size() != 0) begin
      $display("FAIL deleted property element was recreated"); errors++;
    end
  endtask

  task automatic replace_property_container(ref int value);
    h.values = '{42};
    value = 52;
    if (h.values.size() != 1 || h.values[0] != 42) begin
      $display("FAIL outdated property ref changed replacement"); errors++;
    end
  endtask

  task automatic delete_nested_element(ref int value);
    h.nested.queues[0].delete();
    value = 61;
    if (h.nested.queues[0].size() != 0) begin
      $display("FAIL nested outdated ref recreated removed element"); errors++;
    end
  endtask

  initial begin
    h = new;
    h.nested = new;

    h.values.push_back(1);
    update(h.values[0]);
    if (h.values[0] != 21) begin
      $display("FAIL class property element write was not immediate"); errors++;
    end

    delete_property_element(h.values[0]);
    if (h.values.size() != 0) begin
      $display("FAIL deleted class property element remained live"); errors++;
    end

    h.values.push_back(41);
    replace_property_container(h.values[0]);
    if (h.values.size() != 1 || h.values[0] != 42) begin
      $display("FAIL property container replacement boundary"); errors++;
    end

    h.nested.queues.push_back('{7});
    delete_nested_element(h.nested.queues[0][0]);
    if (h.nested.queues[0].size() != 0) begin
      $display("FAIL nested queue element deletion boundary"); errors++;
    end

    if (errors != 0) $fatal(1, "ref alias errors=%0d", errors);
    $display("PASS");
  end
endmodule

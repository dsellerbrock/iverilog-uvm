module sv_invalid_container_element_default;
  int dynamic_holder[0:0][];
  int dynamic_missing[];
  int queue_holder[0:0][$];
  int queue_missing[$];
  int index;

  initial begin
    index = 9;
    dynamic_missing = dynamic_holder[index];
    if (dynamic_missing.size() != 0)
      $fatal(1, "dynamic missing size=%0d", dynamic_missing.size());
    queue_missing = queue_holder[index];
    if (queue_missing.size() != 0)
      $fatal(1, "queue missing size=%0d", queue_missing.size());

    index = 0;
    dynamic_missing = dynamic_holder[index];
    if (dynamic_missing.size() != 0)
      $fatal(1, "dynamic present default size=%0d", dynamic_missing.size());
    queue_missing = queue_holder[index];
    if (queue_missing.size() != 0)
      $fatal(1, "queue present default size=%0d", queue_missing.size());

    $display("PASS invalid_container_element_default");
  end
endmodule

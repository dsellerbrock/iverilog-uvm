module issue3626_size_controls;
  parameter string words[2] = {"a", "b"};
  parameter string text = "abc";
  parameter int inferred[] = {4, 8, 16};
  parameter string names[] = {"one", "two"};
  int dynamic_values[];
  int queue_values[$];
  initial begin
    dynamic_values = new[3];
    queue_values.push_back(1);
    queue_values.push_back(2);
    if ($size(words) != 2 || text.len() != 3 ||
        dynamic_values.size() != 3 || queue_values.size() != 2 ||
        inferred.size() != 3 || inferred[1] != 8 ||
        names.size() != 2 || names[1] != "two")
      $fatal(1, "size controls failed");
    $display("PASSED");
  end
endmodule

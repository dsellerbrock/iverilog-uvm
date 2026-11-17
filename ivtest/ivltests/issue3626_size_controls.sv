module issue3626_size_controls;
  parameter string words[2] = {"a", "b"};
  parameter string text = "abc";
  int dynamic_values[];
  int queue_values[$];
  initial begin
    dynamic_values = new[3];
    queue_values.push_back(1);
    queue_values.push_back(2);
    if ($size(words) != 2 || text.len() != 3 ||
        dynamic_values.size() != 3 || queue_values.size() != 2)
      $fatal(1, "size controls failed");
    $display("PASSED");
  end
endmodule

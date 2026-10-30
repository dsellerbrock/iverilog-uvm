module issue1490_assoc_locators;
  int values[int];
  int found[$];
  int first[$];
  int last[$];

  initial begin
    values[-3] = 8;
    values[2] = 2;
    values[7] = 9;

    found = values.find(item) with (item > 3);
    if (found.size() != 2 || found[0] + found[1] != 17)
      $fatal(1, "find must return matching associative values");

    first = values.find_first(item) with (item > 3);
    if (first.size() != 1 || first[0] !== 8)
      $fatal(1, "find_first must return the first matching value");

    last = values.find_last(item) with (item > 3);
    if (last.size() != 1 || last[0] !== 9)
      $fatal(1, "find_last must return the last matching value");

    found = values.find(item) with (item > 100);
    if (found.size() != 0)
      $fatal(1, "find must return an empty queue when no value matches");

    $display("ISSUE1490_ASSOC_LOCATORS_PASS");
  end
endmodule

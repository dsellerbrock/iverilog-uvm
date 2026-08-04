// A duplicated expression-backed class property must retain its full nested
// container type. This is the shape used by OpenTitan dv_report_catcher:
// a two-dimensional string-keyed associative array iterated with two foreach
// indices from inside a class method.
class nested_assoc_collector;
  int values[string][string];

  function void add(string outer, string inner, int value);
    values[outer][inner] = value;
  endfunction

  function bit scan();
    int count;
    int sum;
    foreach (values[outer, inner]) begin
      count++;
      sum += values[outer][inner];
    end
    return count == 3 && sum == 41;
  endfunction
endclass

module sv_class_nested_assoc_foreach;
  nested_assoc_collector collector;

  initial begin
    collector = new;
    collector.add("alpha", "one", 11);
    collector.add("alpha", "two", 13);
    collector.add("beta", "three", 17);

    if (!collector.scan()) begin
      $display("FAILED");
      $finish(1);
    end
    $display("PASSED");
  end
endmodule

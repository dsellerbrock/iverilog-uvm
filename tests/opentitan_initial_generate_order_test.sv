module opentitan_initial_generate_order_test;
  logic [7:0] parent_before_value;
  logic [7:0] generate_before_value;
  int errors;

  initial begin : initialize_value
    parent_before_value = 8'h5a;
  end

  if (1) begin : parent_before_generated_check
    initial begin
      if (parent_before_value !== 8'h5a) begin
        $display("FAIL parent-before generated check value=%h",
                 parent_before_value);
        errors++;
      end
    end
  end

  if (1) begin : generate_before_parent_check
    initial begin
      if (generate_before_value === 8'ha5) begin
        $display("FAIL generate-before check ran after parent initializer");
        errors++;
      end
    end
  end

  initial begin : initialize_later_value
    generate_before_value = 8'ha5;
  end

  initial begin
    #1;
    if (errors == 0)
      $display("PASS opentitan initial/generate lexical ordering");
    else
      $display("FAIL opentitan initial/generate lexical ordering (%0d)", errors);
    $finish;
  end
endmodule

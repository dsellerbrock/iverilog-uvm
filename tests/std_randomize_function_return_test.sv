module std_randomize_function_return_test;
  function automatic bit [7:0] make_different(input bit [7:0] original);
    if (!std::randomize(make_different) with { make_different != original; }) begin
      $fatal(1, "std::randomize unexpectedly failed");
    end
  endfunction

  initial begin
    bit [7:0] value;
    repeat (16) begin
      value = $urandom;
      if (make_different(value) == value) begin
        $fatal(1, "function return value was not updated");
      end
    end
    $display("PASS std randomize function return");
  end
endmodule

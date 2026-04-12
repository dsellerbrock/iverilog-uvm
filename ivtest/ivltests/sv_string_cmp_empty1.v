module test;
  string s;

  initial begin
    s = "test_t";
    if (s != "") begin
      $display("NONEMPTY_NEQ_TRUE");
    end else begin
      $display("NONEMPTY_NEQ_FALSE");
      $finish_and_return(1);
    end

    if (s == "") begin
      $display("NONEMPTY_EQ_TRUE");
      $finish_and_return(1);
    end

    s = "";
    if (s != "") begin
      $display("EMPTY_NEQ_TRUE");
      $finish_and_return(1);
    end

    if (s == "") begin
      $display("PASS");
    end else begin
      $display("EMPTY_EQ_FALSE");
      $finish_and_return(1);
    end
  end
endmodule

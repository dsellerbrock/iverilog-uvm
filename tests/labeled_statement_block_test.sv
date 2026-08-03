module labeled_statement_block_test;
  bit completed;

  initial begin
    completed = 0;
    fork
      worker: begin
        #20 completed = 1;
      end
      begin
        #1 disable worker;
      end
    join
    if (completed) begin
      $display("FAIL: disable did not reach the statement-labeled block");
      $finish(1);
    end
    $display("PASS: statement-labeled begin/end preserves its disable scope");
    $finish;
  end
endmodule

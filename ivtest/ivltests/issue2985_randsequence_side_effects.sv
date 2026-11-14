module issue2985_randsequence_side_effects;
  int calls, count, code_calls, increments;
  function int next_value();
    calls++;
    return 1;
  endfunction
  initial begin
    randsequence (main)
      main : repeat (next_value()) item
             if (next_value()) item
             case (next_value())
               1: item;
               default: bad;
             endcase
             repeat (++increments) item
             code_item;
      item : { count++; };
      bad : { $fatal(1, "wrong case branch"); };
      code_item : { if (next_value()) code_calls++;
                    repeat (next_value()) code_calls++; };
    endsequence
    if (calls != 5 || count != 4 || code_calls != 2 || increments != 1)
      $fatal(1, "calls=%0d count=%0d code_calls=%0d increments=%0d",
             calls, count, code_calls, increments);
    $display("PASS");
  end
endmodule

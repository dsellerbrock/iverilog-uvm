// A property NBA issued by a program belongs in Re-NBA, after Re-Inactive.
// Waiting for the class property also pins mutation notification when the
// scheduled field update matures.
typedef struct packed {
  logic [3:0] hi;
  logic [3:0] lo;
} nba_reactive_pair_t;

class nba_reactive_holder;
  nba_reactive_pair_t pair;
endclass

program sv_nba_property_reactive;
  nba_reactive_holder obj;
  int errors;

  initial begin
    obj = new;
    obj.pair = 8'ha5;
    obj.pair.hi <= 4'h3;
    obj.pair.lo <= 4'h4;
    #0;
    if (obj.pair !== 8'ha5) begin
      $display("F1 re-inactive=%h", obj.pair);
      errors++;
    end
    fork
      begin
        wait (obj.pair === 8'h34);
      end
      begin
        #1;
        $display("F2 timeout pair=%h", obj.pair);
        errors++;
      end
    join_any
    disable fork;
    if (obj.pair !== 8'h34) begin
      $display("F3 re-nba=%h", obj.pair);
      errors++;
    end
    if (errors == 0)
      $display("PASSED");
    else
      $display("FAILED %0d", errors);
    $finish;
  end
endprogram

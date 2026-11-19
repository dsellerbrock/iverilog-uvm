module top;
  logic [1:0] x, y, wildcard_value;
  logic [7:0] item;
  real offset;
  int branch;

  task exact_case;
    case (x)
      item: branch = 1;
      default: branch = 0;
    endcase
  endtask

  task pruned_case;
    case (x)
      8'd3: branch = 1;
      default: branch = 0;
    endcase
  endtask

  task z_case;
    casez (wildcard_value)
      2'b01: branch = 1;
      default: branch = 0;
    endcase
  endtask

  task x_case;
    casex (wildcard_value)
      2'b01: branch = 1;
      default: branch = 0;
    endcase
  endtask

  task real_comparison;
    case (x)
      3.0: branch = 1;
      default: branch = 0;
    endcase
  endtask

  task real_operation;
    case (x + offset)
      3.5: branch = 1;
      default: branch = 0;
    endcase
  endtask

  task operation_case;
    begin : nested
      priority case (x + y)
        8'd5: branch = 1;
        default: branch = 0;
      endcase
    end
  endtask

  task explicit_true;
    case (1'b1)
      1'b1: branch = 1;
      default: branch = 0;
    endcase
  endtask

  task cast_selector;
    case (1'(x))
      1'b1: branch = 1;
      default: branch = 0;
    endcase
  endtask

  task lowered_cases;
    priority if (x == y) branch = 1;
    else branch = 0;
    case (type(x))
      type(y): branch = 1;
      default: branch = 0;
    endcase
    case (x) inside
      [2'd1:2'd3]: branch = 1;
      default: branch = 0;
    endcase
    case (x) inside
      default: branch = 0;
    endcase
    unique case (x) matches
      2'd3: branch = 1;
      default: branch = 0;
    endcase
  endtask

  task exercise(input int expected);
    exact_case();
    if (branch != expected) $fatal(1, "wrong case branch");
    pruned_case();
    if (branch != expected) $fatal(1, "wrong pruned case branch");
    z_case();
    if (branch != expected) $fatal(1, "wrong casez branch");
    x_case();
    if (branch != expected) $fatal(1, "wrong casex branch");
    real_comparison();
    if (branch != expected) $fatal(1, "wrong real comparison branch");
    real_operation();
    if (branch != expected) $fatal(1, "wrong real operation branch");
    operation_case();
    if (branch != expected) $fatal(1, "wrong operation case branch");
    $issue3874_read(expected);
  endtask

  initial begin
    item = 8'd3;
    x = 2'd3;
    y = 2'd2;
    offset = 0.5;
    wildcard_value = 2'bz1;
    exercise(1);
    cast_selector();
    if (branch != 1) $fatal(1, "wrong cast selector branch");
    wildcard_value = 2'bx1;
    x_case();
    if (branch != 1) $fatal(1, "casex did not ignore X");
    $issue3874_read(2);
    #1;
    x = 2'd1;
    wildcard_value = 2'bz0;
    exercise(0);
    $issue3874_finish;
  end
endmodule

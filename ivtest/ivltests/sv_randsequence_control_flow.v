// IEEE 1800-2017 18.17: structured production control, invocation reuse,
// input actual substitution, rand-join ordering, and the two independent
// randsequence flow domains.
module sv_randsequence_control_flow;
  int errors = 0;

  function automatic int production_controls();
    int value = 0;
    randsequence (main)
      main     : choose cased repeated returned add(.y(4));
      choose   : if (1) add(1) else add(100);
      cased    : case (2)
                   1: add(100);
                   2: add(3);
                   default: add(100);
                 endcase;
      repeated : repeat (2) add(2);
      returned : early add(8);
      early    : { return; value += 1000; };
      void add(input int y) : { value += y; };
    endsequence
    return value;
  endfunction

  function automatic int whole_sequence_break();
    int value = 0;
    randsequence (main)
      main : cut after;
      cut  : {
        repeat (4) begin
          value++;
          if (value == 2) break;
        end
        value += 10;
        if (value == 12) break;
        value += 100;
      };
      after : { value += 1000; };
    endsequence
    return value;
  endfunction

  function automatic int joined_order();
    int order = 0;
    randsequence (main)
      main  : rand join (0.0) left right;
      left  : { order = order * 10 + 1; }
              { order = order * 10 + 2; };
      right : { order = order * 10 + 3; }
              { order = order * 10 + 4; };
    endsequence
    return order;
  endfunction

  function automatic int nested_sequences();
    int value = 0;
    randsequence (outer)
      outer : nested after_outer;
      nested : {
        randsequence (inner)
          inner : cut after_inner;
          cut : { value += 1; break; };
          after_inner : { value += 100; };
        endsequence
        value += 2;
      };
      after_outer : { value += 4; };
    endsequence
    return value;
  endfunction

  initial begin
    int controls;
    int stopped;
    int joined;
    int nested;
    controls = production_controls();
    stopped = whole_sequence_break();
    joined = joined_order();
    nested = nested_sequences();

    if (controls != 20) begin
      $display("FAILED controls=%0d expected=20", controls);
      errors++;
    end
    if (stopped != 12) begin
      $display("FAILED stopped=%0d expected=12", stopped);
      errors++;
    end
    if (!(joined inside {1234, 1324, 1342, 3124, 3142, 3412})) begin
      $display("FAILED joined=%0d", joined);
      errors++;
    end
    if (nested != 7) begin
      $display("FAILED nested=%0d expected=7", nested);
      errors++;
    end

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
  end
endmodule

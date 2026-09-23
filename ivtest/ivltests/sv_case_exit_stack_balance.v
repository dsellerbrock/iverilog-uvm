// Leaving a case body through break/continue/return/disable must not
// leave the case selector on the VVP evaluation stack (IEEE 1800 12.5 and
// jump statements). A repeat loop keeps its count on that stack, so a leaked zero
// selector used to end the loop early.
module sv_case_exit_stack_balance;
  integer fails = 0;
  integer n, k, i, hits;
  real r;
  reg [1:0] sel;

  task automatic check(input integer got, input integer exp, input string what);
    if (got !== exp) begin
      $display("FAILED %s: got %0d, expected %0d", what, got, exp);
      fails = fails + 1;
    end
  endtask

  function automatic integer classify(input [1:0] v);
    case (v)
      2'd0: return 10;
      2'd1: begin
        if (v == 2'd1) return 11;
        return 98;
      end
      default: return 12;
    endcase
    return 99;
  endfunction

  task automatic tsk(input [1:0] v, output integer o);
    o = 0;
    case (v)
      2'd2: begin o = 2; return; end
      default: o = 7;
    endcase
    o = o + 100;
  endtask

  initial begin
    // Matched item + continue inside repeat.
    k = 0; hits = 0;
    repeat (3) begin
      hits = hits + 1;
      case (k)
        0: begin k = 1; continue; end
        default: k = k + 1;
      endcase
    end
    check(hits, 3, "repeat/item continue hits");
    check(k, 3, "repeat/item continue k");

    // Default item + continue inside repeat; code after the case is skipped.
    k = 0; hits = 0;
    repeat (3) begin
      hits = hits + 1;
      case (k)
        5: k = 50;
        default: begin k = k + 1; continue; end
      endcase
      k = 200;
    end
    check(hits, 3, "repeat/default continue hits");
    check(k, 3, "repeat/default continue k");

    // No item matches and there is no default.
    hits = 0;
    repeat (2) begin
      case (hits)
        7: hits = 70;
      endcase
      hits = hits + 1;
    end
    check(hits, 2, "repeat/no-match");

    // Nested case, continue from the inner case.
    k = 0; hits = 0; sel = 2'd0;
    repeat (2) begin
      hits = hits + 1;
      case (sel)
        2'd0: case (k)
                0: begin k = 5; continue; end
                default: k = k + 1;
              endcase
        default: k = 99;
      endcase
    end
    check(hits, 2, "repeat/nested continue hits");
    check(k, 6, "repeat/nested continue k");

    // while + break (pwrmgr csr_spinwait shape).
    i = 0; n = 0;
    while (1) begin
      n = n + 1;
      case (i)
        0, 1: i = i + 1;
        2: break;
      endcase
      n = n + 10;
    end
    check(n, 23, "while/break n");
    check(i, 2, "while/break i");

    // forever + break from a nested inner default.
    n = 0; sel = 2'd0;
    forever begin
      case (sel)
        2'd0: sel = 2'd1;
        2'd1: case (n)
                0: n = 1;
                default: begin n = n + 10; break; end
              endcase
      endcase
    end
    check(n, 11, "forever/nested break n");
    check(sel, 1, "forever/nested break sel");

    // priority case + continue.
    k = 0; hits = 0;
    repeat (2) begin
      hits = hits + 1;
      priority case (k)
        0: begin k = 1; continue; end
        1: k = 2;
      endcase
    end
    check(hits, 2, "priority continue hits");
    check(k, 2, "priority continue k");

    // priority case with no match still warns.
    sel = 2'd3; n = 0;
    priority case (sel)
      2'd0: n = 1;
      2'd1: n = 2;
    endcase
    check(n, 0, "priority no-match");

    // unique case + continue.
    k = 0; hits = 0;
    repeat (2) begin
      hits = hits + 1;
      unique case (k)
        0: begin k = 1; continue; end
        1: k = 2;
      endcase
    end
    check(hits, 2, "unique continue hits");
    check(k, 2, "unique continue k");

    // unique0 default + continue.
    k = 0; hits = 0;
    repeat (2) begin
      hits = hits + 1;
      unique0 case (k)
        4: k = 40;
        default: begin k = k + 1; continue; end
      endcase
    end
    check(hits, 2, "unique0 default continue hits");
    check(k, 2, "unique0 default continue k");

    // unique casez multiple match: warns once, first item runs and breaks.
    n = 0; i = 0; sel = 2'b10;
    while (i < 5) begin
      i = i + 1;
      unique casez (sel)
        2'b1?: begin n = 1; break; end
        2'b?0: n = 2;
      endcase
    end
    check(n, 1, "unique multi-match break n");
    check(i, 1, "unique multi-match break i");

    // unique if (lowered as a quality case) + break.
    i = 0; n = 0;
    while (1) begin
      i = i + 1;
      unique if (i == 3) break;
      else if (i > 10) n = 100;
      else n = i;
    end
    check(i, 3, "unique if break i");
    check(n, 2, "unique if break n");

    // Real selector: matched item + break, default + continue.
    r = 2.5; n = 0;
    for (i = 0; i < 10; i = i + 1) begin
      case (r)
        1.5: n = n + 100;
        2.5: begin n = n + 1; if (i == 2) break; end
        default: n = n + 1000;
      endcase
    end
    check(n, 3, "real break n");
    check(i, 2, "real break i");
    r = 0.0; n = 0;
    for (i = 0; i < 3; i = i + 1) begin
      case (r)
        1.0: n = n + 100;
        default: begin n = n + 1; continue; end
      endcase
      n = n + 1000;
    end
    check(n, 3, "real default continue");

    // return from a case in a function and a task.
    check(classify(2'd0), 10, "function return item 0");
    check(classify(2'd1), 11, "function return nested");
    check(classify(2'd3), 12, "function return default");
    tsk(2'd2, n);
    check(n, 2, "task return");
    tsk(2'd0, n);
    check(n, 107, "task no return");

    // disable of an enclosing named block from a case item.
    n = 0;
    begin : blk
      for (i = 0; i < 5; i = i + 1)
        case (i)
          3: disable blk;
          default: n = n + 1;
        endcase
      n = 999;
    end
    check(n, 3, "disable n");
    check(i, 3, "disable i");

    if (fails == 0) $display("PASSED");
  end
endmodule

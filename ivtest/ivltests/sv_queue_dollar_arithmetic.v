// IEEE 1800-2017 7.10.1: within a queue index expression, `$' stands
// for the queue's top bound (size()-1) and, per 11.5.1's general
// index-expression rule, may be combined with ordinary arithmetic --
// `q[$-1]' names the second-to-last element, `q[$-N]' for a variable
// N the (N+1)-th from the end. Only the bare `q[$]' form was
// supported; `q[$-N]' fell straight through to a syntax error.
//
// Reduced from OpenTitan gpio_scoreboard.sv:
//   } else if(data_in_update_queue[$ - 1].needs_update == 1'b1) begin
module main;
  int q[$];
  int i;
  int errors = 0;

  task check(string what, int got, int exp);
    if (got !== exp) begin
      $display("FAIL %s: got %0d expect %0d", what, got, exp);
      errors++;
    end
  endtask

  initial begin
    q.push_back(10);
    q.push_back(20);
    q.push_back(30);
    q.push_back(40);

    check("bare $", q[$], 40);
    check("$-1 literal offset", q[$-1], 30);
    check("$-2 literal offset", q[$-2], 20);

    i = 1;
    check("$-i variable offset", q[$-i], 30);
    i = 3;
    check("$-i reaches index 0", q[$-i], 10);

    // lvalue form
    q[$-1] = 99;
    check("q[$-1] as lvalue", q[2], 99);

    // combined with an arithmetic expression, not just a bare variable
    i = 1;
    q[$-(i+1)] = 77;
    check("q[$-(i+1)] as lvalue", q[1], 77);

    if (errors == 0) $display("PASSED");
    else $display("%0d checks failed", errors);
  end
endmodule

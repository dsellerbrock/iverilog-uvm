// IEEE 1800-2017 7.10.3 and 13.5.2: a ref to a queue/dynamic-array
// element follows that element through index shifts. If the element is
// removed, it remains alive for the subroutine and becomes an outdated,
// private element value. Multiple refs to the same element remain aliases.
class item_c;
  int id;
  function new(int value);
    id = value;
  endfunction
endclass

module top;
  int q[$];
  int bounded[$:2];
  int da[];
  real rq[$];
  string sq[$];
  item_c oq[$];
  item_c obj;
  int fails = 0;
  bit live_write_event;

  task automatic removed_int(ref int value, input int expected,
                             input int replacement);
    #2;
    if (value != expected) begin
      fails++;
      $display("FAIL removed int read=%0d expected=%0d", value, expected);
    end
    value = replacement;
    #1;
    if (value != replacement) begin
      fails++;
      $display("FAIL removed int private write=%0d expected=%0d",
               value, replacement);
    end
  endtask

  task automatic live_int(ref int value, input int expected,
                          input int replacement);
    #2;
    if (value != expected) begin
      fails++;
      $display("FAIL shifted int read=%0d expected=%0d", value, expected);
    end
    value = replacement;
  endtask

  int alias_ready;
  event alias_go;

  task automatic alias_writer(ref int value);
    alias_ready++;
    @alias_go;
    value = 77;
  endtask

  task automatic alias_reader(ref int value);
    alias_ready++;
    @alias_go;
    #0;
    if (value != 77) begin
      fails++;
      $display("FAIL detached refs lost alias: value=%0d", value);
    end
  endtask

  task automatic removed_real(ref real value);
    #2;
    if (value != 2.5) begin fails++; $display("FAIL real read=%f", value); end
    value = 7.5;
    if (value != 7.5) begin fails++; $display("FAIL real write=%f", value); end
  endtask

  task automatic replaced_string(ref string value);
    #2;
    if (value != "old") begin fails++; $display("FAIL string read=%s", value); end
    value = "private";
    if (value != "private") begin fails++; $display("FAIL string write=%s", value); end
  endtask

  task automatic removed_object(ref item_c value);
    #2;
    if (value == null || value.id != 31) begin
      fails++;
      $display("FAIL object read");
    end
    value = new(99);
    if (value == null || value.id != 99) begin
      fails++;
      $display("FAIL object write");
    end
  endtask

  initial begin
    // Removed queue element: the ref keeps the removed value privately.
    q = {10, 20, 30};
    fork removed_int(q[1], 20, 25); join_none
    #1 q.delete(1);
    #3;
    if (q.size() != 2 || q[0] != 10 || q[1] != 30) begin
      fails++;
      $display("FAIL removed write escaped to queue q=%p", q);
    end

    // Unremoved element follows push_front and is still live storage.
    q = {40, 50, 60};
    fork live_int(q[1], 50, 55); join_none
    #1 q.push_front(35);
    live_write_event = 0;
    fork begin
      wait (q[2] == 55);
      live_write_event = 1;
    end join_none
    #3;
    if (q[2] != 55) begin fails++; $display("FAIL shifted target q=%p", q); end
    if (!live_write_event) begin
      fails++;
      $display("FAIL ref element write did not notify queue observers");
    end

    // Two references to one removed element retain shared identity.
    q = {1, 2, 3};
    alias_ready = 0;
    fork
      alias_writer(q[1]);
      alias_reader(q[1]);
    join_none
    wait (alias_ready == 2);
    q.delete(1);
    -> alias_go;
    #1;

    // Ordering methods move the element rather than retargeting its ref.
    q = {9, 7, 8};
    fork live_int(q[0], 9, 90); join_none
    #1 q.sort();
    #3;
    if (q.size() != 3 || q[2] != 90) begin
      fails++;
      $display("FAIL sort identity q=%p", q);
    end

    // Bounded push_front removes the tail and outdates its reference.
    bounded = {1, 2, 3};
    fork removed_int(bounded[2], 3, 33); join_none
    #1 bounded.push_front(0);
    #3;
    if (bounded.size() != 3 || bounded[0] != 0 || bounded[2] != 2) begin
      fails++;
      $display("FAIL bounded queue=%p", bounded);
    end

    // Dynamic-array deletion has the same removed-element lifetime rule.
    da = new[2];
    da[0] = 70;
    da[1] = 80;
    fork removed_int(da[1], 80, 85); join_none
    #1 da.delete();
    #3;
    if (da.size() != 0) begin fails++; $display("FAIL dynamic delete size=%0d", da.size()); end

    // Typed queues use the same lifetime mechanism.
    rq = {1.5, 2.5};
    fork removed_real(rq[1]); join_none
    #1 void'(rq.pop_back());
    #3;

    sq = {"old"};
    fork replaced_string(sq[0]); join_none
    #1 sq = {"new"};
    #3;
    if (sq.size() != 1 || sq[0] != "new") begin
      fails++;
      $display("FAIL whole replacement sq=%p", sq);
    end

    obj = new(31);
    oq.push_back(obj);
    fork removed_object(oq[0]); join_none
    #1 void'(oq.pop_front());
    #3;
    if (oq.size() != 0) begin fails++; $display("FAIL object queue size=%0d", oq.size()); end

    if (fails == 0) $display("PASSED");
    else $fatal(1, "FAIL count=%0d", fails);
  end
endmodule

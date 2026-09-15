class receiver;
  int count = 0;
  int values[$];
  rand bit value;
  constraint only_zero { value == 0; }
  task write(input int delta); count += delta; endtask
  task get_fields; count += 2; endtask
  task mirror; count += 4; endtask
  task reset; count = 0; endtask
  task clear_successors; count += 8; endtask
endclass
class holder; receiver item; endclass
module test;
  receiver m, items[1];
  holder h;
  int mode_calls;
  function int mode; mode_calls++; return 0; endfunction
  initial begin
    m = new; items[0] = m; h = new; h.item = m;
    m.write(1); items[0].get_fields(); h.item.mirror();
    if (m.count !== 7) $fatal(1, "receiver effects %0d", m.count);
    h.item.reset(); items[0].clear_successors(); m.write(16);
    if (m.count !== 24) $fatal(1, "named methods %0d", m.count);
    m.only_zero.constraint_mode(mode());
    if (mode_calls !== 1 || m.only_zero.constraint_mode() !== 0)
      $fatal(1, "constraint disable/calls %0d", mode_calls);
    m.only_zero.constraint_mode(1);
    if (m.only_zero.constraint_mode() !== 1) $fatal(1, "constraint enable");
    h.item.values.push_back(2); items[0].values.push_front(1);
    h.item.values.insert(1, 7);
    if (m.values.size() !== 3 || m.values[0] !== 1
        || m.values[1] !== 7 || m.values[2] !== 2)
      $fatal(1, "nested queue methods");
    h.item.values.delete();
    if (m.values.size() !== 0) $fatal(1, "nested queue delete");
    m.pre_randomize(); m.post_randomize();
    $display("PASSED");
  end
endmodule

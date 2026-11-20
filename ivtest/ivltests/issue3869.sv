module issue3869;
  typedef bit signed [7:0] byte_equiv;
  class payload;
    byte_equiv data[];
    byte bounded[$:1];
  endclass
  class receiver;
    payload item;
  endclass

  byte dyn[], empty_dyn[];
  byte q[$], empty_q[$];
  byte bounded[$:2];
  receiver objects[2];
  int index_calls, format_calls;

  function automatic int receiver_index();
    return index_calls++;
  endfunction

  function automatic byte format_value();
    format_calls++;
    return 8'hff;
  endfunction

  task automatic exercise_auto;
    byte data[];
    byte queue_data[$];
    string scope_name;
    $swrite(data, "X");
    $sformat(queue_data, "%cY", data[0]);
    if (data.size() != 1 || data[0] !== 8'h58 ||
        queue_data.size() != 2 || queue_data[0] !== 8'h58 ||
        queue_data[1] !== 8'h59)
      $fatal(1, "automatic destinations");
    scope_name = $sformatf("%m");
    $sformat(data, "%m");
    if (data.size() != scope_name.len())
      $fatal(1, "formatter scope length");
    foreach (data[i])
      if (data[i] !== scope_name[i])
        $fatal(1, "formatter scope byte %0d", i);
  endtask

  initial begin
    $swrite(dyn, "abc");
    if (dyn.size() != 3 || dyn[0] !== 8'h61 || dyn[1] !== 8'h62 ||
        dyn[2] !== 8'h63)
      $fatal(1, "swrite into dynamic array");
    $swrite(dyn, "x");
    if (dyn.size() != 1 || dyn[0] !== 8'h78)
      $fatal(1, "shrink a populated dynamic array");
    $sformat(dyn, "A%cB", 0);
    if (dyn.size() != 3 || dyn[0] !== 8'h41 || dyn[1] !== 8'h00 ||
        dyn[2] !== 8'h42)
      $fatal(1, "grow a populated dynamic array with an embedded NUL");

    $sformat(q, "%s", "%c");
    if (q.size() != 2 || q[0] !== 8'h25 || q[1] !== 8'h63)
      $fatal(1, "sformat into queue with a single format argument");
    $sformat(q, "z");
    if (q.size() != 1 || q[0] !== 8'h7a)
      $fatal(1, "shrink a populated queue");
    $swrite(q, "A%0d", 3, "B%c", 0);
    if (q.size() != 4 || q[0] !== 8'h41 || q[1] !== 8'h33 ||
        q[2] !== 8'h42 || q[3] !== 8'h00)
      $fatal(1, "grow a populated queue with multiple format items");

    $swrite(q, 4'd10);
    if (q.size() != 2 || q[0] !== 8'h31 || q[1] !== 8'h30)
      $fatal(1, "decimal radix");
    $swriteb(q, 4'd10);
    if (q.size() != 4 || q[0] !== 8'h31 || q[1] !== 8'h30 ||
        q[2] !== 8'h31 || q[3] !== 8'h30)
      $fatal(1, "binary radix");
    $swriteh(q, 4'd10);
    if (q.size() != 1 || q[0] !== 8'h61)
      $fatal(1, "hexadecimal radix");
    $swriteo(q, 4'd10);
    if (q.size() != 2 || q[0] !== 8'h31 || q[1] !== 8'h32)
      $fatal(1, "octal radix");

    $swrite(dyn);
    $sformat(q, "");
    empty_dyn = "";
    empty_q = "";
    if (dyn.size() != 1 || empty_dyn.size() != 1 ||
        dyn[0] !== 8'h00 || dyn[0] !== empty_dyn[0] ||
        q.size() != 1 || empty_q.size() != 1 ||
        q[0] !== 8'h00 || q[0] !== empty_q[0])
      $fatal(1, "empty formatter results match the empty literal");

    exercise_auto();
    objects[0] = new;
    objects[1] = new;
    objects[0].item = new;
    objects[1].item = new;
    objects[1].item.data = "!";
    $sformat(objects[receiver_index()].item.data, "%c%c", format_value(), 0);
    if (index_calls != 1 || format_calls != 1 ||
        objects[0].item.data.size() != 2 ||
        objects[0].item.data[0] !== 8'hff || objects[0].item.data[1] !== 8'h00 ||
        objects[1].item.data.size() != 1 || objects[1].item.data[0] !== 8'h21)
      $fatal(1, "nested receiver and format argument must each evaluate once");

    $swrite(bounded, "abcd");
    if (bounded.size() != 3 || bounded[0] !== 8'h61 ||
        bounded[1] !== 8'h62 || bounded[2] !== 8'h63)
      $fatal(1, "bounded signal queue prefix");
    $sformat(objects[0].item.bounded, "wxyz!");
    if (objects[0].item.bounded.size() != 2 ||
        objects[0].item.bounded[0] !== 8'h77 || objects[0].item.bounded[1] !== 8'h78)
      $fatal(1, "bounded class queue prefix");

    $sformat(q, "Z", "%d");
    if (q.size() != 1 || q[0] !== 8'h5a)
      $fatal(1, "extra format argument changed the result");
    $sformat(q, "Q%c");
    if (q.size() != 5 || q[0] !== 8'h51 || q[1] !== 8'h3c ||
        q[2] !== 8'h25 || q[3] !== 8'h63 || q[4] !== 8'h3e)
      $fatal(1, "missing format argument recovery");
    $display("PASSED");
  end
endmodule

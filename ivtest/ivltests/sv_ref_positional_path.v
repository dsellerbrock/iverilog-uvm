module sv_ref_positional_path;
  class item;
    int id;
    function new(int id);
      this.id = id;
    endfunction
  endclass

  class payload;
    int queues[$][$][$];
  endclass

  class holder;
    payload data;
  endclass

  int q[$][$];
  int da[][];
  item objects[$][$];
  holder h;
  int selects;

  function automatic int select_once(int step, int index);
    if (selects != step)
      $fatal(1, "selector evaluated out of order or more than once");
    selects++;
    return index;
  endfunction

  task automatic shift(ref int value);
    q[0].push_front(5);
    value = 72;
    if (q[0][0] !== 5 || q[0][1] !== 10 || q[0][2] !== 72)
      $fatal(1, "ref did not follow the shifted element");
  endtask

  task automatic observe(ref int value, const ref int observer);
    value = 81;
    if (observer !== 81 || q[0][2] !== 81)
      $fatal(1, "const ref did not observe the live leaf");
  endtask

  task automatic remove_parent(ref int value);
    if (value !== 22 || selects != 2)
      $fatal(1, "wrong three-deep leaf or selector count");
    h.data.queues.delete(1);
    h.data.queues.insert(1, '{'{90}, '{91, 92}});
    if (value !== 22)
      $fatal(1, "parent removal lost the old leaf value");
    value = 23;
    if (value !== 23 || h.data.queues[1][1][1] !== 92)
      $fatal(1, "outdated ref wrote into the replacement parent");
  endtask

  task automatic resize(ref int value);
    da[0] = new[3](da[0]);
    if (da[0].size() !== 3)
      $fatal(1, "inner dynamic array did not resize");
    if (value !== 40)
      $fatal(1, "resize lost the old leaf value");
    value = 41;
    if (value !== 41 || da[0][1] !== 40)
      $fatal(1, "outdated ref wrote into the resized array");
  endtask

  task automatic set_object(ref item value, const ref item observed);
    item from_queue;
    value = new(84);
    from_queue = objects[0][0];
    if (observed == null || observed.id !== 84 || from_queue != observed)
      $fatal(1, "class handle ref write was not immediate");
  endtask

  task automatic invalid_index(ref int value);
    value = 123;
  endtask

  function automatic bit pop_tail();
    void'(q[0].pop_back());
    return 1'b1;
  endfunction

  task automatic check_computed_index(const ref int value, input int expected);
    if (selects != 1 || value !== expected)
      $fatal(1, "computed queue index did not use the live receiver once");
  endtask

  initial begin
    logic [95:0] wide_index;
    logic signed [1:0] negative_index;
    item original;

    q = '{'{10, 20}};
    shift(q[0][1]);
    selects = 0;
    observe(q[0][2], q[select_once(0, 0)][$]);
    if (selects != 1)
      $fatal(1, "queue last index reevaluated its receiver");

    h = new;
    h.data = new;
    h.data.queues = '{'{'{31}}, '{'{11}, '{21, 22}}, '{'{41}}};
    selects = 0;
    remove_parent(h.data.queues[select_once(0, 1)][$][select_once(1, 1)]);

    da = '{'{30, 40}};
    resize(da[0][1]);

    original = new(18);
    objects = '{'{original}};
    set_object(objects[0][0], objects[0][$]);

    // A selector with invalid bits above the machine word, an oversized
    // value or a negative value must not alias any existing cell.
    wide_index = 96'h1_0000_0000_0000_0000;
    invalid_index(q[wide_index][1]);
    invalid_index(q[0][wide_index]);
    wide_index = '0;
    wide_index[70] = 1'bz;
    invalid_index(q[wide_index][1]);
    invalid_index(q[0][wide_index]);
    negative_index = -2;
    invalid_index(q[0][negative_index]);
    if (q[0][0] !== 5 || q[0][1] !== 10 || q[0][2] !== 81)
      $fatal(1, "invalid selector wrote into a valid cell");

    selects = 0;
    check_computed_index(q[select_once(0, 0)][$-1], 10);
    selects = 0;
    check_computed_index(q[select_once(0, 0)][pop_tail() ? $ : 0], 10);

    $display("PASS");
  end
endmodule

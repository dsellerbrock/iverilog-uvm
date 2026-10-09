module sv_ref_static_task_2023;
  int scalar;
  int fixed_words[4:3];
  typedef struct { int field; } record_t;
  record_t record;

  class static_holder;
    static int value;
  endclass

  task automatic update(ref static int value);
    fork
      begin
        value = value + 5;
      end
    join_none
  endtask

  task automatic forward(ref static int value);
    update(value);
  endtask

  function automatic int update_function(ref static int value);
    value = value + 7;
    update_function = value;
  endfunction

  function automatic int update_array_function(ref static int value);
    value = value + 1;
    update_array_function = fixed_words[3];
  endfunction

  initial begin
    scalar = 1;
    update(scalar);
    wait fork;
    if (scalar !== 6) $fatal(1, "ref static task alias failed: %0d", scalar);

    fixed_words[3] = 10;
    update(fixed_words[3]);
    wait fork;
    if (fixed_words[3] !== 15)
      $fatal(1, "ref static array-element alias failed: %0d", fixed_words[3]);

    record.field = 40;
    update(record.field);
    wait fork;
    if (record.field !== 45)
      $fatal(1, "ref static struct-member alias failed: %0d", record.field);

    static_holder::value = 20;
    update(static_holder::value);
    wait fork;
    if (static_holder::value !== 25)
      $fatal(1, "ref static property alias failed: %0d", static_holder::value);

    forward(scalar);
    wait fork;
    if (scalar !== 11) $fatal(1, "ref static forwarding failed: %0d", scalar);

    if (update_function(scalar) !== 18 || scalar !== 18)
      $fatal(1, "ref static function alias failed: %0d", scalar);

    fixed_words[3] = 30;
    if (update_array_function(fixed_words[3]) !== 31 || fixed_words[3] !== 31)
      $fatal(1, "ref static function array alias failed: %0d", fixed_words[3]);

    $display("PASSED");
  end
endmodule

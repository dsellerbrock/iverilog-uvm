class sv_const_ref_forward_property;
  const int value = 13;
endclass

module sv_const_ref_forward;
  typedef struct packed {
    logic ready;
    logic [2:0] code;
  } status_t;
  typedef struct {
    int value;
  } unpacked_t;

  int observed;
  sv_const_ref_forward_property item;

  task automatic read_later(const ref int value);
    #2;
    observed = value;
  endtask

  task automatic forward_scalar(const ref int value);
    read_later(value);
  endtask

  task automatic read_status(const ref status_t status);
    if (!status.ready || status.code != 3'd5)
      $fatal(1, "packed struct forwarding failed");
  endtask

  task automatic forward_status(const ref status_t status);
    read_status(status);
  endtask

  task automatic read_element(const ref int value);
    if (value != 17)
      $fatal(1, "dynamic array element forwarding failed: %0d", value);
  endtask

  task automatic read_property(const ref int value);
    if (value != 13)
      $fatal(1, "const class property task binding failed: %0d", value);
  endtask

  task automatic forward_array(const ref int values[]);
    read_element(values[0]);
  endtask

  task automatic forward_unpacked(const ref unpacked_t item);
    read_element(item.value);
  endtask

  function automatic int add_one(const ref int value);
    return value + 1;
  endfunction

  function automatic int forward_function(const ref int value);
    return add_one(value);
  endfunction

  function automatic int packed_equivalent(const ref logic [3:0] value);
    return value;
  endfunction

  initial begin
    int value;
    int values[];
    status_t status;
    unpacked_t unpacked;
    value = 2;
    status = {1'b1, 3'd5};
    values = new[1];
    values[0] = 17;
    unpacked.value = 17;
    item = new;
    fork
      forward_scalar(value);
      begin
        #1;
        value = 9;
      end
    join
    if (observed != 9)
      $fatal(1, "const ref did not observe caller update: %0d", observed);
    forward_status(status);
    forward_array(values);
    forward_unpacked(unpacked);
    read_property(item.value);
    if (forward_function(item.value) != 14)
      $fatal(1, "const class property forwarding failed");
    if (packed_equivalent(status) != 4'b1101)
      $fatal(1, "equivalent packed ref type failed");
    if (forward_function(value) != 10 || value != 9)
      $fatal(1, "nonvoid function forwarding failed");
    $display("PASSED");
  end
endmodule

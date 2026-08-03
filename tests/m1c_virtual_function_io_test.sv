// Virtual functions and tasks must preserve input and output arguments through
// wrapper calls. This is the data path used by UVM analysis ports and FIFOs.

typedef enum bit {AddrChannel, DataChannel} dir_e;

class item;
  int tag;
  function new(int value = 0);
    tag = value;
  endfunction
endclass

class io_base;
  virtual function void write(input item value);
  endfunction
  virtual function bit try_get(output item value);
    return 0;
  endfunction
endclass

class io_impl extends io_base;
  item saved;
  virtual function void write(input item value);
    saved = value;
  endfunction
  virtual function bit try_get(output item value);
    value = saved;
    return value != null;
  endfunction
endclass

class io_port;
  io_base m_if;
  function void write(input item value);
    m_if.write(value);
  endfunction
  function bit try_get(output item value);
    return m_if.try_get(value);
  endfunction
endclass

class dir_base;
  virtual task get(output dir_e value);
  endtask
endclass

class dir_impl extends dir_base;
  virtual task get(output dir_e value);
    value = DataChannel;
  endtask
endclass

class dir_port;
  dir_base m_if;
  task get(output dir_e value);
    m_if.get(value);
  endtask
endclass

class param_io_base #(type T1 = int, type T2 = int);
  virtual function void write(input T1 value);
  endfunction
  virtual function bit try_get(output T2 value);
    return 0;
  endfunction
endclass

class param_store #(type T = int) extends param_io_base #(T, T);
  mailbox #(T) values;
  function new;
    values = new(0);
  endfunction
  virtual function void write(input T value);
    void'(values.try_put(value));
  endfunction
  virtual function bit try_get(output T value);
    return values.try_get(value);
  endfunction
endclass

class param_imp #(type T = int, type IMP = int)
  extends param_io_base #(T, T);
  IMP m_imp;
  virtual function void write(input T value);
    m_imp.write(value);
  endfunction
endclass

class param_port #(type T = int);
  param_io_base #(T, T) m_if;
  function void write(input T value);
    m_if.write(value);
  endfunction
endclass

module m1c_virtual_function_io_test;
  mailbox #(item)  item_mailbox;
  mailbox #(dir_e) dir_mailbox;

  initial begin
    item sent = new(42);
    item got;
    io_impl impl = new;
    io_port port_h = new;
    dir_impl dimpl = new;
    dir_port dport = new;
    dir_e direction = AddrChannel;
    bit ok;
    param_store #(item) pstore = new;
    param_imp #(item, param_store #(item)) pimp = new;
    param_port #(item) pport = new;

    item_mailbox = new(0);
    ok = item_mailbox.try_put(sent);
    got = null;
    ok &= item_mailbox.try_get(got);
    if (!ok || got == null || got.tag != 42) begin
      $error("typed mailbox object propagation failed");
      $finish_and_return(1);
    end

    dir_mailbox = new(0);
    ok = dir_mailbox.try_put(DataChannel);
    direction = AddrChannel;
    ok &= dir_mailbox.try_get(direction);
    if (!ok || direction != DataChannel) begin
      $error("typed mailbox enum propagation failed: got=%0d", direction);
      $finish_and_return(1);
    end

    pimp.m_imp = pstore;
    pport.m_if = pimp;
    pport.write(sent);
    got = null;
    if (!pstore.try_get(got) || got == null || got.tag != 42) begin
      $error("parameterized virtual forwarding lost object argument");
      $finish_and_return(1);
    end

    port_h.m_if = impl;
    port_h.write(sent);
    if (!port_h.try_get(got) || got == null || got.tag != 42) begin
      $error("virtual function input/output propagation failed");
      $finish_and_return(1);
    end

    dport.m_if = dimpl;
    dport.get(direction);
    if (direction != DataChannel) begin
      $error("virtual task enum output propagation failed: got=%0d", direction);
      $finish_and_return(1);
    end

    $display("PASSED: virtual function/task argument propagation");
    $finish;
  end
endmodule

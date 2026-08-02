typedef enum bit {AddrChannel, DataChannel} channel_e;

class tagged_item;
  int tag;
  function new(int value = 0);
    tag = value;
  endfunction
endclass

class fifo_base #(type T = int);
  virtual function bit try_get(output T value);
    return 0;
  endfunction
endclass

class test_fifo #(type T = int) extends fifo_base #(T);
  mailbox #(T) values;
  function new;
    values = new(0);
  endfunction
  function void write(T value);
    void'(values.try_put(value));
  endfunction
  virtual function bit try_get(output T value);
    return values.try_get(value);
  endfunction
endclass

class detached_consumer;
  int errors;
  event done;

  task consume_item(tagged_item value);
    if (value == null || value.tag != 42) begin
      errors++;
      $error("detached child lost object argument");
    end
  endtask

  task consume_direction(channel_e value);
    if (value != DataChannel) begin
      errors++;
      $error("detached child lost enum argument: got=%0d", value);
    end
  endtask

  task start(fifo_base #(tagged_item) item_fifo,
             fifo_base #(channel_e) direction_fifo);
    tagged_item value;
    channel_e direction;
    fork
      begin
        if (!item_fifo.try_get(value))
          errors++;
        consume_item(value);
        if (!direction_fifo.try_get(direction))
          errors++;
        consume_direction(direction);
        ->done;
      end
    join_none
  endtask
endclass

module b9_detached_fork_method_args_test;
  test_fifo #(tagged_item) item_fifo;
  test_fifo #(channel_e) direction_fifo;
  detached_consumer consumer;
  tagged_item sent;

  initial begin
    item_fifo = new;
    direction_fifo = new;
    consumer = new;
    sent = new(42);
    item_fifo.write(sent);
    direction_fifo.write(DataChannel);
    consumer.start(item_fifo, direction_fifo);
    @consumer.done;
    if (consumer.errors != 0)
      $finish_and_return(1);
    $display("PASSED: detached-fork method arguments and task formals");
    $finish;
  end
endmodule

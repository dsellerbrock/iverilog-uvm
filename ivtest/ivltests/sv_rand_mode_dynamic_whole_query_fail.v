class whole_container_query_item;
  rand int dynamic_values[];
  rand int queue_values[$];
  rand int associative_values[int];

  function new;
    dynamic_values = new[1];
    queue_values = '{1};
    associative_values[1] = 1;
  endfunction
endclass

module test;
  whole_container_query_item item = new;
  int mode;

  initial begin
    // IEEE 1800-2017 18.8 permits an unpacked array in the setter form,
    // but the query function accepts only a singular variable. Each query
    // therefore requires an element index.
    mode = item.dynamic_values.rand_mode();
    mode = item.queue_values.rand_mode();
    mode = item.associative_values.rand_mode();
  end
endmodule

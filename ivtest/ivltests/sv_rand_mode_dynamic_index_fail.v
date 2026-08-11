// IEEE 1800-2017 permits rand_mode control of an unpacked array member, and
// Slang accepts these dynamic, queue, and associative element spellings.
// Icarus does not yet carry stable per-element mode state for containers whose
// membership can change, so each form must fail loudly instead of controlling
// the entire property.
class dynamic_index_mode_item;
  rand int dynamic_values[];
  rand int queue_values[$];
  rand int associative_values[int];

  function new;
    dynamic_values = new[2];
    queue_values = '{1, 2};
    associative_values[3] = 4;
  endfunction
endclass

module test;
  dynamic_index_mode_item item = new;
  int mode;

  initial begin
    item.dynamic_values[0].rand_mode(0);
    mode = item.dynamic_values[0].rand_mode();
    item.queue_values[0].rand_mode(0);
    mode = item.queue_values[0].rand_mode();
    item.associative_values[3].rand_mode(0);
    mode = item.associative_values[3].rand_mode();
  end
endmodule

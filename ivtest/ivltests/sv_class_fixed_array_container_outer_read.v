// IEEE 1800-2017/2023 7.6, 21.2.1.7: reading the complete fixed outer property
// of queues. Each word is one queue object (not a packed vector element), and
// the aggregate prints as an assignment-pattern of queues. This was refused by
// the code generator ("cannot be read as one aggregate object").
class fixed_container_outer_read_holder;
  int values[2][$];
endclass

module sv_class_fixed_array_container_outer_read;
  initial begin
    automatic fixed_container_outer_read_holder holder = new;
    automatic string empty_text, filled_text;
    empty_text = $sformatf("%p", holder.values);
    holder.values[0].push_back(1);
    holder.values[1].push_back(2);
    holder.values[1].push_back(3);
    filled_text = $sformatf("%p", holder.values);
    if (empty_text == "'{'{}, '{}}" && filled_text == "'{'{1}, '{2, 3}}")
      $display("PASSED");
    else
      $display("FAILED empty=%s filled=%s", empty_text, filled_text);
  end
endmodule

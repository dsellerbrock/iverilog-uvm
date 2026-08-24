class fixed_container_invalid_delete_holder;
  int values[2][$];
endclass

module sv_class_fixed_array_container_invalid_delete;
  initial begin
    automatic fixed_container_invalid_delete_holder holder = new;
    automatic logic signed [31:0] unknown_index = 'x;
    automatic int negative_index = -1;

    holder.values[0] = '{1, 2};
    holder.values[0].delete(unknown_index);
    holder.values[0].delete(negative_index);
    holder.values[0].push_back(3);

    if (holder.values[0].size() != 3 ||
        holder.values[0][0] != 1 || holder.values[0][1] != 2 ||
        holder.values[0][2] != 3)
      $fatal(1, "invalid delete changed the queue or corrupted receiver state");
    $display("PASSED");
  end
endmodule

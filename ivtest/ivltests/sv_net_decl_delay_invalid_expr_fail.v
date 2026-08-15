class delay_holder;
  int value;
endclass

module top;
  delay_holder holder;
  wire #(holder.value) bad;
endmodule

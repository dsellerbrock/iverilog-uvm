// IEEE 1800-2017/2023 7.4.2 and 7.4.5: selecting a class handle from a
// queue must not change a following fixed unpacked-array member access.
typedef struct {
  int words[5:3];
} payload_t;

class holder_t;
  payload_t data;
endclass

module sv_selected_container_struct_fixed_member_read;
  holder_t holder;
  holder_t holders[$];

  initial begin
    holder = new;
    holder.data.words[5] = 50;
    holders.push_back(holder);

    if (holder.data.words[5] != 50)
      $fatal(1, "direct class-property control failed");
    if (holders[0].data.words[5] != 50)
      $fatal(1, "selected receiver read returned %0d",
             holders[0].data.words[5]);

    $display("PASSED");
  end
endmodule

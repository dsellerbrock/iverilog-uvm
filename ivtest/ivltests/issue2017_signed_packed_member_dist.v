module issue2017_signed_packed_member_dist;
  typedef struct packed { bit signed [3:0] s; bit [3:0] u; } sp_t;
  class packed_member_c;
    rand sp_t p;
    constraint weighted { p.s dist {[-4:-1] :/ 90, [0:3] :/ 10}; }
  endclass
  class plain_member_c;
    rand bit signed [3:0] s;
    constraint weighted { s dist {[-4:-1] :/ 90, [0:3] :/ 10}; }
  endclass
  initial begin
    packed_member_c packed_item;
    plain_member_c plain_item;
    int packed_negative;
    int plain_negative;
    packed_item = new;
    plain_item = new;
    packed_negative = 0;
    plain_negative = 0;
    repeat (100) begin
      if (!packed_item.randomize() || !plain_item.randomize())
        $fatal(1, "randomize failed");
      packed_negative += packed_item.p.s < 0;
      plain_negative += plain_item.s < 0;
    end
    if (packed_negative < 50 || plain_negative < 50)
      $fatal(1, "signed dist range underweighted: packed %0d/100 plain %0d/100",
             packed_negative, plain_negative);
    $display("PASS");
  end
endmodule

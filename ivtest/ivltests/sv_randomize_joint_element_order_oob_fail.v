class joint_element_oob;
  rand bit values[2];
  constraint order_c { solve values[0] before values[2]; }
endclass
class joint_element_oob_nonzero;
  rand bit values[5:4];
  constraint order_c { solve values[6] before values[4]; }
endclass
class joint_element_oob_negative;
  rand bit values[-2:-3];
  constraint order_c { solve values[-2] before values[-4]; }
endclass
module sv_randomize_joint_element_order_oob_fail;
  joint_element_oob item=new;
  joint_element_oob_nonzero nonzero=new;
  joint_element_oob_negative negative=new;
  initial begin
    void'(item.randomize());
    void'(nonzero.randomize());
    void'(negative.randomize());
  end
endmodule

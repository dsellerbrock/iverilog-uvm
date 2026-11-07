class issue2724_holder;
  bit [7:0] arr[3] = '{10, 20, 30};
endclass

class issue2724_item;
  bit [3:0] st[5] = '{1, 0, 1, 1, 0};
  issue2724_holder h;
  rand int via, ni, nfirst;
  constraint k {
    via == h.arr.sum();
    ni == st.find_index(x) with (x == 1).size();
    nfirst == st.find_first(x) with (x == 1).size();
  }
  function new; h = new; endfunction
endclass

module issue2724_constraint_array_state;
  issue2724_item obj;
  initial begin
    obj = new;
    if (!obj.randomize()) $fatal(1, "randomize failed");
    if (obj.via != 60 || obj.ni != 3 || obj.nfirst != 1)
      $fatal(1, "unexpected values via=%0d ni=%0d nfirst=%0d",
             obj.via, obj.ni, obj.nfirst);
    $display("PASS issue2724 via=%0d ni=%0d nfirst=%0d",
             obj.via, obj.ni, obj.nfirst);
  end
endmodule

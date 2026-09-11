// IEEE 1800-2017/2023 6.21: unnamed-block static locals have no public path.
module sv_hier_unnamed_static_fail;
  task automatic t();
    begin
      static int hidden = 3;
    end
  endtask
  initial $display("%0d", t.hidden);
endmodule

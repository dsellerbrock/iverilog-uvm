// IEEE 1800-2017/2023 16.4, A.6.3: null actions are not begin-end blocks.
module main;
  initial begin
    assert final (1);
    assert #0 (1);
    assert final (0) else ;
    assert #0 (0) else ;
    assume final (1);
    assume #0 (1);
    assume final (0) else ;
    assume #0 (0) else ;
    cover final (1);
    cover #0 (1);
    #1 $display("PASSED");
  end
endmodule

module issue3162_deferred_fork;
  initial begin
    fork
      begin : br
        assert #0 (0) else $display("ERROR: disabled observed");
        assert final (0) else $display("ERROR: disabled final");
        #10 $display("ERROR: disabled continued");
      end
      begin : sibling
        assert #0 (0) else $display("sibling observed");
        assert final (0) else $display("sibling final");
        #10;
      end
      begin : outer_block
        begin : inner_block
          assert #0 (0) else $display("nested observed");
          assert final (0) else $display("nested final");
          #10;
        end
      end
    join_none
    #0 disable br;
    disable outer_block.inner_block;
    #1 $display("done");
  end
endmodule

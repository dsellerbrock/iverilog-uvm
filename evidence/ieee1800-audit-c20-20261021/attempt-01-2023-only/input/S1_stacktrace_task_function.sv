module top;
    task automatic t2;
        string s;
        s = $stacktrace;
        $display("len_ok=%0d", s.len() > 0);
        $stacktrace;
    endtask

    task automatic t1;
        t2();
    endtask

    initial t1();
endmodule

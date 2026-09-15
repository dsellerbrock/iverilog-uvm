module sv_const_string_format;
 function automatic string decimal(input integer value);string s;s.itoa(value);return s;endfunction
 function automatic string hexadecimal(input integer value);string s;s.hextoa(value);return s;endfunction
 function automatic string octal(input integer value);string s;s.octtoa(value);return s;endfunction
 function automatic string binary(input integer value);string s;s.bintoa(value);return s;endfunction
 function automatic string real_text(input real value);string s;s.realtoa(value);return s;endfunction
 function automatic string decimal_real(input real value);string s;s.itoa(value);return s;endfunction
 function automatic string nested(input integer value);string s;s.hextoa(value);s=s.toupper();return s;endfunction
 function automatic string repeated();string s;for(integer i=0;i<4;i++)s.itoa(i);return s;endfunction
 function automatic string once();string s;integer calls=27;s.hextoa(calls++);if(calls!=28)return "BAD";return s;endfunction
 function automatic string literal_integer();string s;s.itoa("abc");return s;endfunction
 function automatic string explicit_integer(input string arg);string s;s.itoa(int'(arg));return s;endfunction
 function automatic string direct_result(input integer value);direct_result.itoa(value);endfunction
 localparam string DNEG=decimal(-123),DZERO=decimal(0);
 localparam string HNEG=hexadecimal(-255),OCT=octal(83),BIN=binary(10);
 localparam string REAL=real_text(12.5),NESTED=nested(8'haf);
 localparam string RPOS=decimal_real(1.6),RNEG=decimal_real(-1.6);
 localparam string IMIN=decimal(32'sh80000000),IMAX=decimal(32'sh7fffffff);
 localparam string WIDE=decimal(64'h1_0000_0001),NARROW=decimal(4'shf),REPEAT=repeated(),ONCE=once();
 localparam string LITERAL=literal_integer(),EXPLICIT=explicit_integer("abc");
 localparam string RZERO=real_text(0.0),RNEGATIVE=real_text(-2.5),RINTEGER=real_text(7),DIRECT=direct_result(42);
 initial begin
  string d,h,o,b,r;
  d.itoa(-123);h.hextoa(-255);o.octtoa(83);b.bintoa(10);r.realtoa(12.5);
  if(DNEG!="-123"||DZERO!="0"||HNEG!="-ff"||OCT!="123"||BIN!="1010"||REAL!="12.5"||NESTED!="AF"||RPOS!="2"||RNEG!="-2"||IMIN!="-2147483648"||IMAX!="2147483647"||WIDE!="1"||NARROW!="-1"||REPEAT!="3"||ONCE!="1b"||LITERAL!="6382179"||EXPLICIT!="6382179"||RZERO!="0"||RNEGATIVE!="-2.5"||RINTEGER!="7"||DIRECT!="42")
   $fatal(1,"constant format mismatch");
  if(d!=DNEG||h!=HNEG||o!=OCT||b!=BIN||r!=REAL)$fatal(1,"runtime/constant mismatch");
  $display("PASSED");
 end
endmodule

# Dedupe: §19.5.4 wildcard arrayed transition bins

Open and closed issue searches run on 2026-10-21:

- `wildcard arrayed transition bins`: no open or closed result.
- `wildcard transition pattern range`: no open or closed result.
- `wildcard transition nonliteral`: no open or closed result.
- `arrayed wildcard bins`: no open or closed result.
- `wildcard transition bins`: no open result; closed #661.
- `"T0_3_array"`: no open or closed result.

Reviewed closed issue [#661](https://github.com/dsellerbrock/iverilog-uvm/issues/661) and its resolution comment [#issuecomment-6280082010](https://github.com/dsellerbrock/iverilog-uvm/issues/661#issuecomment-6280082010): scalar wildcard transition bins were fixed by #662; arrayed wildcard bins and nonliteral/range patterns were explicitly left unsupported. Thus this is already covered, and the lead should add the exact result to #661 rather than file a duplicate.

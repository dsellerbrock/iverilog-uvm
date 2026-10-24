# Standard basis

IEEE 1800-2017 §15.4.6 and IEEE 1800-2023 §15.4.6 state that `try_get()`
returns a negative integer when the message-variable type is not equivalent
to the queued message type. The corresponding §15.4.8 `try_peek()` rule
requires the same negative return on type mismatch without removing the item.
The original quoted clause text and issue report are in open issue #695.

Source PDFs: `/Users/danielellerbrock/Documents/Standards/1800-2017.pdf` and
`/Users/danielellerbrock/Documents/Standards/1800-2023.pdf`.

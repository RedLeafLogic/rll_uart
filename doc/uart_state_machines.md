# UART state machines

The transmitter and receiver use independent state registers. Both use
`uart_codec_state` to calculate the normal frame-sequence transition, while
the receiver adds false-start, framing-error and break-handling transitions.

## Transmitter

```mermaid
stateDiagram-v2
    [*] --> IDLE

    IDLE --> START : fifo_pop.pop_accept / latch data and format
    START --> SEL_0 : advance
    SEL_0 --> SEL_1 : advance
    SEL_1 --> SEL_2 : advance
    SEL_2 --> SEL_3 : advance

    SEL_3 --> DATA_END : advance and 5-bit
    SEL_3 --> SEL_4 : advance and 6/7/8-bit
    SEL_4 --> DATA_END : advance and 6-bit
    SEL_4 --> SEL_5 : advance and 7/8-bit
    SEL_5 --> DATA_END : advance and 7-bit
    SEL_5 --> SEL_6 : advance and 8-bit
    SEL_6 --> DATA_END : advance

    DATA_END --> PARITY : advance and parity enabled
    DATA_END --> STOP : advance and parity disabled
    PARITY --> STOP : advance

    STOP --> IDLE : advance and one stop bit
    STOP --> STOP_EXTRA : advance and extra stop enabled
    STOP_EXTRA --> IDLE : final stop interval complete
```

`advance` is normally `trans_clk_en`. For a 5-bit character with 1.5 stop
bits, `STOP_EXTRA` completes on `trans_half_en`.

## Receiver

```mermaid
stateDiagram-v2
    [*] --> IDLE

    IDLE --> START : falling edge on filtered RX
    START --> IDLE : sample pulse and RX high (false start)
    START --> SEL_0 : sample pulse and RX low
    SEL_0 --> SEL_1 : sample pulse
    SEL_1 --> SEL_2 : sample pulse
    SEL_2 --> SEL_3 : sample pulse

    SEL_3 --> DATA_END : sample pulse and 5-bit
    SEL_3 --> SEL_4 : sample pulse and 6/7/8-bit
    SEL_4 --> DATA_END : sample pulse and 6-bit
    SEL_4 --> SEL_5 : sample pulse and 7/8-bit
    SEL_5 --> DATA_END : sample pulse and 7-bit
    SEL_5 --> SEL_6 : sample pulse and 8-bit
    SEL_6 --> DATA_END : sample pulse

    DATA_END --> PARITY : sample pulse and parity enabled
    DATA_END --> STOP : sample pulse and parity disabled
    PARITY --> STOP : sample pulse

    STOP --> IDLE : RX high / push character
    STOP --> WAIT_HIGH : RX low but not an all-low frame / push character
    STOP --> BREAK_CHECK : RX low after an all-low frame

    BREAK_CHECK --> BREAK_CHECK : remaining break qualification interval
    BREAK_CHECK --> IDLE : qualification complete and RX high / push character
    BREAK_CHECK --> WAIT_HIGH : qualification complete and RX low / push break character
    WAIT_HIGH --> WAIT_HIGH : RX remains low
    WAIT_HIGH --> IDLE : RX returns high
```

## Receive timeout

Receive timeout is not a codec state. It is measured independently in
`uart_register` while the receive FIFO is non-empty.

```mermaid
stateDiagram-v2
    [*] --> CLEAR
    CLEAR --> COUNTING : RX FIFO becomes non-empty
    COUNTING --> COUNTING : half-character timing tick
    COUNTING --> TIMEOUT_PENDING : four configured character times elapsed
    COUNTING --> CLEAR : RX read/push, FIFO clear/empty, or baud/LCR write
    TIMEOUT_PENDING --> CLEAR : RX read/push, FIFO clear/empty, or baud/LCR write
```

The legacy `TIMEOUT` value remains in `codec_state_t`, but the current TX and
RX state machines do not transition to it.

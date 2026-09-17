# UART register structure

This diagram reflects the packed types currently defined in
`rtl/uart_package.sv`.

```mermaid
classDiagram
    direction LR

    class uart_package {
        <<package>>
        uart_parity()
    }

    class u_reg_t {
        <<packed struct>>
        interrupt_enable_reg_t interrupt_enable_reg
        interrupt_identification_reg_t interrupt_ident_reg
        fifo_control_reg_t fifo_control_reg
        modem_control_reg_t modem_control_reg
        line_control_reg_t line_control_reg
        line_status_reg_t line_status_reg
        modem_status_reg_t modem_status_reg
        interrupt_pending_reg_t interrupt_pending_reg
        logic[7:0] scratch_reg
        logic[7:0] baud_reg
    }

    class u_codec_t {
        <<packed struct>>
        logic[7:0] data_r
        logic start
        logic line
        logic framing_err
        logic parity_err
        logic break_err
        codec_state_t state
    }

    class uart_format_t {
        <<packed struct>>
        logic stick_parity
        logic even_parity
        logic parity_enable
        logic stop_bit_count
        char_length_t char_length
    }

    class interrupt_enable_reg_t {
        <<8-bit packed struct>>
        logic[3:0] ignored_74_bit
        logic modem_status
        logic rec_line_status
        logic trans_holding_reg_empty
        logic rec_data_available
    }

    class interrupt_identification_reg_t {
        <<8-bit packed struct>>
        logic[3:0] ignored_74_value_hC
        interrupt_identification_t interrupt_identification
    }

    class fifo_control_reg_t {
        <<8-bit packed struct>>
        define_fifo_trigger_level_t define_fifo_trigger_level
        logic[2:0] ignored_53_bit
        logic transmitter_fifo_reset
        logic receiver_fifo_reset
        logic ignored_0_bit
    }

    class modem_control_reg_t {
        <<8-bit packed struct>>
        logic[2:0] ignored_75_bit
        logic loopback
        logic out2
        logic out1
        logic rts
        logic dtr
    }

    class line_control_reg_t {
        <<8-bit packed struct>>
        logic divisor_access
        logic break_control_bit
        logic stick_parity
        logic even_parity
        logic parity_enable
        logic stop_bit_count
        char_length_t char_length
    }

    class line_status_reg_t {
        <<8-bit packed struct>>
        logic all_error
        logic trans_empty
        logic trans_fifo_empty
        logic break_intr
        logic framing_err
        logic parity_err
        logic overrun_err
        logic data_ready
    }

    class modem_status_reg_t {
        <<8-bit packed struct>>
        logic dcd
        logic ri
        logic dsr
        logic cts
        logic dcd_indicator
        logic ri_indicator
        logic dsr_indicator
        logic cts_indicator
    }

    class interrupt_pending_reg_t {
        <<internal packed struct>>
        logic modem_status
        logic transmitter_holding_register_empty
        logic timeout_indication
        logic receiver_data_available
        logic receiver_line_status
    }

    uart_package ..> u_reg_t : defines
    uart_package ..> u_codec_t : defines
    uart_package ..> uart_format_t : defines

    u_reg_t *-- interrupt_enable_reg_t
    u_reg_t *-- interrupt_identification_reg_t
    u_reg_t *-- fifo_control_reg_t
    u_reg_t *-- modem_control_reg_t
    u_reg_t *-- line_control_reg_t
    u_reg_t *-- line_status_reg_t
    u_reg_t *-- modem_status_reg_t
    u_reg_t *-- interrupt_pending_reg_t
```

## Implementation notes

- `u_reg_t` is an exported snapshot assembled from the independent register and
  status signals in `uart_register`; it is not a separate physical register
  bank.
- `u_codec_t` is a waveform/debug snapshot of transmitter or receiver state.
- `uart_format_t` captures the line format at the beginning of each frame so
  that an in-progress frame is not affected by later LCR writes.
- `interrupt_pending_reg_t` is internal state and is not a software-visible
  16550 register.

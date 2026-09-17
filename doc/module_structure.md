# UART module structure

This diagram reflects the current RTL instance hierarchy and the principal
package/interface dependencies.

```mermaid
classDiagram
    direction TB

    class uart_16550_rll {
        <<module>>
        wb_bus wb_bus
        uart_bus uart_bus
        u_reg_t u_reg
    }

    class uart_register {
        <<module>>
        fifo_rec : uart_fifo
        fifo_trans : uart_fifo
    }

    class uart_transmitter {
        <<module>>
        trans_state : uart_codec_state
    }

    class uart_receiver {
        <<module>>
        rec_state : uart_codec_state
    }

    class uart_baud {
        <<module>>
    }

    class uart_noize_shaver {
        <<module>>
    }

    class uart_codec_state {
        <<module>>
        codec_state_t state
        codec_state_t next_state
    }

    class uart_fifo {
        <<module x2>>
        fifo_bus fifo_pop
        fifo_bus fifo_push
    }

    class uart_package {
        <<package>>
        u_reg_t
        u_codec_t
        uart_format_t
        codec_state_t
        uart_parity()
    }

    class fifo_package {
        <<package>>
        u_fifo_t
    }

    class uart_bus {
        <<interface>>
        stx_o
        srx_i
        rts_o
        cts_i
        dtr_o
        dsr_i
        ri_i
        dcd_i
    }

    class wb_bus {
        <<interface>>
        Wishbone signals
    }

    class fifo_bus {
        <<interface>>
        push_master_mp
        push_slave_mp
        pop_master_mp
        pop_slave_mp
    }

    uart_16550_rll *-- uart_register : u_register
    uart_16550_rll *-- uart_transmitter : u_trans
    uart_16550_rll *-- uart_receiver : u_rec
    uart_16550_rll *-- uart_baud : u_baud
    uart_16550_rll *-- uart_noize_shaver : u_shaver

    uart_register *-- uart_fifo : fifo_rec and fifo_trans
    uart_transmitter *-- uart_codec_state : trans_state
    uart_receiver *-- uart_codec_state : rec_state

    uart_16550_rll ..> uart_package : imports
    uart_16550_rll ..> uart_bus : uses
    uart_16550_rll ..> wb_bus : uses
    uart_16550_rll ..> fifo_bus : connects submodules
    uart_register ..> fifo_bus : uses
    uart_transmitter ..> fifo_bus : TX pop
    uart_receiver ..> fifo_bus : RX push
    uart_fifo ..> fifo_bus : uses
    uart_fifo ..> fifo_package : imports
```

## Notes

- `uart_register` owns two `uart_fifo` instances: `fifo_rec` and `fifo_trans`.
- `uart_transmitter` does not own the transmit FIFO; it accesses it through a
  `fifo_bus` instance created by `uart_16550_rll`.
- `uart_transmitter` and `uart_receiver` each own an independent
  `uart_codec_state` instance.
- `uart_bus` and `wb_bus` are both declared in `rtl/uart_interface.sv`.

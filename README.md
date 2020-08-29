# SPI_Master_HDL

Project creates a SPI master on the GO Board FPGA. The interface sends out a byte one bit at a time on MOSI (Masoter out Slave in)
and recieves byte data one bit at a time on MISO (Master in Slave out).

**SPI_Master.v** module creates a SPI master that works with all 4 modes of SPI. The module does not contain a chip select
which will get instantiated in a higher level module.

**SPI_Master_TB.v** module is the testbench for SPI_Master. The output waveform from Modelsim can be seen in SPI_Master_TB_Waveform

**SPI_Master_With_Chip_Select** module is a higher level module to SPI_Master which adds a single chip select. The module also supports
arbitrary length byte transfers. To use multiple chip select signals, a multiplexer is needed in a higer level module.

**SPI_Master_With_Chip_Select_TB** module is the testbench. The output waveform from Modelsim can be seen in SPI_Master_With_Chip_Select_Waveform

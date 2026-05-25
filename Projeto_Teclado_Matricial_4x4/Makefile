SHELL     := /bin/bash
IVERILOG  = iverilog
VVP       = vvp
GTKWAVE   = gtkwave

TOP       = tb_teclado
SIM_OUT   = simulacao.vvp
VCD       = teste_teclado.vcd

TOP_C1      = tb_cenario1_decodifica_teclas
SIM_OUT_C1  = simulacao_cenario1.vvp
VCD_C1      = tb_cenario1.vcd

SRCS      = design_teclado_matricial_4x4.sv \
            teste_teclado_matricial_4x4.sv

SRCS_C1   = design_teclado_matricial_4x4.sv \
            tb_cenario1_decodifica_teclas.sv

FLAGS     = -g2012 -Wall

.PHONY: all run wave clean cenario1 run_c1 wave_c1

all: $(SIM_OUT)

$(SIM_OUT): $(SRCS)
	$(IVERILOG) $(FLAGS) -s $(TOP) -o $@ $^

run: $(SIM_OUT)
	$(VVP) $< +seed=$$RANDOM

wave: $(VCD)
	$(GTKWAVE) $<

$(VCD): run

# --- Cenário 1: Decodificação do Teclado ---
cenario1: $(SIM_OUT_C1)

$(SIM_OUT_C1): $(SRCS_C1)
	$(IVERILOG) $(FLAGS) -s $(TOP_C1) -o $@ $^

run_c1: $(SIM_OUT_C1)
	$(VVP) $< +seed=$$RANDOM

wave_c1: $(VCD_C1)
	$(GTKWAVE) $<

$(VCD_C1): run_c1

clean:
	rm -f $(SIM_OUT) $(VCD) $(SIM_OUT_C1) $(VCD_C1)

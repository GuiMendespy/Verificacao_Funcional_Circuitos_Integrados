SHELL := /bin/bash

PROJECT := $(word 2, $(MAKECMDGOALS))

ifneq ($(PROJECT),)
  SRCS    := $(wildcard $(PROJECT)/src/*.sv)
  TOP     := $(shell awk '/^module /{print $$2; exit}' $(PROJECT)/src/teste_bench.sv | tr -dc 'a-zA-Z0-9_')
  SIM_OUT := $(PROJECT)/sim.vvp
  VCD     := $(shell grep -m1 'dumpfile' $(PROJECT)/src/teste_bench.sv | grep -o '"[^"]*"' | tr -d '"')
  .PHONY: $(PROJECT)
  $(PROJECT): ;
endif

FLAGS := -g2012 -Wall

.PHONY: run wave clean help _guard

_guard:
	@[ -n "$(PROJECT)" ] || (echo "Erro: informe o projeto. Ex: make run 2-teclado-matricial"; exit 1)

$(SIM_OUT): $(SRCS)
	iverilog $(FLAGS) -s $(TOP) -o $@ $^

run: _guard $(SIM_OUT)
	vvp $(SIM_OUT) +seed=$$RANDOM

wave: _guard $(SIM_OUT)
	vvp $(SIM_OUT) +seed=$$RANDOM
	gtkwave $(VCD)

clean:
	@if [ -n "$(PROJECT)" ]; then \
		rm -f $(SIM_OUT) $(VCD); \
	else \
		find . -name "sim.vvp" -delete; \
		find . -name "*.vcd" ! -path "./.git/*" -delete; \
	fi

help:
	@echo "Uso: make <acao> <projeto>"
	@echo ""
	@echo "  make run  <projeto>   compila e simula"
	@echo "  make wave <projeto>   compila, simula e abre GTKWave"
	@echo "  make clean <projeto>  remove arquivos gerados do projeto"
	@echo "  make clean            remove todos os arquivos gerados"
	@echo ""
	@echo "Projetos disponíveis:"
	@ls -d [0-9]*/ 2>/dev/null | sed 's|/||'

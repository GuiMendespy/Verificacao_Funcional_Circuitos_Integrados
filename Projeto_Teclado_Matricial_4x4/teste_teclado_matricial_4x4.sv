`timescale 1ns/1ps
`define DEBUG 0

// Garanta que a struct esteja visível no testbench.
// Se o seu pacote real tiver outro nome, descomente e use o seu original.


module tb_teclado;

    logic clk, rst, enable;
    logic [3:0] col_matriz;
    logic [3:0] lin_matriz;
    senhaPac_t digitos_value;
    logic digitos_valid;

    decodificador_de_teclado dut (
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .col_matriz(col_matriz),
        .lin_matriz(lin_matriz),
        .digitos_value(digitos_value),
        .digitos_valid(digitos_valid)
    );

    // Gerador de clock
    initial clk = 0;
    always #1 clk = ~clk;
    
    bit [3:0] num;

    task gerar_num_aleatorio(output bit [3:0] numero_out);
        numero_out = $urandom_range(3, 0); 
    endtask

    task varrer_coluna;
        bit [3:0] num; 
        gerar_num_aleatorio(num);
        
        case(num)
            4'd0    : col_matriz = 4'b0111;
            4'd1    : col_matriz = 4'b1011;
            4'd2    : col_matriz = 4'b1101;
            4'd3    : col_matriz = 4'b1110;
            default : col_matriz = 4'b1111; 
        endcase
        if (DEBUG) $display("[DEBUG TB] Coluna injetada pelo teste: %b (Sorteio num=%0d)", col_matriz, num);
    endtask

    function bit [3:0] descobrir_digito_esperado();
        bit [3:0] digito_local;
        digito_local = 4'hF; 

        // Adicionado um display para você ver o que o DUT está enviando de linha
        if (DEBUG) $display("[DEBUG TB] Analisando pinos atuais -> Linha: %b | Coluna: %b", lin_matriz, col_matriz);

        if (lin_matriz == 4'b0111) begin 
            if      (col_matriz == 4'b0111) digito_local = 4'h1;
            else if (col_matriz == 4'b1011) digito_local = 4'h2;
            else if (col_matriz == 4'b1101) digito_local = 4'h3;
        end
        else if (lin_matriz == 4'b1011) begin 
            if      (col_matriz == 4'b0111) digito_local = 4'h4;
            else if (col_matriz == 4'b1011) digito_local = 4'h5;
            else if (col_matriz == 4'b1101) digito_local = 4'h6;
        end
        else if (lin_matriz == 4'b1101) begin 
            if      (col_matriz == 4'b0111) digito_local = 4'h7;
            else if (col_matriz == 4'b1011) digito_local = 4'h8;
            else if (col_matriz == 4'b1101) digito_local = 4'h9;
        end
        else if (lin_matriz == 4'b1110) begin 
            if      (col_matriz == 4'b0111) digito_local = 4'hA; // '#'
            else if (col_matriz == 4'b1011) digito_local = 4'h0;
            else if (col_matriz == 4'b1101) digito_local = 4'hB; // '*'
        end

        return digito_local;
    endfunction

    task aplicar_debounce;
        $display("[DEBOUNCE] Segurando a estabilidade dos pinos por 110 ciclos de clock...");
        
        repeat(110) @(posedge clk);
        
        $display("[DEBOUNCE] Tempo de estabilização concluído.");
    endtask
  
    task teste_decodificar_teclado;
        bit [3:0] esperado;

        $display("[START] Iniciando a task de teste...");
        
        col_matriz = 4'b1111;

        rst = 1;
        enable = 1; 
        #10; 
        rst = 0; 
        if (DEBUG) $display("[DEBUG TB] Reset finalizado.");

        repeat(5) @(posedge clk);
        varrer_coluna();
        aplicar_debounce();
        repeat(5) @(posedge clk);

        esperado = descobrir_digito_esperado();
        if (DEBUG) $display("[DEBUG TB] Resultado calculado pelo modelo de teste: %X", esperado);
        if (DEBUG) $display("[DEBUG TB] Valor atual na saída do DUT: %X", digitos_value.digits[0]);

        if (digitos_value.digits[0] === esperado) begin
            $display("[SUCESSO] Teste de decodificação realizado! Injetado Hex: %X", esperado);
        end
        else begin
            $display("[FALHA] Esperado: %X, Obtido no DUT: %X", esperado, digitos_value.digits[0]);
        end
    endtask

    initial begin
        $display("=== INICIO DA SIMULACAO ===");
        $dumpfile("teste_teclado.vcd");
        $dumpvars(0, tb_teclado);
		$display("=== INICIANDO MARATONA DE 5 TESTES ALEATÓRIOS ===");

        repeat(5) begin
            $display("\n------------------------------------------------");
            teste_decodificar_teclado();
            #50; 
        end

        $display("\n================================================");
        $display("=== FIM DA MARATONA DE TESTES ===");

        #100;
        $display("=== FIM DA SIMULACAO ===");
        $finish;
    end

endmodule
`timescale 1ns/1ps
`define DEBUG 0
`define MAX_COBERTURA 10
`define DEBOUNCE_PRESSIONAMENTO 100
`define MAX_ESPERA 20

module tb_teclado;

    logic clk, rst, enable;
    logic [3:0] col_matriz;
    logic [3:0] lin_matriz;
    digitosPac_t digitos_value;
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

    always #0.5 clk = ~clk;

    initial begin
        clk = 0;
        enable = 1;
    end

    bit [3:0] num;
    integer hit_count[10];

    // ================================================================
    // Utilitarios
    // ================================================================

    function logic [7:0] get_coords(input logic [3:0] d);
        case (d)
            4'h0:    return 8'b1110_1011;
            4'h1:    return 8'b0111_0111;
            4'h2:    return 8'b0111_1011;
            4'h3:    return 8'b0111_1101;
            4'h4:    return 8'b1011_0111;
            4'h5:    return 8'b1011_1011;
            4'h6:    return 8'b1011_1101;
            4'h7:    return 8'b1101_0111;
            4'h8:    return 8'b1101_1011;
            4'h9:    return 8'b1101_1101;
            default: return 8'b1111_1111;
        endcase
    endfunction

    task pressionar_digito(input logic [3:0] d);
        logic [7:0] coords;
        coords = get_coords(d);

        if (`DEBUG) $display("[DEBUG TB] Iniciando pressionamento de %1d...", d);

        while (lin_matriz !== coords[7:4]) begin
            if (`DEBUG) $display("[DEBUG TB] lin_matriz = 0b%4b", lin_matriz);
            @(posedge clk);
        end
        col_matriz = coords[3:0];
        repeat(`DEBOUNCE_PRESSIONAMENTO) @(posedge clk);
        col_matriz = 4'b1111;
        repeat(`MAX_ESPERA) @(posedge clk);
        // esperamos o máximo sempre para garantir
        // que os dados vão está no barramento

        if (`DEBUG) $display("[DEBUG TB] Pressionamento finalizado.");
    endtask

    task pressionar_asterisco;
        if (`DEBUG) $display("[DEBUG TB] Iniciando confirmamento...");

        while (lin_matriz !== 4'b1110) @(posedge clk);
        col_matriz = 4'b0111;
        repeat(`DEBOUNCE_PRESSIONAMENTO) @(posedge clk);
        col_matriz = 4'b1111;
        repeat(`MAX_ESPERA) @(posedge clk);

        if (`DEBUG) $display("[DEBUG TB] Confirmamento finalizado.");
    endtask

    task fazer_reset;
        if (`DEBUG) $display("[DEBUG TB] Iniciando reset...");
        col_matriz = 4'b1111;
        rst    = 1;
        repeat(5) @(posedge clk);
        rst    = 0;
        repeat(5) @(posedge clk);
        if (`DEBUG) $display("[DEBUG TB] Reset finalizado.");
    endtask

    task linha(input bit m);
        if (m)
            $display("===============================================");
        else
            $display("-----------------------------------------------");
    endtask

    task gerar_num_aleatorio(output bit [3:0] numero_out);
        numero_out = $urandom_range(0, 9);
        if (`DEBUG) $display("[DEBUG TB] Número aleatório gerado: %d", numero_out);
    endtask

    function bit cobertura_completa;
        for (int i = 0; i <= 9; i++)
            if (hit_count[i] < `MAX_COBERTURA) return 0;
        return 1;
    endfunction

    task limpar_cobertura;
        foreach (hit_count[i]) hit_count[i] = 0;
        if (`DEBUG) $display("[DEBUG TB] Cobertura limpa.");
    endtask

    task exibir_cobertura;
        int c;
        integer cobertos;
        c = 0;
        cobertos = 0;
        $display("             RELATORIO DE COBERTURA");
        linha(0);
        for (int i = 0; i <= 9; i++) begin
            $display(
                " Digito %0d: %0d/%1d \t\t    %s",
                i,
                hit_count[i],
                `MAX_COBERTURA,
                hit_count[i] >= `MAX_COBERTURA ? "[COBERTO]" : "[PENDENTE]"
            );
            if (hit_count[i] >= `MAX_COBERTURA) cobertos++;
        end
        linha(0);
        for (int i = 0; i <= 9; i++)
            c += hit_count[i];
        $display("  Total: %0d/10 digitos cobertos (%.0f%%)", cobertos, c * 100 / (10 * `MAX_COBERTURA));
        linha(1);
    endtask

    // ================================================================
    // CENARIO 1 — Decodificação do teclado
    // ================================================================
    task teste_decodificar_teclado;
        bit [3:0] esperado;

        $display("           CENÁRIO 1: DECODIFICAÇÃO");
        linha(1);

        fazer_reset();
        limpar_cobertura();
        exibir_cobertura();

        while (!cobertura_completa()) begin
            gerar_num_aleatorio(num);

            pressionar_digito(num);

            if (digitos_value.digits[0] != num) begin
                $display("[FALHA] Esperado: %X, Obtido: %X", num, digitos_value.digits[0]);
                $finish;
            end
            else if (hit_count[num] < `MAX_COBERTURA)
                hit_count[num]++;

            $write("\x1b[15A");
            exibir_cobertura();
        end
    endtask

    // ================================================================
    // CENARIO 2 — Shift do barramento
    // ================================================================
    task teste_shift_barramento;
        digitosPac_t sequencia_esperada;
        logic [3:0] digito_atual;
        integer erros;

        $display("               CENARIO 2: Shift");
        linha(1);

        fazer_reset();
        sequencia_esperada = ~0;

        $display(" Digitando sequencia de 0-9 duas vezes...");
        linha(0);
        for (int i = 0; i < 20; i++) begin
            digito_atual = i % 10;
            sequencia_esperada = (sequencia_esperada << 4) | digito_atual;
            pressionar_digito(digito_atual);
            $display(" Digitando %1d...           %20h", digito_atual, digitos_value);
            if (digitos_value != sequencia_esperada) begin
                $display("%20h = %20h : %1b", digitos_value, sequencia_esperada, digitos_value == sequencia_esperada);
                $finish;
            end
            if (`DEBUG) $display("%20h = %20h : %1b", digitos_value, sequencia_esperada, digitos_value == sequencia_esperada);
        end

        linha(0);
        $display(" Digitando 50 números aleatórios...");
        linha(0);

        for (int i = 0; i < 50; i++) begin
            gerar_num_aleatorio(digito_atual);

            sequencia_esperada = (sequencia_esperada << 4) | digito_atual;

            pressionar_digito(digito_atual);

            $display(" Digitando %1d...           %20h", digito_atual, digitos_value);
            if (digitos_value != sequencia_esperada) begin
                $display("%20h = %20h : %1b", digitos_value, sequencia_esperada, digitos_value == sequencia_esperada);
                $finish;
            end
            if (`DEBUG) $display("%20h = %20h : %1b", digitos_value, sequencia_esperada, digitos_value == sequencia_esperada);
        end

        linha(1);
    endtask

    // ================================================================
    // CENARIO 3 — Debounce
    // ================================================================
    task teste_debounce_tecla(input logic [3:0] tecla);
        logic [7:0] coords;
        logic [3:0] l, c;
        logic [7:0] i;

        integer limite_max_press;
        integer ciclos_pressionado;
        integer ciclos_solto;
        longint t_inicio;
        linha(1);

        fazer_reset();

        coords = get_coords(tecla);
        l      = coords[7:4];
        c      = coords[3:0];

        $display(" Tecla alvo: %0d", tecla);
        linha(0);

        limite_max_press   = 5;
        t_inicio           = $time;


        fork : ruidos
            begin
                for (i = 0; i < 100; i++) @(posedge clk);
                disable ruidos;
            end
            begin
                while (1) begin
                    ciclos_pressionado = $urandom_range(1, limite_max_press);
                    ciclos_solto       = $urandom_range(2, 15);

                    while (lin_matriz != l) @(posedge clk);
                    col_matriz = c;
                    $display(" [%03dns] Ruído com duração %1dns", $time - t_inicio, ciclos_pressionado);

                    repeat (ciclos_pressionado) @(posedge clk);

                    col_matriz = 4'b1111;

                    repeat (ciclos_solto) @(posedge clk);

                    limite_max_press = (limite_max_press * 5)/3;
                end
            end
        join

        while (lin_matriz != l) @(posedge clk);
        col_matriz = c;
        $display(" [%03dns] O sinal estabilizou", $time - t_inicio);

        repeat(`DEBOUNCE_PRESSIONAMENTO) @(posedge clk);
        $display(" [%03dns] O sinal passou o debounce", $time - t_inicio);

        repeat(`MAX_ESPERA) @(posedge clk);

            $display(" [%03dns] Barramento: %20h", $time - t_inicio, digitos_value);
        linha(0);
        // Validação final do barramento
        if (digitos_value == (~0 << 4) | tecla) begin
            $display(" [SUCESSO] Tecla %0d foi gravada no barramento!", tecla);
        end
        else begin
            $display(" [FALHA] O sinal estabilizou mas o barramento contem: 0x%X (esperado: 0x%X)", digitos_value.digits[0], tecla);
        end
    endtask

    task teste_debounce;
        $display("              CENARIO 3: Debounce");

        for (int i = 0; i < 10; i++) begin
            teste_debounce_tecla(i);
        end

        linha(1);
    endtask

    // ================================================================
    // CENARIO 4 — Repeticao automatica da tecla
    // ================================================================
    task teste_repeticao_tecla;
        logic [3:0] tecla;
        logic [7:0] coords;
        logic [3:0] l, c;
        logic [79:0] shadow_matrix;

        $display("   CENARIO 4: Repetição Automática de Teclas");
        linha(1);

        fazer_reset();

        gerar_num_aleatorio(tecla);
        coords = get_coords(tecla);
        l      = coords[7:4];
        c      = coords[3:0];

        $display(" Tecla sorteada para teste de pressao longa: %0d", tecla);
        linha(0);

        while (lin_matriz !== l) @(posedge clk);
        col_matriz = c;
        repeat(`DEBOUNCE_PRESSIONAMENTO) @(posedge clk);

        shadow_matrix = digitos_value;
        if (shadow_matrix[3:0] === tecla) begin
            $display(" [OK] Tecla %0d registrada pela primeira vez com sucesso!", tecla);
        end else begin
            $display(" [AVISO] Tecla ainda nao apareceu no barramento. Obtido: 0x%X", shadow_matrix[3:0]);
        end

        $display(" Mantendo pressionado... aguardando 2000 clks para a 1a repeticao...");
        repeat(2000) @(posedge clk);

        shadow_matrix = digitos_value;
        $display(" Checando o barramento apos os primeiros 2 segundos...");
        if (shadow_matrix[3:0] === tecla && shadow_matrix[7:4] === tecla) begin
            $display(" [SUCESSO] 1a Repeticao Detectada! O digito duplicou: [0]=0x%X, [1]=0x%X",
                     shadow_matrix[3:0], shadow_matrix[7:4]);
        end else begin
            $display(" [AVISO] A 1a repeticao nao aconteceu apos 2s. Barramento: [0]=0x%X, [1]=0x%X",
                     shadow_matrix[3:0], shadow_matrix[7:4]);
        end

        $display(" Mantendo pressionado... aguardando +1000 clks para a 2a repeticao (ritmo de 1s)...");
        repeat(1000) @(posedge clk);

        shadow_matrix = digitos_value;
        $display(" Checando o barramento apos mais 1 segundo...");
        if (shadow_matrix[3:0] === tecla && shadow_matrix[7:4] === tecla && shadow_matrix[11:8] === tecla) begin
            $display(" [SUCESSO] 2a Repeticao Detectada! O digito triplicou: [0]=0x%X, [1]=0x%X, [2]=0x%X",
                     shadow_matrix[3:0], shadow_matrix[7:4], shadow_matrix[11:8]);
        end else begin
            $display(" [AVISO] A 2a repeticao falhou ou ritmo de 1s nao foi obedecido. Barramento: [0]=0x%X, [1]=0x%X, [2]=0x%X",
                     shadow_matrix[3:0], shadow_matrix[7:4], shadow_matrix[11:8]);
        end

        col_matriz = 4'b1111;
        repeat(20) @(posedge clk);

        linha(0);
        $display("        RELATORIO DE REPETICAO AUTOMATICA");
        linha(0);
        if (digitos_value.digits[0] === tecla && digitos_value.digits[1] === tecla && digitos_value.digits[2] === tecla) begin
            $display(" [SUCESSO] Maquina de estados obedeceu perfeitamente os tempos (Debounce -> 2s -> 1s)!");
        end else if (digitos_value.digits[0] === tecla && digitos_value.digits[1] === tecla) begin
            $display(" [PARCIAL] Apenas uma repeticao ocorreu. Verifique se o loop continuo de 1s esta ativo.");
        end else if (digitos_value.digits[0] === tecla) begin
            $display(" [LIMITADO] Tecla registrada apenas 1 vez. O circuito nao possui auto-repeat.");
        end else begin
            $display(" [FALHA] A tecla sequer foi registrada no teste.");
        end

        linha(1);
        repeat(20) @(posedge clk);
    endtask

    // ================================================================
    // CENARIO 5 — Confirmacao com tecla *
    // ================================================================
    task teste_confirmacao_asterisco;
        localparam integer N = 5;
        logic [3:0]  digitados [N];
        logic [3:0]  esperado_k;
        logic [3:0]  obtido_k;
        logic [79:0] barramento_plano;
        integer ciclos;
        integer erros_dados;
        integer ok_timing, ok_dados;
        integer k;
        logic [3:0]  digito_atual;
        logic [7:0]  coords_atuais;

        $display("       CENARIO 5: Confirmacao com * (ENTER)");
        linha(1);
        fazer_reset();

        $display(" Digitando %0d teclas aleatorias...", N);
        linha(0);
        for (int i = 0; i < N; i++) begin
            digito_atual = $urandom_range(0, 9);
            digitados[i] = digito_atual;
            coords_atuais = get_coords(digito_atual);

            while (lin_matriz !== coords_atuais[7:4]) @(posedge clk);

            col_matriz = coords_atuais[3:0];

            repeat(110) @(posedge clk);

            col_matriz = 4'b1111;
            repeat(15) @(posedge clk);

            if (`DEBUG) $display("  [%0d/%0d] Digitado: %0d | Registrado em digits[0]: %X", i+1, N, digito_atual, digitos_value.digits[0]);
        end

        repeat(5) @(posedge clk);

        $display(" Barramento antes de acionar o ENTER:");
        barramento_plano = digitos_value;
        for (k = 0; k < N; k++) begin
            $display("  barramento_plano[%0d] = 0x%X", k, barramento_plano[k*4 +: 4]);
        end

        linha(0);
        $display(" Pressionando * (ENTER)...");
        while (lin_matriz !== 4'b1110) @(posedge clk);
        col_matriz = 4'b0111;

        ciclos    = 0;
        ok_timing = 0;

        while (!digitos_valid && ciclos < 200) begin
            @(posedge clk);
            ciclos++;
        end

        col_matriz = 4'b1111; 
        repeat(5) @(posedge clk);

        if (digitos_valid || ciclos < 200) begin
            ok_timing = (ciclos <= 120);
            if (ok_timing)
                $display(" [SUCESSO] digitos_valid subiu em %0d ciclos!", ciclos);
            else
                $display(" [FALHA] digitos_valid demorou %0d ciclos para responder!", ciclos);
        end else begin
            $display(" [FALHA] Timeout: O sinal digitos_valid nao subiu apos 200 ciclos.");
        end

        linha(0);
        $display(" Verificando integridade e ordem dos dados...");
        erros_dados = 0;

        for (k = 0; k < N; k++) begin
            esperado_k = digitados[(N - 1) - k];
            obtido_k   = barramento_plano[k*4 +: 4];

            if (obtido_k !== esperado_k) begin
                $display(" [FALHA] Posicao digits[%0d]: esperado=0x%X | obtido=0x%X", k, esperado_k, obtido_k);
                erros_dados++;
            end else begin
                $display(" [OK] digits[%0d]: esperado=0x%X | obtido=0x%X", k, esperado_k, obtido_k);
            end
        end

        ok_dados = (erros_dados == 0);

        linha(0);
        if (ok_dados && ok_timing)
            $display(" [SUCESSO] Sincronismo perfeito.");
        else
            $display(" [FALHA] (Dados=%0s, Timing=%0s).",
                     ok_dados ? "OK" : "ERRO", ok_timing ? "OK" : "ERRO");
        linha(1);

        repeat(30) @(posedge clk);
    endtask

    // ================================================================
    // Bloco principal
    // ================================================================

    initial begin
        integer seed;
        if (!$value$plusargs("seed=%d", seed))
            seed = 42;

        if (`DEBUG) $display("=== SEMENTE ALEATORIA ATIVADA: %0d ===", seed);

        $dumpfile("teste_teclado.vcd");
        $dumpvars(0, tb_teclado);

        linha(1);
        $display("        TESTES DO TECLADO MATRICIAL 4X4        ");
        linha(1);
        $display("              INICIO DA SIMULACAO              ");
        linha(1);

        // ------ Cenario 1: Decodificacao do teclado ------
        teste_decodificar_teclado();

        // ------ Cenario 2: Shift do barramento ------
        teste_shift_barramento();

        // ------ Cenario 3: Debounce ------
        teste_debounce();

        // ------ Cenario 4: Repeticao automatica ------
        teste_repeticao_tecla();

        // ------ Cenario 5: Confirmacao com * ------
        teste_confirmacao_asterisco();

        repeat(10) @(posedge clk);

        $display("                FIM DA SIMULACAO");
        linha(1);
        $finish;
    end

endmodule
`timescale 1ns/1ps
`define DEBUG 1

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

    initial clk = 0;
    always #0.5 clk = ~clk;

    bit [1:0] num;
    integer hit_count [10];

    // ================================================================
    // Utilitarios comuns
    // ================================================================

    // Retorna {lin[7:4], col[3:0]} para o digito d (Icarus nao suporta output em functions)
    function automatic logic [7:0] get_coords(input logic [3:0] d);
        case (d)
            4'h0: return 8'b1110_1011;
            4'h1: return 8'b0111_0111;
            4'h2: return 8'b0111_1011;
            4'h3: return 8'b0111_1101;
            4'h4: return 8'b1011_0111;
            4'h5: return 8'b1011_1011;
            4'h6: return 8'b1011_1101;
            4'h7: return 8'b1101_0111;
            4'h8: return 8'b1101_1011;
            4'h9: return 8'b1101_1101;
            default: return 8'bxxxx_xxxx;
        endcase
    endfunction

    task automatic pressionar_tecla(input logic [3:0] d);
        logic [7:0] coords;
        coords = get_coords(d);
        
        // 1. Aguarda o DUT ativar a linha correta correspondente ao dígito
        while (lin_matriz !== coords[7:4]) @(posedge clk);
        
        // 2. Injeta a coluna (Pressiona o botão)
        col_matriz = coords[3:0];
        
        // 3. CAIXA-PRETA ATUALIZADO:
        // Como o debounce do design exige 100 ciclos (td >= 100), precisamos segurar 
        // a tecla por pelo menos esse tempo, mais uma margem para a FSM processar.
        // Aumentamos o timeout para 250 ciclos para dar tempo do debounce concluir.
        fork : esperar_resposta
            begin
                wait (digitos_value.digits[0] !== 4'hF);
                disable esperar_resposta;
            end
            begin
                // Garante que o botão fica pressionado tempo suficiente para o debounce (100) + decodificação
                repeat(150) @(posedge clk); 
                disable esperar_resposta;
            end
        join

        // 4. Solta a tecla (Simula que o usuário tirou o dedo)
        col_matriz = 4'b1111;
        
        // 5. Aguarda o design processar a liberação da tecla (o estado 'c1' será verdadeiro no design)
        // Isso permite que o design saia de 'inserirNoArray' ou 'limparArray' e volte para 'leitura'
        repeat(20) @(posedge clk);
    endtask

    // Pressiona tecla * para confirmar: LINHA=1110, COL=0111
    task automatic pressionar_asterisco;
        while (lin_matriz !== 4'b1110) @(posedge clk);
        col_matriz = 4'b0111;
        repeat(115) @(posedge clk);
        col_matriz = 4'b1111;
        repeat(10) @(posedge clk);
    endtask

    // Reset padrao entre cenarios
    task fazer_reset;
        col_matriz = 4'b1111;
        rst    = 1;
        enable = 0;
        repeat(5) @(posedge clk);
        rst    = 0;
        enable = 1;
        repeat(5) @(posedge clk);
    endtask

    // ================================================================
    // CENARIO 1 — Decodificacao do teclado (original)
    // ================================================================

    function bit cobertura_completa();
        for (int i = 0; i <= 9; i++)
            if (hit_count[i] < 5) return 0;
        return 1;
    endfunction

    task exibir_cobertura;
        integer cobertos;
        cobertos = 0;
        $display("\n=== RELATORIO DE COBERTURA (meta: 5 hits cada) ===");
        for (int i = 0; i <= 9; i++) begin
            $display("  Digito %0d: %0d/5  %s", i, hit_count[i],
                     hit_count[i] >= 5 ? "[COBERTO]" : "[PENDENTE]");
            if (hit_count[i] >= 5) cobertos++;
        end
        $display("  Total: %0d/10 digitos cobertos (%.0f%%)", cobertos, cobertos * 10.0);
    endtask

    task gerar_num_aleatorio(output bit [3:0] numero_out);
        numero_out = $random(seed) & 3;
    endtask

    task varrer_coluna;
        gerar_num_aleatorio(num);
        case(num)
            4'd0    : col_matriz = 4'b0111;
            4'd1    : col_matriz = 4'b1011;
            4'd2    : col_matriz = 4'b1101;
            default : col_matriz = 4'b1111;
        endcase
        if (`DEBUG) $display("[DEBUG TB] Coluna injetada: %b (num=%0d)", col_matriz, num);
    endtask

    function bit [3:0] descobrir_digito_esperado();
        bit [3:0] digito_local;
        digito_local = 4'hF;
        if (`DEBUG) $display("[DEBUG TB] Linha: %b | Coluna: %b", lin_matriz, col_matriz);
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
            if      (col_matriz == 4'b0111) digito_local = 4'hA;
            else if (col_matriz == 4'b1011) digito_local = 4'h0;
            else if (col_matriz == 4'b1101) digito_local = 4'hB;
        end
        return digito_local;
    endfunction

    task aplicar_debounce;
        $display("[DEBOUNCE] Segurando por 110 ciclos...");
        repeat(110) @(posedge clk);
        $display("[DEBOUNCE] Concluido.");
    endtask

    task teste_decodificar_teclado;
        bit [3:0] esperado;
        $display("[START] Iniciando teste de decodificacao...");
        col_matriz = 4'b1111;
        rst = 1; enable = 1;
        repeat(5) @(posedge clk);
        rst = 0;
        if (`DEBUG) $display("[DEBUG TB] Reset finalizado.");
        gerar_num_aleatorio(num);
        repeat(num + 5) @(posedge clk);
        varrer_coluna();
        aplicar_debounce();
        repeat(5) @(posedge clk);
        esperado = descobrir_digito_esperado();
        if (`DEBUG) $display("[DEBUG TB] Esperado: %X | Obtido: %X", esperado, digitos_value.digits[0]);
        if (digitos_value.digits[0] === esperado)
            $display("[SUCESSO] Decodificacao correta: %X", esperado);
        else
            $display("[FALHA] Esperado: %X, Obtido: %X", esperado, digitos_value.digits[0]);
        if (esperado <= 4'h9)
            hit_count[esperado]++;
    endtask

    // ================================================================
    // CENARIO 2 — Shift do barramento (SEQUENCIAL 0-9 DUAS VEZES)
    // Digita sequencialmente de 0-9 duas vezes (20 digitos), 
    // garante o melhor sincronismo com as linhas e valida o shifter.
    // ================================================================
    task automatic teste_shift_barramento;
        logic [3:0]  sequencia_gerada [21]; 
        logic [3:0]  esperado_k;
        logic [3:0]  obtido_k;
        logic [79:0] shadow_matrix;        
        integer erros;
        integer k;
        logic [3:0] digito_atual;
        logic [7:0] coords_atuais;

        $display("\n================================================");
        $display("=== CENARIO 2: SHIFT SEQUENCIAL 0-9 (2X) =======");
        
        fazer_reset();

        $display("[C2] Digitando sequencia de 0-9 duas vezes (20 digitos)...");
        for (int i = 0; i < 20; i++) begin
            
            // 1. Define o dígito de forma estritamente sequencial (0,1,2...9,0,1,2...9)
            digito_atual = i % 10;
            sequencia_gerada[i] = digito_atual;
            coords_atuais = get_coords(digito_atual);

            // 2. SINCRONISMO MÁXIMO: Aguarda a linha exata do dígito ser varrida pela FSM
            while (lin_matriz !== coords_atuais[7:4]) @(posedge clk);
            
            // 3. Injeta a coluna correspondente no mesmo instante correspondente
            col_matriz = coords_atuais[3:0];

            // 4. Mantém pressionado pelo tempo do debounce (110 ciclos conforme o cenário 1)
            repeat(110) @(posedge clk);
            
            // 5. CAPTURA SEGURO: Salva o barramento imediatamente antes de retirar o estímulo
            shadow_matrix = digitos_value;

            // 6. Solta a tecla e aguarda uma folga para a FSM processar o release e voltar a varrer
            col_matriz = 4'b1111;
            repeat(15) @(posedge clk);

            if (`DEBUG) $display("[C2] [%0d/20] Digitado: %0d | Capturado no SHIFT: %X", i+1, digito_atual, shadow_matrix[3:0]);
        end

       // --- Verificação do Shifter para as 20 posições ---
        $display("[C2] Verificando o deslocamento (shifter) das 20 posicoes...");
        erros = 0;
        for (k = 0; k < 20; k++) begin
            // O último a entrar (índice 19 -> dígito 9) fica na posição 0.
            // O primeiro a entrar (índice 0 -> dígito 0) é empurrado para a posição 19.
            esperado_k = sequencia_gerada[19 - k];
            obtido_k   = shadow_matrix[k*4 +: 4]; 
            
            if (obtido_k !== esperado_k) begin
                $display("[FALHA] posicao [%0d]: esperado=0x%X  obtido=0x%X", k, esperado_k, obtido_k);
                erros++;
            end else begin
                // Print de depuração para acompanhar o deslocamento com sucesso no terminal
                $display("[OK]    posicao [%02d]: esperado=0x%X  obtido=0x%X | Shifter OK!", k, esperado_k, obtido_k);
            end
        end
        
        if (erros == 0)
            $display("[SUCESSO] Shifter sequencial de 20 posições validado com perfeição!");
        else
            $display("[FALHA] O Shifter apresentou %0d erros nas 20 posicoes sequenciais.", erros);


        // --- Teste do 21º Dígito (Estouro do Shifter) ---
        // Vamos usar o dígito '5' para testar o empurrão extra
        digito_atual = 4'd5;
        sequencia_gerada[20] = digito_atual;
        coords_atuais = get_coords(digito_atual);
        $display("\n[C2] Inserindo o 21o digito (%0d) — verificando descarte do mais antigo...", digito_atual);
        
        while (lin_matriz !== coords_atuais[7:4]) @(posedge clk);
        col_matriz = coords_atuais[3:0];
        
        repeat(110) @(posedge clk);
        shadow_matrix = digitos_value; // Captura com o 21º elemento inserido

        col_matriz = 4'b1111;
        repeat(15) @(posedge clk);

        // Verificação pós-estouro:
        // Posição 0 deve conter o 5 (índice 20).
        // O primeiro '0' digitado lá no início (índice 0) deve ter sumido.
        $display("[C2] Verificando o barramento apos o 21o digito...");
        erros = 0;
        for (k = 0; k < 20; k++) begin
            esperado_k = sequencia_gerada[20 - k];
            obtido_k   = shadow_matrix[k*4 +: 4];
            
            if (obtido_k !== esperado_k) begin
                $display("[FALHA] Pos-Shift posicao [%0d]: esperado=0x%X  obtido=0x%X", k, esperado_k, obtido_k);
                erros++;
            end else begin
                // Print de depuração para acompanhar o estouro com sucesso no terminal
                $display("[OK]    Pos-Shift posicao [%02d]: esperado=0x%X  obtido=0x%X | Deslocado!", k, esperado_k, obtido_k);
            end
        end

        if (erros == 0)
            $display("[SUCESSO] 21o digito deslocou o barramento e descartou o valor antigo corretamente!");
        else
            $display("[FALHA] Erro no teste de descarte do 21o digito.");

        pressionar_asterisco();
        repeat(20) @(posedge clk);
    endtask

// ================================================================
    // CENARIO 3 — Debounce (Estágio Único Dinâmico com Rampa de Tempo)
    // O ruído varia livremente. A cada iteração, o teto máximo de persistência
    // da tecla aumenta de 5 em 5 ciclos. O teste roda continuamente até que
    // o sorteio ultrapasse 100 ciclos, disparando a leitura definitiva.
    // ================================================================
    task automatic teste_debounce;
        logic [3:0] tecla;
        logic [7:0] coords;
        logic [3:0] l, c;
        
        integer limite_max_press;
        integer ciclos_pressionado;
        integer ciclos_solto;
        integer tentativa;
        bit     tecla_estabilizada;

        $display("\n================================================");
        $display("=== CENARIO 3: DEBOUNCE - ESTAGIO UNICO DINAMICO ===");
        fazer_reset();

        // 1. Sorteia a tecla alvo e obtém as coordenadas
        tecla  = $urandom_range(1, 9);
        coords = get_coords(tecla);
        l      = coords[7:4];
        c      = coords[3:0];
        $display("[C3] Tecla alvo: %0d (LIN=%b, COL=%b)", tecla, l, c);
        
        // Inicializa as variáveis da rampa de ruído
        limite_max_press   = 10; // Começa permitindo ruídos de até 10 ciclos
        tentativa          = 0;
        tecla_estabilizada = 0;

        $display("[C3] Iniciando oscilacoes na coluna. Aguardando estabilizacao (>= 100 ciclos)...");

        // Loop único contínuo
        while (!tecla_estabilizada) begin
            tentativa++;
            
            // Incrementa o range de busca de 5 em 5 ciclos a cada iteração
            limite_max_press = limite_max_press + 5;

            // Sorteia o tempo que o ruído vai segurar a tecla nesta tentativa
            ciclos_pressionado = $urandom_range(5, limite_max_press);
            // Sorteia o tempo que ela fica solta (repouso)
            ciclos_solto       = $urandom_range(2, 15);

            // Aguarda a linha correta para sincronizar a aplicação do sinal
            while (lin_matriz !== l) @(posedge clk);

            // Injeta o clique (Coluna vai para nível baixo/ativo)
            col_matriz = c;

            // Condicional analítica: Se o sorteio alcançou a meta de leitura do DUT (>= 100)
            if (ciclos_pressionado >= 100) begin
                $display("\n[SUCESSO #%02d] Sinal assentou! Tecla ficou estavel por %0d ciclos.", tentativa, ciclos_pressionado);
                
                // Segura o tempo sorteado para o DUT validar
                repeat(ciclos_pressionado) @(posedge clk);
                
                // Força a saída do loop único
                tecla_estabilizada = 1;
            end else begin
                // Caso contrário, é apenas mais um ruído que decaiu antes da hora
                repeat(ciclos_pressionado) @(posedge clk);
                
                $display("  [ALERTA RUIDO #%02d] Coluna ativa por %0d clks, mas caiu antes dos 100 (Range max: %0d).", 
                         tentativa, ciclos_pressionado, limite_max_press);
            end

            // Solta a tecla (retorna para '1') e aguarda o tempo de release
            col_matriz = 4'b1111;
            repeat(ciclos_solto) @(posedge clk);
        end

        // Aguarda a FSM processar o término da operação e atualizar o visor
        repeat(20) @(posedge clk);

        // Validação final do barramento
        if (digitos_value.digits[0] === tecla)
            $display("\n[SUCESSO FINAL] Tecla %0d foi gravada no barramento apos vencer o debounce!", tecla);
        else
            $display("\n[FALHA] O sinal estabilizou mas o barramento contem: 0x%X (esperado: 0x%X)", digitos_value.digits[0], tecla);

        pressionar_asterisco();
        repeat(20) @(posedge clk);
    endtask

    // ================================================================
    // CENARIO 4 — Repeticao automatica da tecla (RANDOMICA E MONITORADA)
    // Escolhe uma tecla aleatoria de 0-9 e mantém pressionada para testar:
    // 1. O registro inicial após vencer o debounce (>19 ciclos).
    // 2. A primeira repetição automática após 2000 ciclos (2 segundos).
    // 3. A segunda repetição automática após mais 1000 ciclos (1 segundo).
    // ================================================================
    task automatic teste_repeticao_tecla;
        logic [3:0] tecla;
        logic [7:0] coords;
        logic [3:0] l, c;
        logic [79:0] shadow_matrix;

        $display("\n================================================");
        $display("=== CENARIO 4: REPETICAO AUTOMATICA DE TECLA ===");
        fazer_reset();

        // MODIFICAÇÃO: Sorteia uma tecla aleatória (de 1 a 9) a cada execução
        tecla  = $urandom_range(1, 9);
        coords = get_coords(tecla);
        l      = coords[7:4];
        c      = coords[3:0];
        
        $display("[C4] Tecla sorteada para teste de pressao longa: %0d (LIN=%b, COL=%b)", tecla, l, c);
        
        // Aguarda a linha correta para sincronismo máximo e inicia o pressionamento
        while (lin_matriz !== l) @(posedge clk);
        col_matriz = c; // Tecla pressionada AGORA

        // ------------------------------------------------------------
        // PASSO A: Vencer o Debounce Inicial
        // ------------------------------------------------------------
        repeat(50) @(posedge clk);
        shadow_matrix = digitos_value;
        $display("[C4 - T+50 clks] Verificando registro inicial (Debounce)...");
        if (shadow_matrix[3:0] === tecla) begin
            $display("    [OK] Tecla %0d registrada pela primeira vez com sucesso!", tecla);
        end else begin
            $display("    [ALERTA] Tecla ainda nao apareceu no barramento. Obtido: 0x%X", shadow_matrix[3:0]);
        end

        // ------------------------------------------------------------
        // PASSO B: Aguardar os 2000 ciclos da Primeira Repetição (2 segundos)
        // ------------------------------------------------------------
        $display("[C4] Mantendo pressionado... aguardando o timeout de 2000 clks para a 1a repeticao...");
        repeat(2000) @(posedge clk);
        
        shadow_matrix = digitos_value;
        $display("[C4 - T+2050 clks] Checando o barramento apos os primeiros 2 segundos...");
        if (shadow_matrix[3:0] === tecla && shadow_matrix[7:4] === tecla) begin
            $display("    [SUCESSO] 1a Repeticao Detectada! O digito duplicou: [0]=0x%X, [1]=0x%X", 
                     shadow_matrix[3:0], shadow_matrix[7:4]);
        end else begin
            $display("    [AVISO] A 1a repeticao nao aconteceu após 2s. Barramento: [0]=0x%X, [1]=0x%X", 
                     shadow_matrix[3:0], shadow_matrix[7:4]);
        end

        // ------------------------------------------------------------
        // PASSO C: Aguardar mais 1000 ciclos para a Segunda Repetição (1 segundo)
        // ------------------------------------------------------------
        $display("[C4] Mantendo pressionado... aguardando +1000 clks para a 2a repeticao (ritmo de 1s)...");
        repeat(1000) @(posedge clk);
        
        shadow_matrix = digitos_value;
        $display("[C4 - T+3050 clks] Checando o barramento apos mais 1 segundo...");
        if (shadow_matrix[3:0] === tecla && shadow_matrix[7:4] === tecla && shadow_matrix[11:8] === tecla) begin
            $display("    [SUCESSO FINAL] 2a Repeticao Detectada! O digito triplicou: [0]=0x%X, [1]=0x%X, [2]=0x%X", 
                     shadow_matrix[3:0], shadow_matrix[7:4], shadow_matrix[11:8]);
        end else begin
            $display("    [AVISO] A 2a repeticao falhou ou ritmo de 1s nao foi obedecido. Barramento: [0]=0x%X, [1]=0x%X, [2]=0x%X", 
                     shadow_matrix[3:0], shadow_matrix[7:4], shadow_matrix[11:8]);
        end

        // Finaliza o clique soltando a tecla
        col_matriz = 4'b1111;
        repeat(20) @(posedge clk);

        // ------------------------------------------------------------
        // Relatório Final do Cenário no Terminal
        // ------------------------------------------------------------
        $display("\n[C4] --- RELATORIO DE REPETICAO AUTOMATICA ---");
        if (digitos_value.digits[0] === tecla && digitos_value.digits[1] === tecla && digitos_value.digits[2] === tecla) begin
            $display("[STATUS SUCESSO] Maquina de estados obedeceu perfeitamente os tempos (Debounce -> 2s -> 1s)!");
        end else if (digitos_value.digits[0] === tecla && digitos_value.digits[1] === tecla) begin
            $display("[STATUS PARCIAL] Apenas uma repeticao ocorreu. Verifique se o loop contínuo de 1s está ativo.");
        end else if (digitos_value.digits[0] === tecla) begin
            $display("[STATUS LIMITADO] Tecla registrada apenas 1 vez. O circuito nao possui auto-repeat.");
        end else begin
            $display("[STATUS FALHA] A tecla sequer foi registrada no teste.");
        end

        pressionar_asterisco();
        repeat(20) @(posedge clk);
    endtask

// ================================================================
    // CENARIO 5 — Confirmacao com tecla * (SINCRONISMO DO CENARIO 2)
    // Sorteia N digitos aleatorios de 0-9, mas usa o sincronismo estrito
    // de linha/coluna do Cenario 2 para garantir que o Shifter desloque
    // os 5 numeros perfeitamente antes da confirmacao com a tecla *.
    // ================================================================
    task automatic teste_confirmacao_asterisco;
        localparam integer N = 5;
        logic [3:0]  digitados [N];
        logic [3:0]  esperado_k;
        logic [3:0]  obtido_k;
        logic [79:0] barramento_plano; // "Foto" preventiva do barramento
        integer ciclos;
        integer erros_dados;
        integer ok_timing, ok_dados;
        integer k;
        logic [3:0]  digito_atual;
        logic [7:0]  coords_atuais;

        $display("\n================================================");
        $display("=== CENARIO 5: CONFIRMACAO COM * (CONFIABILIDADE DO C2) ===");
        fazer_reset();

        // 1. Inserção Aleatória com Sincronismo do Cenário 2
        $display("[C5] Digitando %0d teclas aleatorias com alinhamento de linha...", N);
        for (int i = 0; i < N; i++) begin
            // Sorteia um dígito de 0 a 9 usando o motor sincronizado do SV
            digito_atual = $urandom_range(0, 9);
            digitados[i] = digito_atual;
            coords_atuais = get_coords(digito_atual);

            // SINCRONISMO CRUCIAL (Herdado do C2): Aguarda a linha exata do dígito ser varrida pela FSM
            while (lin_matriz !== coords_atuais[7:4]) @(posedge clk);
            
            // Injeta a coluna correspondente no instante exato
            col_matriz = coords_atuais[3:0];

            // Mantém pressionado pelo tempo regulamentar do debounce (110 ciclos do C1/C2)
            repeat(110) @(posedge clk);
            
            // Solta a tecla e aguarda a FSM processar o release e voltar a varrer
            col_matriz = 4'b1111;
            repeat(15) @(posedge clk);

            if (`DEBUG) $display("  [C5] [%0d/%0d] Digitado: %0d | Registrado em digits[0]: %X", i+1, N, digito_atual, digitos_value.digits[0]);
        end

        // Aguarda uma folga segura para estabilização geral do hardware
        repeat(5) @(posedge clk);

        // ============================================================
        // CAPTURA DA FOTO: Dados 100% estáveis e deslocados no barramento
        // ============================================================
        $display("[C5] Tirando foto de seguranca do barramento antes de acionar o ENTER...");
        barramento_plano = digitos_value;

        $display("[DEBUG FOTO] Estado do barramento obtido no snapshot:");
        for (k = 0; k < N; k++) begin
            $display("  -> barramento_plano[%0d] contem: 0x%X", k, barramento_plano[k*4 +: 4]);
        end
        // ============================================================

        // 2. Pressiona * (ENTER) e monitora a latência de resposta
        $display("[C5] Pressionando * (ENTER) e medindo ciclos ate digitos_valid...");
        while (lin_matriz !== 4'b1110) @(posedge clk);
        col_matriz = 4'b0111;  // Injeta coordenada física da tecla *

        ciclos    = 0;
        ok_timing = 0;
        
        // Mede a latência ciclo a ciclo aguardando o sinal de válido subir
        while (!digitos_valid && ciclos < 200) begin
            @(posedge clk);
            ciclos++;
        end

        // Solta o ENTER de forma segura
        col_matriz = 4'b1111; 
        repeat(5) @(posedge clk);

        // Validação de Timing (Máximo 120 ciclos)
        if (digitos_valid || ciclos < 200) begin
            ok_timing = (ciclos <= 120);
            if (ok_timing)
                $display("[SUCESSO TEMPO] digitos_valid subiu em %0d ciclos! (Limite de 120 respeitado).", ciclos);
            else
                $display("[FALHA TEMPO]   digitos_valid demorou %0d ciclos para responder!", ciclos);
        end else begin
            $display("[FALHA CRITICA] Timeout: O sinal digitos_valid nao subiu após 200 ciclos.");
        end

        // 3. Checagem Rigorosa de Dados (Varredura do Shifter)
        $display("[C5] Verificando integridade e ordem dos dados com base na foto salva...");
        erros_dados = 0;
        
        for (k = 0; k < N; k++) begin
            // O último a entrar (índice N-1) fica na posição 0.
            // O primeiro a entrar (índice 0) é empurrado para a posição N-1.
            esperado_k = digitados[(N - 1) - k];
            obtido_k   = barramento_plano[k*4 +: 4];
            
            if (obtido_k !== esperado_k) begin
                $display("  [FALHA DADO] Posicao digits[%0d]: esperado=0x%X | obtido=0x%X", k, esperado_k, obtido_k);
                erros_dados++;
            end else begin
                $display("  [OK DADO]    Posicao digits[%0d]: esperado=0x%X | obtido=0x%X", k, esperado_k, obtido_k);
            end
        end

        ok_dados = (erros_dados == 0);

        // 4. Veredito Final do Cenário
        $display("------------------------------------------------");
        if (ok_dados && ok_timing)
            $display("[CENARIO 5] RESULTADO: PASSOU! (Sincronismo perfeito do C2, dados integros e resposta rapida).");
        else
            $display("[CENARIO 5] RESULTADO: FALHOU! (Dados=%0s, Timing=%0s).",
                     ok_dados ? "OK" : "ERRO", ok_timing ? "OK" : "ERRO");

        repeat(30) @(posedge clk);
    endtask

    // ================================================================
    // Bloco principal
    // ================================================================
    integer seed;
    logic [31:0] dummy_rand; // Variável temporária para inicializar a semente

    initial begin
        if (!$value$plusargs("seed=%d", seed))
            seed = 42;
        
        // 1. Sincroniza o motor do Verilog clássico ($random)
        void'($random(seed)); 
        
        // 2. Sincroniza o motor do SystemVerilog ($urandom e $urandom_range) no Icarus
        dummy_rand = $urandom(seed); 

        $display("=== SEMENTE ALEATORIA ATIVADA: %0d ===", seed);

        $dumpfile("teste_teclado.vcd");
        $dumpvars(0, tb_teclado);

        // ------ Cenario 1: Decodificacao do teclado ------
        $display("\n================================================");
        $display("=== CENARIO 1: DECODIFICACAO DO TECLADO ===");
        $display("=== Meta: 5 hits por digito (0-9) ===");
        foreach (hit_count[i]) hit_count[i] = 0;

        while (!cobertura_completa()) begin
            $display("\n------------------------------------------------");
            teste_decodificar_teclado();
            exibir_cobertura();
            repeat(50) @(posedge clk);
        end

        $display("\n=== CENARIO 1: COBERTURA COMPLETA! ===");
        exibir_cobertura();

        // ------ Cenario 2: Shift do barramento ------
        teste_shift_barramento();

        // ------ Cenario 3: Debounce ------
        teste_debounce();

        // ------ Cenario 4: Repeticao automatica ------
        teste_repeticao_tecla();

        // ------ Cenario 5: Confirmacao com * ------
        teste_confirmacao_asterisco();

        $display("\n================================================");
        $display("=== FIM DA SIMULACAO ===");
        repeat(10) @(posedge clk);
        $finish;
    end

endmodule
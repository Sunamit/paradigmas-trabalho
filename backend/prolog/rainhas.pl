/*  rainhas.pl: Rainhas Minadas, um remix de N-rainhas com Campo Minado.

    REGRAS DO JOGO
    Num tabuleiro N x N, coloque N rainhas de forma que:

        * cada linha tenha exatamente uma rainha;
        * cada coluna tenha exatamente uma rainha;
        * nenhuma rainha encoste em outra, nem na diagonal;
        * (regra nossa) uma casa com numero nao tem rainha, e o numero diz
          quantas rainhas existem nas 8 casas ao redor dela, como no
          Campo Minado.

    REPRESENTAÇÃO
    Puzzle: lista de N linhas com N inteiros. -1 é casa sem pista; de 0 a 8
    é uma pista.

        [[-1,-1, 1,-1],
         [ 2,-1,-1,-1],
         ...]

    Solução: lista de N linhas com N inteiros, 1 onde há rainha e 0 onde
    não há. Cada casa da solução é uma variável de domínio 0..1 no CLP(FD),
    e cada regra acima vira uma restrição de SOMA sobre essas variáveis.

    COMO TESTAR NO TERMINAL
    -----------------------
        $ swipl backend/prolog/rainhas.pl
        ?- example_puzzle(P), solve(P, S), print_solution(S).
        ?- generate(medium, P), print_puzzle(P).
*/

:- module(rainhas,
          [ solve/2,             % +Puzzle, -Solution
            count_solutions/3,   % +Puzzle, +Limit, -Count
            generate/2,          % +Difficulty, -Puzzle
            hint/3,              % +Puzzle, +Board, -Result
            example_puzzle/1,    % -Puzzle
            print_puzzle/1,      % +Puzzle
            print_solution/1     % +Solution
          ]).

:- use_module(library(clpfd)).
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(random)).
:- use_module(library(solution_sequences)).

%   Valor usado no puzzle para "casa sem pista".
no_clue(-1).



%!  board_constraints(+N, ?Queens) is det.
%
%   Queens é uma grade N x N de variáveis 0..1 que obedece às três regras
%   das rainhas: uma por linha, uma por coluna e nenhuma encostada em outra.
%   Não olha as pistas; isso fica em clue_constraints/2.
board_constraints(N, Queens) :-
    length(Queens, N),
    % Toda linha tem N casas. Cuidado: um lambda como
    % [Row] >> length(Row, N) NÃO funcionaria aqui, porque o yall copia a
    % variável N como se fosse livre, e length/2 passaria a gerar listas de
    % todos os tamanhos, sem parar.
    maplist(same_length(Queens), Queens),
    append(Queens, Cells),
    Cells ins 0..1,

    % Uma rainha por linha: a soma dos 0/1 da linha é 1.
    maplist(exactly_one, Queens),

    % Uma rainha por coluna: mesma restrição sobre a grade transposta.
    transpose(Queens, Columns),
    maplist(exactly_one, Columns),

    % Nenhuma rainha encostada: em todo quadrado 2x2 há no maximo uma.
    % Duas casas vizinhas (inclusive na diagonal) sempre dividem algum
    % quadrado 2x2, então esta regra cobre todos os casos de contato.
    no_touching(Queens).

%   exactly_one(?Cells): exatamente uma das casas 0/1 vale 1.
exactly_one(Cells) :-
    sum(Cells, #=, 1).

%!  no_touching(?Rows) is det.
%
%   Percorre as linhas de duas em duas (1 e 2, 2 e 3, ...) por recursão.
no_touching([_]).
no_touching([Upper, Lower | Rest]) :-
    squares(Upper, Lower),
    no_touching([Lower | Rest]).

%   squares(?Upper, ?Lower): os quadrados 2x2 formados por duas linhas
%   vizinhas, deslizando uma coluna por vez.
squares([_], [_]).
squares([A, B | As], [C, D | Cs]) :-
    A + B + C + D #=< 1,
    squares([B | As], [D | Cs]).

%!  clue_constraints(+Puzzle, ?Queens) is det.
%
%   Para cada pista K na posição (R, C): a casa não tem rainha, e a soma
%   das casas vizinhas é K.
clue_constraints(Puzzle, Queens) :-
    findall(R-C-K, clue_at(Puzzle, R, C, K), Clues),
    maplist(clue_constraint(Queens), Clues).

%   clue_at(+Puzzle, -R, -C, -K): enumera, por backtracking, as pistas.
clue_at(Puzzle, R, C, K) :-
    no_clue(None),
    nth0(R, Puzzle, Row),
    nth0(C, Row, K),
    K =\= None.

clue_constraint(Queens, R-C-K) :-
    cell_at(Queens, R-C, Self),
    Self #= 0,
    neighbors(Queens, R-C, Around),
    sum(Around, #=, K).

%!  neighbors(+Grid, +R-C, -Vars) is det.
%
%   As variáveis das até 8 casas vizinhas de (R, C).
%   Atenção: findall/3 COPIA as variáveis do resultado, então não dá para
%   coletar as variáveis da grade direto com ele. Coletamos só as POSIÇÕES
%   (números) e depois buscamos as variáveis com maplist/3.
neighbors(Grid, R-C, Vars) :-
    length(Grid, N),
    Max is N - 1,
    findall(R1-C1,
            ( member(DR, [-1, 0, 1]),
              member(DC, [-1, 0, 1]),
              DR-DC \== 0-0,
              R1 is R + DR, between(0, Max, R1),
              C1 is C + DC, between(0, Max, C1) ),
            Positions),
    maplist(cell_at(Grid), Positions, Vars).

%   cell_at(+Grid, +R-C, -Value): o valor (ou variável) na posição (R, C).
cell_at(Grid, R-C, Value) :-
    nth0(R, Grid, Row),
    nth0(C, Row, Value).

%!  puzzle_constraints(+Puzzle, -Queens) is det.
%
%   Todas as regras juntas: as das rainhas e as das pistas.
puzzle_constraints(Puzzle, Queens) :-
    length(Puzzle, N),
    board_constraints(N, Queens),
    clue_constraints(Puzzle, Queens).


/* =========================================================================
   2. RESOLVER
   ========================================================================= */

%!  solve(+Puzzle, -Solution) is semidet.
%
%   Solution é uma solução de Puzzle (grade de 0/1). Falha se não houver.
solve(Puzzle, Solution) :-
    puzzle_constraints(Puzzle, Solution),
    append(Solution, Cells),
    labeling([ff], Cells),
    !.

%!  count_solutions(+Puzzle, +Limit, -Count) is det.
%
%   Quantas soluções Puzzle tem, contando no máximo até Limit.
count_solutions(Puzzle, Limit, Count) :-
    findall(x,
            limit(Limit, ( puzzle_constraints(Puzzle, Queens),
                           append(Queens, Cells),
                           labeling([ff], Cells) )),
            Found),
    length(Found, Count).

unique_solution(Puzzle) :-
    count_solutions(Puzzle, 2, 1).


/* =========================================================================
   3. GERADOR
   =========================================================================

   (a) Sorteia uma posição válida das N rainhas, sem pistas.
   (b) Vai revelando pistas em casas sem rainha, em ordem aleatória, até o
       puzzle ter solução única. Isso sempre termina: com todas as casas
       vazias reveladas, só sobram as casas das rainhas.
   (c) Tenta esconder cada pista revelada; se o puzzle continua com solução
       única, a pista era desnecessária e sai. Assim o puzzle fica enxuto.
*/

%!  difficulty_size(?Difficulty, ?N) is nondet.
%
%   Fatos: o tamanho do tabuleiro em cada nível.
difficulty_size(easy,   6).
difficulty_size(medium, 7).
difficulty_size(hard,   8).

%!  generate(+Difficulty, -Puzzle) is det.
generate(Difficulty, Puzzle) :-
    must_be(oneof([easy, medium, hard]), Difficulty),
    difficulty_size(Difficulty, N),
    random_solution(N, Solution),
    empty_puzzle(N, Empty),
    findall(R-C, cell_at(Solution, R-C, 0), Free),
    random_permutation(Free, Order),
    reveal_until_unique(Order, Solution, Empty, Revealed, Used),
    hide_redundant(Used, Revealed, Puzzle),
    !.

%!  random_solution(+N, -Solution) is det.
random_solution(N, Solution) :-
    board_constraints(N, Solution),
    append(Solution, Cells),
    random_labeling(Cells),
    !.

%   random_labeling(+Vars): como label/1, mas tenta 0 e 1 em ordem
%   aleatória. member/2 é o ponto de escolha para o backtracking.
random_labeling([]).
random_labeling([Var | Vars]) :-
    (   integer(Var)
    ->  true
    ;   random_permutation([0, 1], Values),
        member(Var, Values)
    ),
    random_labeling(Vars).

%   empty_puzzle(+N, -Puzzle): grade N x N só com "sem pista".
empty_puzzle(N, Puzzle) :-
    no_clue(None),
    length(Row, N),
    maplist(=(None), Row),
    length(Puzzle, N),
    maplist(=(Row), Puzzle).

%!  reveal_until_unique(+Order, +Solution, +Puzzle0, -Puzzle, -Used) is det.
%
%   Revela as pistas das posições em Order até a solução ficar única.
%   Used guarda as posições reveladas, para a etapa (c).
reveal_until_unique(_, _, Puzzle, Puzzle, []) :-
    unique_solution(Puzzle),
    !.
reveal_until_unique([Pos | Rest], Solution, Puzzle0, Puzzle, [Pos | Used]) :-
    neighbors(Solution, Pos, Around),
    sum_list(Around, K),
    set_cell(Puzzle0, Pos, K, Puzzle1),
    reveal_until_unique(Rest, Solution, Puzzle1, Puzzle, Used).

%!  hide_redundant(+Positions, +Puzzle0, -Puzzle) is det.
hide_redundant([], Puzzle, Puzzle).
hide_redundant([Pos | Rest], Puzzle0, Puzzle) :-
    no_clue(None),
    set_cell(Puzzle0, Pos, None, Candidate),
    (   unique_solution(Candidate)
    ->  Next = Candidate          % a pista era desnecessária
    ;   Next = Puzzle0            % a pista é necessária: fica
    ),
    hide_redundant(Rest, Next, Puzzle).

%   set_cell(+Grid, +R-C, +Value, -NewGrid): Grid com (R, C) trocada.
%   Nada é alterado no lugar: NewGrid é uma lista nova.
set_cell(Grid, R-C, Value, NewGrid) :-
    nth0(R, Grid, Row, OtherRows),
    nth0(C, Row, _, OtherCells),
    nth0(C, NewRow, Value, OtherCells),
    nth0(R, NewGrid, NewRow, OtherRows).


/* =========================================================================
   4. DICA
   ========================================================================= */

%!  hint(+Puzzle, +Board, -Result) is det.
%
%   Board é a grade de 0/1 com as rainhas que o jogador já colocou.
%   Result é:
%
%       [Row, Col]   uma casa onde vai uma rainha que o jogador ainda não
%                    colocou, escolhida ao acaso;
%       complete     todas as rainhas já estão no lugar certo;
%       unsolvable   as rainhas do jogador não cabem em nenhuma solução.
%
%   As rainhas do jogador entram como restrições extras: cada casa marcada
%   com 1 em Board é fixada em 1 na solução.
hint(Puzzle, Board, Result) :-
    (   puzzle_constraints(Puzzle, Solution),
        maplist(maplist(keep_queen), Board, Solution),
        append(Solution, Cells),
        labeling([ff], Cells)
    ->  findall(R-C,
                ( cell_at(Solution, R-C, 1),
                  cell_at(Board, R-C, 0) ),
                Missing),
        (   Missing == []
        ->  Result = complete
        ;   random_member(Row-Col, Missing),
            Result = [Row, Col]
        )
    ;   Result = unsolvable
    ).

%   keep_queen(+Placed, ?Var): se o jogador pôs rainha, a variável é 1.
keep_queen(1, 1) :- !.
keep_queen(0, _).


/* =========================================================================
   5. UTILITÁRIOS PARA USO NO TERMINAL
   ========================================================================= */

%   Um puzzle 6x6 com solução única, gerado por generate(easy, P).
%   Solução: rainhas nas colunas 0, 2, 4, 1, 5, 3 (linha a linha).
example_puzzle([[-1,-1,-1,-1, 0,-1],
                [-1,-1,-1,-1,-1,-1],
                [ 1,-1,-1,-1,-1,-1],
                [-1,-1,-1,-1,-1,-1],
                [-1, 1,-1, 1,-1,-1],
                [-1,-1,-1,-1,-1,-1]]).

print_puzzle(Puzzle) :-
    forall(member(Row, Puzzle),
           ( maplist(format_clue, Row), nl )).

format_clue(-1) :- !, write(' .').
format_clue(K)  :- format(' ~w', [K]).

print_solution(Solution) :-
    forall(member(Row, Solution),
           ( maplist(format_queen, Row), nl )).

format_queen(1) :- !, write(' Q').
format_queen(0) :- write(' .').
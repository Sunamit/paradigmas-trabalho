/*  test_rainhas.pl: Testes unitários do Rainhas Minadas com plunit.

    Para rodar:
        $ swipl -g run_tests -t halt backend/prolog/test_rainhas.pl
*/

:- use_module(rainhas).
:- use_module(library(plunit)).
:- use_module(library(lists)).
:- use_module(library(apply)).

%   A solução do example_puzzle/1, para comparar nos testes.
example_solution([[1,0,0,0,0,0],
                  [0,0,1,0,0,0],
                  [0,0,0,0,1,0],
                  [0,1,0,0,0,0],
                  [0,0,0,0,0,1],
                  [0,0,0,1,0,0]]).

:- begin_tests(solve).

test(example_puzzle, true(S == Expected)) :-
    example_puzzle(P),
    example_solution(Expected),
    solve(P, S).

test(example_is_unique, true(N == 1)) :-
    example_puzzle(P),
    count_solutions(P, 2, N).

test(clue_cell_has_no_queen) :-
    % Em toda casa com pista (valor diferente de -1), a solução tem 0.
    example_puzzle(P),
    solve(P, S),
    append(P, FlatP),
    append(S, FlatS),
    forall(nth0(I, FlatP, Clue),
           ( Clue =:= -1 -> true ; nth0(I, FlatS, 0) )).

test(impossible_clue, fail) :-
    % Uma casa de canto tem só 3 vizinhas: a pista 4 é impossível.
    P = [[ 4,-1,-1,-1],
         [-1,-1,-1,-1],
         [-1,-1,-1,-1],
         [-1,-1,-1,-1]],
    solve(P, _).

test(no_board_for_size_3, fail) :-
    % Não existe jeito de pôr 3 rainhas sem encostar num 3x3.
    P = [[-1,-1,-1], [-1,-1,-1], [-1,-1,-1]],
    solve(P, _).

:- end_tests(solve).

:- begin_tests(generate).

test(unique_in_every_level, [forall(member(D, [easy, medium, hard]))]) :-
    generate(D, P),
    count_solutions(P, 2, 1).

test(size_by_level, [forall(member(D-N, [easy-6, medium-7, hard-8]))]) :-
    generate(D, P),
    length(P, N).

test(bad_level, error(type_error(_, _))) :-
    generate(impossible, _).

:- end_tests(generate).

:- begin_tests(hint).

empty_board(N, Board) :-
    length(Row, N),
    maplist(=(0), Row),
    length(Board, N),
    maplist(=(Row), Board).

test(hint_is_a_solution_queen) :-
    example_puzzle(P),
    example_solution(S),
    empty_board(6, B),
    hint(P, B, [R, C]),
    nth0(R, S, Row),
    nth0(C, Row, 1).

test(complete, true(Result == complete)) :-
    example_puzzle(P),
    example_solution(S),
    hint(P, S, Result).

test(wrong_queen, true(Result == unsolvable)) :-
    % Uma rainha na casa (0,1), que não faz parte da solução.
    example_puzzle(P),
    empty_board(6, B0),
    B0 = [_ | Rest],
    B = [[0,1,0,0,0,0] | Rest],
    hint(P, B, Result).

:- end_tests(hint).
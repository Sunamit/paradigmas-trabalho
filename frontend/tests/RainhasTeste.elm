module RainhasTest exposing (suite)

{-| Testes do domínio puro (`Rainhas.elm`).

Como `Rainhas` não faz HTTP nem HTML, dá para testá-lo sem navegador e sem
servidor: damos um tabuleiro, chamamos a função e comparamos o resultado.

Os tabuleiros dos testes são 4x4 para ficarem fáceis de conferir à mão.

-}

import Dict
import Expect
import Rainhas
    exposing
        ( Board
        , Cell(..)
        , Origin(..)
        , Position
        , cellAt
        , clear
        , conflicts
        , cycle
        , fromPuzzle
        , isComplete
        , placeQueen
        , positions
        , queenCount
        , queensAround
        , revealSolution
        , toPuzzle
        , toQueens
        )
import Set
import Test exposing (Test, describe, test)



-- AUXILIARES


{-| Tabuleiro 4x4 só com as pistas dadas (posição, número).
-}
withClues : List ( Position, Int ) -> Board
withClues clues =
    let
        lookup =
            Dict.fromList clues

        clueAt row col =
            Dict.get ( row, col ) lookup |> Maybe.withDefault -1
    in
    List.range 0 3
        |> List.map (\row -> List.map (clueAt row) (List.range 0 3))
        |> fromPuzzle


blank : Board
blank =
    withClues []


{-| Põe uma rainha do jogador em cada posição da lista.
-}
withQueens : List Position -> Board -> Board
withQueens queenPositions board =
    List.foldl (placeQueen Player) board queenPositions


{-| Todas as casas na ordem de leitura. Comparar listas é mais simples e
seguro do que comparar `Array` ou `Set` diretamente.
-}
cellsOf : Board -> List Cell
cellsOf board =
    List.map (\position -> cellAt position board) (positions board)


{-| As posições em conflito, em ordem (`Set.toList` já devolve ordenado).
-}
conflictList : Board -> List Position
conflictList board =
    Set.toList (conflicts board)


{-| A solução das 4 rainhas: uma por linha e por coluna, sem encostar.

    . Q . .
    . . . Q
    Q . . .
    . . Q .

-}
solution : List Position
solution =
    [ ( 0, 1 ), ( 1, 3 ), ( 2, 0 ), ( 3, 2 ) ]



-- TESTES


suite : Test
suite =
    describe "Rainhas"
        [ conversionTests
        , cycleTests
        , queensAroundTests
        , conflictsTests
        , isCompleteTests
        , revealSolutionTests
        , clearTests
        ]


conversionTests : Test
conversionTests =
    describe "fromPuzzle, toPuzzle e toQueens"
        [ test "fromPuzzle lê o tamanho do lado" <|
            \_ ->
                Expect.equal 4 (fromPuzzle (List.repeat 4 (List.repeat 4 -1))).size
        , test "-1 vira casa vazia e 0 a 8 vira pista" <|
            \_ ->
                let
                    board =
                        withClues [ ( ( 0, 1 ), 2 ), ( ( 3, 3 ), 0 ) ]
                in
                Expect.equal
                    [ Empty, Clue 2, Clue 0 ]
                    [ cellAt ( 0, 0 ) board, cellAt ( 0, 1 ) board, cellAt ( 3, 3 ) board ]
        , test "toPuzzle devolve o puzzle original (ida e volta)" <|
            \_ ->
                let
                    puzzle =
                        [ [ -1, 2, -1, -1 ]
                        , [ -1, -1, -1, 1 ]
                        , [ 0, -1, -1, -1 ]
                        , [ -1, -1, 3, -1 ]
                        ]
                in
                Expect.equal puzzle (toPuzzle (fromPuzzle puzzle))
        , test "toPuzzle ignora as rainhas e as marcações" <|
            \_ ->
                let
                    board =
                        withClues [ ( ( 0, 0 ), 1 ) ]
                            |> withQueens [ ( 2, 2 ) ]
                            |> cycle ( 3, 3 )
                in
                Expect.equal
                    [ [ 1, -1, -1, -1 ]
                    , [ -1, -1, -1, -1 ]
                    , [ -1, -1, -1, -1 ]
                    , [ -1, -1, -1, -1 ]
                    ]
                    (toPuzzle board)
        , test "toQueens marca 1 onde há rainha e 0 no resto" <|
            \_ ->
                Expect.equal
                    [ [ 0, 1, 0, 0 ]
                    , [ 0, 0, 0, 1 ]
                    , [ 1, 0, 0, 0 ]
                    , [ 0, 0, 1, 0 ]
                    ]
                    (toQueens (withQueens solution blank))
        ]


cycleTests : Test
cycleTests =
    describe "cycle (o clique)"
        [ test "vazia -> X -> rainha do jogador -> vazia" <|
            \_ ->
                let
                    first =
                        cycle ( 1, 1 ) blank

                    second =
                        cycle ( 1, 1 ) first

                    third =
                        cycle ( 1, 1 ) second
                in
                Expect.equal
                    [ Cross, Queen Player, Empty ]
                    [ cellAt ( 1, 1 ) first, cellAt ( 1, 1 ) second, cellAt ( 1, 1 ) third ]
        , test "o clique numa pista não muda nada" <|
            \_ ->
                let
                    board =
                        withClues [ ( ( 0, 1 ), 2 ) ]
                in
                Expect.equal (cellsOf board) (cellsOf (cycle ( 0, 1 ) board))
        , test "o clique fora do tabuleiro não muda nada" <|
            \_ ->
                Expect.equal (cellsOf blank) (cellsOf (cycle ( 9, 9 ) blank))
        , test "o clique não altera o tabuleiro original (imutabilidade)" <|
            \_ ->
                let
                    after =
                        cycle ( 0, 0 ) blank
                in
                Expect.equal
                    ( Empty, Cross )
                    ( cellAt ( 0, 0 ) blank, cellAt ( 0, 0 ) after )
        , test "placeQueen não troca uma pista" <|
            \_ ->
                let
                    board =
                        withClues [ ( ( 2, 2 ), 1 ) ]
                in
                Expect.equal (Clue 1) (cellAt ( 2, 2 ) (placeQueen Player ( 2, 2 ) board))
        ]


queensAroundTests : Test
queensAroundTests =
    describe "queensAround"
        [ test "conta só as rainhas das 8 casas vizinhas" <|
            \_ ->
                -- (3, 3) está longe de (1, 1) e não conta.
                withQueens [ ( 0, 0 ), ( 2, 2 ), ( 3, 3 ) ] blank
                    |> queensAround ( 1, 1 )
                    |> Expect.equal 2
        , test "uma rainha não conta a si mesma" <|
            \_ ->
                withQueens [ ( 0, 0 ) ] blank
                    |> queensAround ( 0, 0 )
                    |> Expect.equal 0
        , test "no canto só existem 3 vizinhas" <|
            \_ ->
                withQueens [ ( 0, 1 ), ( 1, 0 ), ( 1, 1 ), ( 2, 2 ) ] blank
                    |> queensAround ( 0, 0 )
                    |> Expect.equal 3
        , test "a marcação X não conta como rainha" <|
            \_ ->
                cycle ( 0, 1 ) blank
                    |> queensAround ( 0, 0 )
                    |> Expect.equal 0
        ]


conflictsTests : Test
conflictsTests =
    describe "conflicts"
        [ test "tabuleiro vazio não tem conflitos" <|
            \_ ->
                Expect.equal [] (conflictList blank)
        , test "duas rainhas na mesma linha" <|
            \_ ->
                withQueens [ ( 0, 0 ), ( 0, 3 ) ] blank
                    |> conflictList
                    |> Expect.equal [ ( 0, 0 ), ( 0, 3 ) ]
        , test "duas rainhas na mesma coluna" <|
            \_ ->
                withQueens [ ( 0, 1 ), ( 3, 1 ) ] blank
                    |> conflictList
                    |> Expect.equal [ ( 0, 1 ), ( 3, 1 ) ]
        , test "duas rainhas encostadas na diagonal" <|
            \_ ->
                withQueens [ ( 1, 1 ), ( 2, 2 ) ] blank
                    |> conflictList
                    |> Expect.equal [ ( 1, 1 ), ( 2, 2 ) ]
        , test "diagonal à distância 2 NÃO é conflito (regra do jogo)" <|
            \_ ->
                withQueens [ ( 0, 0 ), ( 2, 2 ) ] blank
                    |> conflictList
                    |> Expect.equal []
        , test "movimento de cavalo NÃO é conflito" <|
            \_ ->
                withQueens [ ( 0, 0 ), ( 1, 2 ) ] blank
                    |> conflictList
                    |> Expect.equal []
        , test "a solução das 4 rainhas não tem conflitos" <|
            \_ ->
                withQueens solution blank
                    |> conflictList
                    |> Expect.equal []
        , test "só as rainhas em conflito ficam marcadas, não as vizinhas" <|
            \_ ->
                withQueens [ ( 0, 0 ), ( 0, 1 ), ( 3, 3 ) ] blank
                    |> conflictList
                    |> Expect.equal [ ( 0, 0 ), ( 0, 1 ) ]
        , test "pista com rainhas DEMAIS fica em conflito" <|
            \_ ->
                -- As rainhas (0, 0) e (2, 2) não se atacam; o erro é a pista 1.
                withClues [ ( ( 1, 1 ), 1 ) ]
                    |> withQueens [ ( 0, 0 ), ( 2, 2 ) ]
                    |> conflictList
                    |> Expect.equal [ ( 1, 1 ) ]
        , test "pista com rainhas de MENOS não é conflito" <|
            \_ ->
                withClues [ ( ( 1, 1 ), 2 ) ]
                    |> withQueens [ ( 0, 0 ) ]
                    |> conflictList
                    |> Expect.equal []
        , test "pista com o número exato não é conflito" <|
            \_ ->
                withClues [ ( ( 1, 1 ), 1 ) ]
                    |> withQueens [ ( 0, 0 ) ]
                    |> conflictList
                    |> Expect.equal []
        ]


isCompleteTests : Test
isCompleteTests =
    describe "isComplete"
        [ test "a solução completa, sem pistas, termina o jogo" <|
            \_ ->
                Expect.equal True (isComplete (withQueens solution blank))
        , test "faltando uma rainha, o jogo não terminou" <|
            \_ ->
                Expect.equal False (isComplete (withQueens (List.take 3 solution) blank))
        , test "tabuleiro vazio não está completo" <|
            \_ ->
                Expect.equal False (isComplete blank)
        , test "queenCount conta as rainhas" <|
            \_ ->
                Expect.equal 4 (queenCount (withQueens solution blank))
        , test "pista com o número exato mantém o jogo completo" <|
            \_ ->
                -- Ao redor de (1, 2) estão as rainhas (0, 1) e (1, 3).
                withClues [ ( ( 1, 2 ), 2 ) ]
                    |> withQueens solution
                    |> isComplete
                    |> Expect.equal True
        , test "pista com rainhas demais impede o fim" <|
            \_ ->
                withClues [ ( ( 1, 2 ), 1 ) ]
                    |> withQueens solution
                    |> isComplete
                    |> Expect.equal False
        , test "pista com rainhas de menos impede o fim (sem ser conflito)" <|
            \_ ->
                let
                    board =
                        withClues [ ( ( 1, 2 ), 3 ) ]
                            |> withQueens solution
                in
                Expect.equal ( [], False ) ( conflictList board, isComplete board )
        , test "rainhas em conflito impedem o fim, mesmo na quantidade certa" <|
            \_ ->
                withQueens [ ( 0, 0 ), ( 0, 1 ), ( 2, 2 ), ( 3, 3 ) ] blank
                    |> isComplete
                    |> Expect.equal False
        ]


revealSolutionTests : Test
revealSolutionTests =
    let
        answer =
            Set.fromList solution

        revealed =
            blank
                |> withQueens [ ( 0, 1 ), ( 3, 3 ) ]
                |> cycle ( 0, 3 )
                |> cycle ( 1, 3 )
                |> revealSolution answer
    in
    describe "revealSolution"
        [ test "mantém a rainha certa do jogador como dele" <|
            \_ ->
                Expect.equal (Queen Player) (cellAt ( 0, 1 ) revealed)
        , test "tira a rainha errada do jogador" <|
            \_ ->
                Expect.equal Empty (cellAt ( 3, 3 ) revealed)
        , test "põe as rainhas que faltam, como do Prolog" <|
            \_ ->
                Expect.equal
                    [ Queen Prolog, Queen Prolog ]
                    [ cellAt ( 2, 0 ) revealed, cellAt ( 3, 2 ) revealed ]
        , test "um X sobre a casa da solução vira rainha do Prolog" <|
            \_ ->
                Expect.equal (Queen Prolog) (cellAt ( 1, 3 ) revealed)
        , test "um X fora da solução continua X" <|
            \_ ->
                Expect.equal Cross (cellAt ( 0, 3 ) revealed)
        , test "as pistas nunca mudam" <|
            \_ ->
                let
                    board =
                        withClues [ ( ( 0, 0 ), 1 ) ]
                in
                Expect.equal (Clue 1) (cellAt ( 0, 0 ) (revealSolution answer board))
        , test "o resultado tem uma rainha por linha e termina o jogo" <|
            \_ ->
                Expect.equal True (isComplete (revealSolution answer blank))
        ]


clearTests : Test
clearTests =
    describe "clear"
        [ test "apaga rainhas e X, mas mantém as pistas" <|
            \_ ->
                let
                    board =
                        withClues [ ( ( 0, 0 ), 1 ), ( ( 3, 3 ), 0 ) ]
                            |> withQueens [ ( 1, 2 ), ( 2, 1 ) ]
                            |> cycle ( 0, 3 )
                in
                Expect.equal
                    [ Clue 1
                    , Empty
                    , Empty
                    , Empty
                    , Empty
                    , Empty
                    , Empty
                    , Empty
                    , Empty
                    , Empty
                    , Empty
                    , Empty
                    , Empty
                    , Empty
                    , Empty
                    , Clue 0
                    ]
                    (cellsOf (clear board))
        ]

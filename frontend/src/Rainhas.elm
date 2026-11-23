module Rainhas exposing
    ( Board
    , Cell(..)
    , Origin(..)
    , Position
    , cellAt
    , clear
    , conflicts
    , cycle
    , empty
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

{-| Regras e representação do tabuleiro do Rainhas Minadas, do lado do Elm.

Este módulo é PURO: não faz HTTP e não sabe nada de HTML. São só dados e
funções sobre esses dados.

Quem resolve, gera puzzles e dá dicas é o Prolog. Aqui ficam só as
verificações que precisam ser instantâneas a cada clique, como marcar em
vermelho duas rainhas que se atacam.

-}

import Array exposing (Array)
import Set exposing (Set)



-- TIPOS


{-| Uma casa do tabuleiro. É EXATAMENTE uma das quatro alternativas.

Uma casa não pode ser "pista e rainha ao mesmo tempo": o tipo não deixa
representar esse estado, que as regras proíbem. Com dois `Bool` (`temRainha`
e `temPista`), esse estado inválido seria possível.

-}
type Cell
    = Clue Int -- pista do puzzle: quantas rainhas há ao redor (não muda)
    | Queen Origin -- rainha
    | Cross -- o jogador marcou que ali NÃO vai rainha
    | Empty


{-| Quem colocou a rainha. Mostramos de cores diferentes as rainhas do
jogador e as que o Prolog revelou (dica ou "resolver").
-}
type Origin
    = Player
    | Prolog


{-| Posição de uma casa: (linha, coluna), a partir de 0.
-}
type alias Position =
    ( Int, Int )


{-| O tabuleiro: o tamanho do lado (6, 7 ou 8) e as casas em um Array,
linha por linha. A casa (linha, coluna) fica no índice `linha * size + coluna`.
-}
type alias Board =
    { size : Int
    , cells : Array Cell
    }



-- CONSTRUÇÃO E CONVERSÃO


empty : Board
empty =
    { size = 6, cells = Array.repeat 36 Empty }


{-| Converte o puzzle da API (-1 = sem pista, 0 a 8 = pista) num tabuleiro.
-}
fromPuzzle : List (List Int) -> Board
fromPuzzle rows =
    { size = List.length rows
    , cells =
        rows
            |> List.concat
            |> List.map clueOrEmpty
            |> Array.fromList
    }


clueOrEmpty : Int -> Cell
clueOrEmpty n =
    if n < 0 then
        Empty

    else
        Clue n


{-| O caminho inverso, só com as pistas: é o que mandamos ao Prolog.
-}
toPuzzle : Board -> List (List Int)
toPuzzle board =
    toRows board
        (\cell ->
            case cell of
                Clue k ->
                    k

                _ ->
                    -1
        )


{-| As rainhas do tabuleiro como grade de 0/1, o formato da API.
-}
toQueens : Board -> List (List Int)
toQueens board =
    toRows board
        (\cell ->
            if isQueen cell then
                1

            else
                0
        )


{-| Converte o tabuleiro em linhas de inteiros. O segundo argumento é uma
FUNÇÃO que diz como cada casa vira número: `toPuzzle` e `toQueens` só
mudam essa função (função de ordem superior).
-}
toRows : Board -> (Cell -> Int) -> List (List Int)
toRows board encode =
    board.cells
        |> Array.toList
        |> List.map encode
        |> chunksOf board.size


{-| Quebra uma lista em pedaços de `n`, por recursão.
-}
chunksOf : Int -> List a -> List (List a)
chunksOf n list =
    if n <= 0 then
        []

    else
        case list of
            [] ->
                []

            _ ->
                List.take n list :: chunksOf n (List.drop n list)



-- CONSULTAS


isQueen : Cell -> Bool
isQueen cell =
    case cell of
        Queen _ ->
            True

        _ ->
            False


inside : Board -> Position -> Bool
inside board ( row, col ) =
    row >= 0 && row < board.size && col >= 0 && col < board.size


cellAt : Position -> Board -> Cell
cellAt (( row, col ) as position) board =
    if inside board position then
        Array.get (row * board.size + col) board.cells
            |> Maybe.withDefault Empty

    else
        Empty


{-| Todas as posições do tabuleiro, na ordem de leitura.
-}
positions : Board -> List Position
positions board =
    let
        range =
            List.range 0 (board.size - 1)
    in
    List.concatMap (\row -> List.map (\col -> ( row, col )) range) range


{-| As até 8 casas vizinhas de uma posição.
-}
neighbors : Board -> Position -> List Position
neighbors board ( row, col ) =
    [ ( -1, -1 ), ( -1, 0 ), ( -1, 1 ), ( 0, -1 ), ( 0, 1 ), ( 1, -1 ), ( 1, 0 ), ( 1, 1 ) ]
        |> List.map (\( dr, dc ) -> ( row + dr, col + dc ))
        |> List.filter (inside board)


queenPositions : Board -> List Position
queenPositions board =
    List.filter (\position -> isQueen (cellAt position board)) (positions board)


queenCount : Board -> Int
queenCount board =
    List.length (queenPositions board)


{-| Quantas rainhas há ao redor de uma casa. É o que uma pista conta.
-}
queensAround : Position -> Board -> Int
queensAround position board =
    neighbors board position
        |> List.filter (\other -> isQueen (cellAt other board))
        |> List.length


{-| Duas rainhas se atacam se estão na mesma linha, na mesma coluna, ou
encostadas (inclusive na diagonal).
-}
attack : Position -> Position -> Bool
attack (( r1, c1 ) as p1) (( r2, c2 ) as p2) =
    p1 /= p2 && (r1 == r2 || c1 == c2 || (abs (r1 - r2) <= 1 && abs (c1 - c2) <= 1))


{-| Posições que violam as regras: rainhas que atacam outra rainha, e
pistas com MAIS rainhas ao redor do que o número permite.

Uma pista com MENOS rainhas não é erro: o jogador pode não ter terminado.

-}
conflicts : Board -> Set Position
conflicts board =
    let
        queens =
            queenPositions board

        badQueens =
            List.filter (\queen -> List.any (attack queen) queens) queens

        badClues =
            List.filter (clueExceeded board) (positions board)
    in
    Set.fromList (badQueens ++ badClues)


clueExceeded : Board -> Position -> Bool
clueExceeded board position =
    case cellAt position board of
        Clue k ->
            queensAround position board > k

        _ ->
            False


clueSatisfied : Board -> Position -> Bool
clueSatisfied board position =
    case cellAt position board of
        Clue k ->
            queensAround position board == k

        _ ->
            True


{-| O jogo termina quando há uma rainha por linha, nenhum conflito e toda
pista tem exatamente o número certo de rainhas ao redor.
-}
isComplete : Board -> Bool
isComplete board =
    queenCount board
        == board.size
        && Set.isEmpty (conflicts board)
        && List.all (clueSatisfied board) (positions board)



-- ALTERAÇÕES
--
-- Nada é modificado no lugar: cada função devolve um tabuleiro NOVO.


{-| Troca uma casa, exceto se ela for uma pista (pistas não mudam).
-}
setCell : Position -> Cell -> Board -> Board
setCell (( row, col ) as position) cell board =
    case cellAt position board of
        Clue _ ->
            board

        _ ->
            if inside board position then
                { board | cells = Array.set (row * board.size + col) cell board.cells }

            else
                board


{-| O clique numa casa: vazia -> X -> rainha -> vazia.
-}
cycle : Position -> Board -> Board
cycle position board =
    case cellAt position board of
        Empty ->
            setCell position Cross board

        Cross ->
            setCell position (Queen Player) board

        Queen _ ->
            setCell position Empty board

        Clue _ ->
            board


placeQueen : Origin -> Position -> Board -> Board
placeQueen origin position board =
    setCell position (Queen origin) board


{-| Mostra a solução do Prolog: põe rainhas onde faltam e tira as erradas.
As rainhas certas do jogador continuam sendo dele.
-}
revealSolution : Set Position -> Board -> Board
revealSolution solution board =
    let
        reveal index cell =
            let
                position =
                    ( index // board.size, modBy board.size index )
            in
            case ( cell, Set.member position solution ) of
                ( Clue _, _ ) ->
                    cell

                ( Queen _, True ) ->
                    cell

                ( _, True ) ->
                    Queen Prolog

                ( Queen _, False ) ->
                    Empty

                ( _, False ) ->
                    cell
    in
    { board | cells = Array.indexedMap reveal board.cells }


{-| Apaga tudo o que não é pista: rainhas e X.
-}
clear : Board -> Board
clear board =
    { board
        | cells =
            Array.map
                (\cell ->
                    case cell of
                        Clue _ ->
                            cell

                        _ ->
                            Empty
                )
                board.cells
    }

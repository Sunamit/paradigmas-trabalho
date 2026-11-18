module Api exposing
    ( Difficulty(..)
    , difficultyLabel
    , generate
    , hint
    , solve
    )

{-| Comunicação com o backend (FastAPI + Prolog).

As funções deste módulo devolvem um `Cmd msg`: uma DESCRIÇÃO da requisição.
Quem a executa é o runtime do Elm; quando a resposta chega, ele chama o
`update` com a mensagem indicada. Assim todas as funções continuam puras.

-}

import Http
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode
import Rainhas exposing (Board, Position)
import Set exposing (Set)


type Difficulty
    = Easy
    | Medium
    | Hard


difficultyLabel : Difficulty -> String
difficultyLabel difficulty =
    case difficulty of
        Easy ->
            "Fácil"

        Medium ->
            "Médio"

        Hard ->
            "Difícil"


{-| Nome usado pela API (e pelo Prolog: os átomos easy/medium/hard).
-}
difficultyToString : Difficulty -> String
difficultyToString difficulty =
    case difficulty of
        Easy ->
            "easy"

        Medium ->
            "medium"

        Hard ->
            "hard"



-- REQUISIÇÕES


generate : Difficulty -> (Result String Board -> msg) -> Cmd msg
generate difficulty toMsg =
    Http.post
        { url = "/api/generate"
        , body =
            Http.jsonBody
                (Encode.object [ ( "difficulty", Encode.string (difficultyToString difficulty) ) ])
        , expect = expectJson toMsg puzzleDecoder
        }


{-| Manda só as pistas: os erros do jogador não atrapalham o Prolog.
A resposta vira o conjunto das posições das rainhas da solução.
-}
solve : Board -> (Result String (Set Position) -> msg) -> Cmd msg
solve board toMsg =
    Http.post
        { url = "/api/solve"
        , body = Http.jsonBody (Encode.object [ ( "puzzle", encodeGrid (Rainhas.toPuzzle board) ) ])
        , expect = expectJson toMsg solutionDecoder
        }


{-| Manda as pistas e as rainhas já colocadas; recebe a posição de uma
rainha que falta.
-}
hint : Board -> (Result String Position -> msg) -> Cmd msg
hint board toMsg =
    Http.post
        { url = "/api/hint"
        , body =
            Http.jsonBody
                (Encode.object
                    [ ( "puzzle", encodeGrid (Rainhas.toPuzzle board) )
                    , ( "queens", encodeGrid (Rainhas.toQueens board) )
                    ]
                )
        , expect = expectJson toMsg hintDecoder
        }



-- JSON


encodeGrid : List (List Int) -> Encode.Value
encodeGrid =
    Encode.list (Encode.list Encode.int)


gridDecoder : Decoder (List (List Int))
gridDecoder =
    Decode.list (Decode.list Decode.int)


{-| Lê `{"puzzle": [[...], ...]}`.
-}
puzzleDecoder : Decoder Board
puzzleDecoder =
    Decode.field "puzzle" gridDecoder
        |> Decode.map Rainhas.fromPuzzle


{-| Lê `{"queens": [[...], ...]}` e guarda só onde há 1.
-}
solutionDecoder : Decoder (Set Position)
solutionDecoder =
    Decode.field "queens" gridDecoder
        |> Decode.map queensOf


queensOf : List (List Int) -> Set Position
queensOf rows =
    rows
        |> List.indexedMap
            (\row cells ->
                List.indexedMap
                    (\col value ->
                        if value == 1 then
                            Just ( row, col )

                        else
                            Nothing
                    )
                    cells
            )
        |> List.concat
        |> List.filterMap identity
        |> Set.fromList


{-| Lê `{"row": 2, "col": 4}`. `Decode.map2` junta os dois campos com
`Tuple.pair`, que monta a tupla `( 2, 4 )`.
-}
hintDecoder : Decoder Position
hintDecoder =
    Decode.map2 Tuple.pair
        (Decode.field "row" Decode.int)
        (Decode.field "col" Decode.int)



-- TRATAMENTO DE ERROS
--
-- `Http.expectJson` descarta o corpo das respostas de erro (como o 422). O
-- backend manda uma mensagem útil em `{"detail": "..."}`, então lemos o
-- corpo e devolvemos sempre um `Result String a`.


expectJson : (Result String a -> msg) -> Decoder a -> Http.Expect msg
expectJson toMsg decoder =
    Http.expectStringResponse toMsg <|
        \response ->
            case response of
                Http.GoodStatus_ _ body ->
                    Decode.decodeString decoder body
                        |> Result.mapError (\_ -> "Resposta inesperada do servidor.")

                Http.BadStatus_ metadata body ->
                    Err (errorDetail metadata.statusCode body)

                Http.BadUrl_ url ->
                    Err ("URL inválida: " ++ url)

                Http.Timeout_ ->
                    Err "O servidor demorou demais para responder."

                Http.NetworkError_ ->
                    Err "Não foi possível falar com o servidor. O backend está rodando?"


errorDetail : Int -> String -> String
errorDetail status body =
    case Decode.decodeString (Decode.field "detail" Decode.string) body of
        Ok detail ->
            detail

        Err _ ->
            "Erro no servidor (código " ++ String.fromInt status ++ ")."
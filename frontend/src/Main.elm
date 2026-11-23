module Main exposing (main)

{-| Interface do Rainhas Minadas, na Arquitetura Elm:

- `Model`: o estado completo da aplicação, num único valor imutável.
- `Msg`: tudo o que pode acontecer (cliques, respostas HTTP, ticks do tempo...).
- `update`: recebe uma `Msg` e o `Model`, devolve o novo `Model` e os
    efeitos a executar.
- `view`: recebe o `Model` e devolve o `Html`.

-}

import Api exposing (Difficulty(..))
import Browser
import Html exposing (Html, aside, button, div, footer, h1, header, input, label, main_, span, text)
import Html.Attributes exposing (attribute, checked, class, classList, disabled, type_, value)
import Html.Events exposing (onCheck, onClick)
import Rainhas exposing (Board, Cell(..), Origin(..), Position)
import Set exposing (Set)
import Time



-- MAIN


main : Program Flags Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }


subscriptions : Model -> Sub Msg
subscriptions model =
    if not model.loading && not (Rainhas.isComplete model.board) then
        Time.every 1000 Tick

    else
        Sub.none



-- MODEL


{-| Dados que o main.js entrega ao Elm na inicialização.
-}
type alias Flags =
    { darkTheme : Bool
    }


type alias Model =
    { board : Board
    , difficulty : Difficulty
    , darkTheme : Bool
    , loading : Bool
    , error : Maybe String
    , seconds : Int
    }


init : Flags -> ( Model, Cmd Msg )
init flags =
    ( { board = Rainhas.empty
      , difficulty = Medium
      , darkTheme = flags.darkTheme
      , loading = True
      , error = Nothing
      , seconds = 0
      }
    , Api.generate Medium GotPuzzle
    )



-- UPDATE


{-| As mensagens `Got...` carregam um `Result`: quem as cria é o runtime do
Elm, quando a resposta HTTP chega. Cada uma traz o tipo exato que a
requisição devolve: um tabuleiro, uma posição ou um conjunto de posições.
-}
type Msg
    = NewGame Difficulty
    | GotPuzzle (Result String Board)
    | CellClicked Position
    | ThemeToggled Bool
    | HintRequested
    | GotHint (Result String Position)
    | SolveRequested
    | GotSolution (Result String (Set Position))
    | ResetRequested
    | ErrorDismissed
    | Tick Time.Posix


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NewGame difficulty ->
            ( { model | difficulty = difficulty, loading = True, error = Nothing, seconds = 0 }
            , Api.generate difficulty GotPuzzle
            )

        GotPuzzle (Ok board) ->
            ( { model | board = board, loading = False }, Cmd.none )

        GotPuzzle (Err error) ->
            ( failed error model, Cmd.none )

        CellClicked position ->
            ( { model | board = Rainhas.cycle position model.board, error = Nothing }
            , Cmd.none
            )

        ThemeToggled dark ->
            ( { model | darkTheme = dark }, Cmd.none )

        HintRequested ->
            ( { model | loading = True, error = Nothing }
            , Api.hint model.board GotHint
            )

        GotHint (Ok position) ->
            ( { model | board = Rainhas.placeQueen Prolog position model.board, loading = False }
            , Cmd.none
            )

        GotHint (Err error) ->
            ( failed error model, Cmd.none )

        SolveRequested ->
            ( { model | loading = True, error = Nothing }
            , Api.solve model.board GotSolution
            )

        GotSolution (Ok solution) ->
            ( { model | board = Rainhas.revealSolution solution model.board, loading = False }
            , Cmd.none
            )

        GotSolution (Err error) ->
            ( failed error model, Cmd.none )

        ResetRequested ->
            ( { model | board = Rainhas.clear model.board, error = Nothing, seconds = 0 }, Cmd.none )

        ErrorDismissed ->
            ( { model | error = Nothing }, Cmd.none )

        Tick _ ->
            ( { model | seconds = model.seconds + 1 }, Cmd.none )


failed : String -> Model -> Model
failed error model =
    { model | loading = False, error = Just error }



-- VIEW
--
-- As classes são semânticas ("board", "cell", "cell--guess"); a aparência
-- fica em src/style.css.


view : Model -> Html Msg
view model =
    div [ class "app" ]
        [ header [ class "app-header" ]
            [ div [ class "app-container app-header-content" ]
                [ h1 [ class "app-title" ] [ text "Rainhas Minadas" ]
                , span [ class "app-subtitle" ] [ text "Prolog + Elm" ]
                , viewThemeToggle model
                ]
            ]
        , main_ [ class "app-main" ]
            [ div [ class "app-container game" ]
                [ viewBoard model.board
                , aside [ class "side-panel" ]
                    [ span [ class "panel-label" ] [ text "Novo jogo" ]
                    , viewDifficulty model
                    , div [ class "message-area" ] [ viewMessages model ]
                    , span [ class "panel-label" ] [ text "Rainhas" ]
                    , viewQueenCounter model.board
                    , span [ class "panel-label" ] [ text "Tempo" ]
                    , viewTimer model.seconds
                    , span [ class "panel-label" ] [ text "Ajuda" ]
                    , viewActions model
                    ]
                ]
            ]
        , footer [ class "app-footer" ]
            [ text "Uma rainha por linha e por coluna, sem encostar em outra. "
            , text "O número diz quantas rainhas há nas 8 casas ao redor. "
            , text "Clique numa casa: vazia → ✕ → ♛ → vazia."
            ]
        ]


{-| Botão sol/lua: o `theme-controller` do daisyUI (veja style.css).
-}
viewThemeToggle : Model -> Html Msg
viewThemeToggle model =
    label [ class "theme-toggle", attribute "aria-label" "Alternar tema claro/escuro" ]
        [ input
            [ type_ "checkbox"
            , class "theme-controller"
            , value "dark"
            , checked model.darkTheme
            , onCheck ThemeToggled
            ]
            []
        , span [ class "swap-off" ] [ text "☀" ]
        , span [ class "swap-on" ] [ text "☾" ]
        ]


viewDifficulty : Model -> Html Msg
viewDifficulty model =
    let
        option difficulty =
            button
                [ class "difficulty-option"
                , classList [ ( "difficulty-option--active", difficulty == model.difficulty ) ]
                , disabled model.loading
                , onClick (NewGame difficulty)
                ]
                [ text (Api.difficultyLabel difficulty) ]
    in
    div [ class "difficulty-picker" ] (List.map option [ Easy, Medium, Hard ])


viewMessages : Model -> Html Msg
viewMessages model =
    case ( model.error, model.loading ) of
        ( Just error, _ ) ->
            div [ class "message message--error" ]
                [ span [] [ text error ]
                , button [ class "message-close", onClick ErrorDismissed ] [ text "✕" ]
                ]

        ( Nothing, True ) ->
            div [ class "message message--loading" ]
                [ span [ class "spinner" ] []
                , span [] [ text "O Prolog está pensando..." ]
                ]

        ( Nothing, False ) ->
            if Rainhas.isComplete model.board then
                div [ class "message message--success" ]
                    [ text (completionMessage model.board) ]

            else
                text ""


completionMessage : Board -> String
completionMessage board =
    let
        helped =
            Rainhas.positions board
                |> List.any (\position -> Rainhas.cellAt position board == Queen Prolog)
    in
    if helped then
        "Resolvido (com ajuda do Prolog)."

    else
        "Parabéns! Você achou todas as rainhas!"


viewQueenCounter : Board -> Html Msg
viewQueenCounter board =
    div [ class "queen-counter" ]
        [ text (String.fromInt (Rainhas.queenCount board) ++ " de " ++ String.fromInt board.size) ]


viewTimer : Int -> Html Msg
viewTimer totalSeconds =
    div [ class "queen-counter" ]
        [ text (formatTime totalSeconds) ]


formatTime : Int -> String
formatTime totalSeconds =
    let
        mins =
            totalSeconds // 60

        secs =
            remainderBy 60 totalSeconds

        pad n =
            String.padLeft 2 '0' (String.fromInt n)
    in
    pad mins ++ ":" ++ pad secs


{-| O tamanho do tabuleiro muda com o nível (6, 7 ou 8). O Elm passa o
tamanho ao CSS pela variável `--size`, e o CSS monta a grade.
-}
viewBoard : Board -> Html Msg
viewBoard board =
    let
        conflicts =
            Rainhas.conflicts board
    in
    div
        [ class "board"
        , classList [ ( "board--solved", Rainhas.isComplete board ) ]
        , attribute "style" ("--size: " ++ String.fromInt board.size)
        ]
        (List.map (viewCell board conflicts) (Rainhas.positions board))


viewCell : Board -> Set Position -> Position -> Html Msg
viewCell board conflicts (( row, col ) as position) =
    let
        cell =
            Rainhas.cellAt position board

        clueDone =
            case cell of
                Clue k ->
                    Rainhas.queensAround position board == k

                _ ->
                    False
    in
    button
        [ class "cell"
        , class (cellClass cell)
        , classList
            [ ( "cell--conflict", Set.member position conflicts )
            , ( "cell--clue-done", clueDone )
            ]
        , attribute "aria-label"
            ("Linha " ++ String.fromInt (row + 1) ++ ", coluna " ++ String.fromInt (col + 1))
        , onClick (CellClicked position)
        ]
        [ span [ class "cell-value" ] [ text (cellText cell) ] ]


{-| A classe de cada tipo de casa. O `case` é exaustivo: se um dia `Cell`
ganhar um construtor novo, o compilador aponta esta função.
-}
cellClass : Cell -> String
cellClass cell =
    case cell of
        Clue _ ->
            "cell--given"

        Queen Player ->
            "cell--guess"

        Queen Prolog ->
            "cell--revealed"

        Cross ->
            "cell--cross"

        Empty ->
            "cell--empty"


cellText : Cell -> String
cellText cell =
    case cell of
        Clue k ->
            String.fromInt k

        Queen _ ->
            "♛"

        Cross ->
            "✕"

        Empty ->
            ""


viewActions : Model -> Html Msg
viewActions model =
    let
        nothingToReveal =
            model.loading || Rainhas.isComplete model.board
    in
    div [ class "actions" ]
        [ button [ class "action-button action-button--hint", disabled nothingToReveal, onClick HintRequested ] [ text "Dica" ]
        , button [ class "action-button action-button--solve", disabled nothingToReveal, onClick SolveRequested ] [ text "Resolver" ]
        , button [ class "action-button action-button--reset", disabled model.loading, onClick ResetRequested ] [ text "Limpar" ]
        ]
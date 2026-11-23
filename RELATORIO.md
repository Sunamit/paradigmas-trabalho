# Rainhas Minadas

## 1. Identificação

| Nome completo | Matrícula | Turma (14h/16h) | Usuário GitHub |
|---------------|-----------|-----------------|----------------|
| Arthur Fonseca Vale | 221031120 | 14h | @arthurfonsecaa |
| Ana Carolina Madeira Fialho | 221031102 | 14h | @anawcarol |
| Sunamita Vitória Rodrigues dos Santos | 221008697 | 14h | @Sunamit |
| Pedro Paulo Santos Almeida | 221008688 | 14h | @Pedrin0030 |
| Isabelle da Costa Figueiredo | 211039500 | 14h | @isacostaf |

- **Nome do projeto:** Rainhas Minadas
- **Nome do grupo:** Rainhas Minadas
- **Repositório:** https://github.com/Sunamit/paradigmas-trabalho
- **Commit ou tag entregue:** [`a1b2c3d` ou `v1.0`]
  <!--
    O avaliador vai olhar exatamente esta versão. Para criar uma tag:
      git tag v1.0 && git push origin v1.0
  -->
- **Ponto de partida:** Remix original
- **Slides da apresentação oral:** [`docs/apresentacao.pdf` | link externo | não há]
  <!--
    No final do semestre, cada grupo faz uma apresentação oral de 15
    minutos. Slides são opcionais; se o grupo usar, coloque o arquivo no
    repositório (de preferência em PDF) e indique o caminho aqui.
  -->

## 2. Resumo

Rainhas Minadas é um jogo de raciocínio que mistura N-rainhas com Campo Minado. O jogador coloca N rainhas num tabuleiro N×N (6×6, 7×7 ou 8×8): uma por linha e por coluna, sem que duas se encostem, nem na diagonal. Casas com número não têm rainha, e o número indica quantas rainhas há nas 8 casas ao redor. Todo puzzle tem solução única.

O Prolog é o cérebro do sistema: cada regra do jogo vira uma restrição CLP(FD), e o mesmo código resolve o puzzle, gera puzzles com solução única e calcula dicas. O Elm cuida da interface e da verificação instantânea de conflitos.

![Captura de tela do sistema](docs\Screenshot_934.png)

## 3. Como executar

**Requisitos** (com as versões que o grupo usou):

- SWI-Prolog 10.0.2 (macOS) e 11.0.0 (Windows); a biblioteca janus exige 9.2 ou mais novo
- Node.js 24.15.0 (20 ou mais novo)
- uv 0.13.9 e Python 3.11 ou mais novo (o uv instala o Python sozinho)

No Windows, o `janus-swi` é compilado na instalação, então também são necessárias as Build Tools do C++ (carga de trabalho "Desenvolvimento para desktop com C++").

**Instalação e execução:**

```sh
git clone https://github.com/Sunamit/paradigmas-trabalho.git
cd paradigmas-trabalho
cd backend && uv sync && cd ..
cd frontend && npm install && cd ..
```

Em seguida, em **dois terminais**:

```sh
# terminal 1: backend (http://localhost:8000/docs)
cd backend
uv run fastapi dev app/main.py
```

```sh
# terminal 2: frontend (http://localhost:5173)
cd frontend
npm run dev
```

**Testes:**

```sh
make test
```

Sem `make` (Windows):

```sh
swipl -g run_tests -t halt backend/prolog/test_rainhas.pl
cd backend && uv run pytest 
```

**Testado em:** macOS + Chrome e Windows 11 + Chrome.

## 4. Arquitetura

```
┌────────────────────────┐             ┌─────────────────────┐         ┌────────────────────┐
│ Navegador              │             │ FastAPI (Python)    │         │ SWI-Prolog         │
│                        │             │                     │         │                    │
│ Elm                    │  HTTP/JSON  │ app/main.py         │  janus  │ rainhas.pl         │
│ Rainhas.elm (domínio)  │ ──────────▶ │ app/prolog.py       │ ──────▶ │ CLP(FD)            │
│ Api.elm (HTTP/JSON)    │ ◀────────── │                     │ ◀────── │ solve/2, generate/2│
│ Main.elm (interface)   │             │ só integração       │         │ hint/3             │
│                        │             │                     │         │                    │
└────────────────────────┘             └─────────────────────┘         └────────────────────┘
  porta 5173                           porta 8000                (roda dentro do Python)
```

| Parte  | Responsabilidade | Arquivos principais |
|--------|------------------|---------------------|
| Prolog | Regras do jogo, resolvedor, gerador de puzzles com solução única e dica | `backend/prolog/rainhas.pl` |
| Elm    | Interface, verificação instantânea de conflitos e estado do jogo | `frontend/src/Rainhas.elm`, `frontend/src/Api.elm`, `frontend/src/Main.elm` |
| Python | Só integração: recebe JSON, chama o Prolog e devolve JSON | `backend/app/prolog.py`, `backend/app/main.py` |

## 5. Parte em Prolog

### 5.1 Predicados principais

<!--
  Os predicados mais importantes, com o local no código. Use a notação
  nome/aridade e indique entradas (+) e saídas (-), como na documentação
  do SWI-Prolog.
-->

| Predicado | Local | O que faz |
|-----------|-------|-----------|
| [`resolver(+Entrada, -Saida)`] | [`arquivo.pl:42`] | [...] |
| [...] | [...] | [...] |

### 5.2 Conceitos do paradigma lógico utilizados

<!--
  Marque o que o projeto usa DE FATO e indique onde. Não é preciso usar
  tudo; é preciso explicar bem o que foi usado.
-->

- [ ] Fatos e regras como base de conhecimento: [onde]
- [ ] Unificação e casamento de padrões: [onde]
- [ ] Recursão (inclusive sobre listas): [onde]
- [ ] Backtracking e múltiplas soluções: [onde]
- [ ] `findall/3`, `bagof/3`, `setof/3` ou similares: [onde]
- [ ] Corte (`!`) ou negação (`\+`), e por que foram necessários: [onde]
- [ ] Programação por restrições (CLP(FD) ou outra): [onde]
- [ ] Predicados de ordem superior (`maplist`, `foldl`, `include`...): [onde]
- [ ] Outro: [...]

### 5.3 Trecho em destaque

<!--
  Escolha o trecho de Prolog de que o grupo mais se orgulha (ou o mais
  difícil). Cole o código e explique como ele funciona: o que é declarado,
  como o Prolog chega à resposta, e por que essa solução é "lógica" e não
  uma tradução de um algoritmo imperativo.
-->

```prolog
[trecho]
```

[Explicação.]

## 6. Parte em Elm

### 6.1 Modelo e mensagens

Domínio (`frontend/src/Rainhas.elm:48`, `:58` e `:72`):

```elm
type Cell
    = Clue Int -- pista do puzzle: quantas rainhas há ao redor (não muda)
    | Queen Origin -- rainha
    | Cross -- o jogador marcou que ali NÃO vai rainha
    | Empty

type Origin
    = Player
    | Prolog

type alias Board =
    { size : Int
    , cells : Array Cell
    }
```

Estado e eventos (`frontend/src/Main.elm:47` e `:76`):

```elm
type alias Model =
    { board : Board
    , difficulty : Difficulty
    , darkTheme : Bool
    , loading : Bool
    , error : Maybe String
    }

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
```

- **`Cell` é um custom type, e não dois `Bool`.** Com `temPista` e `temRainha`, uma casa poderia ser pista e rainha ao mesmo tempo, o que as regras proíbem. Com `Cell`, esse estado não pode ser escrito. `setCell` (`frontend/src/Rainhas.elm:302`) completa a garantia: nunca troca uma pista.
- **`Origin` fica dentro de `Queen`.** Só rainha tem origem, então uma casa vazia "colocada pelo Prolog" também não existe. A origem define a classe CSS (`frontend/src/Main.elm:313`) e a mensagem de fim de jogo (`frontend/src/Main.elm:245`).
- **`Difficulty` é um custom type, e não `String`** (`frontend/src/Api.elm:24`). Um nível com erro de digitação não compila; a conversão para texto fica só em `difficultyToString` (`frontend/src/Api.elm:45`).
- **`error : Maybe String`** representa a ausência de erro sem null nem texto vazio. Para mostrar a mensagem, `viewMessages` (`frontend/src/Main.elm:221`) precisa tratar também o caso `Nothing`.
- **As mensagens `Got...` carregam um `Result`** com o tipo exato de cada resposta: um tabuleiro, uma posição ou um conjunto de posições. O `update` é obrigado a tratar `Ok` e `Err`.
- **O que não está no `Model`:** conflitos, contagem de rainhas e vitória são calculados a partir do tabuleiro (`conflicts`, `queenCount`, `isComplete`). Assim não podem ficar desatualizados.

`loading` e `error` ainda são campos independentes, então o tipo permite os dois ativos ao mesmo tempo. O `update` evita isso na prática; um custom type para o estado da requisição impediria no próprio tipo.

### 6.2 Conceitos do paradigma funcional utilizados

- [x] Arquitetura Elm (Model, update, view): `Model` (`frontend/src/Main.elm:47`), `update` (`frontend/src/Main.elm:89`) e `view` (`frontend/src/Main.elm:156`).
- [x] Custom types e `case` exaustivo: `Cell` (`frontend/src/Rainhas.elm:48`), `cycle` (`frontend/src/Rainhas.elm:318`), o `case` sobre tupla de `revealSolution` (`frontend/src/Rainhas.elm:342`) e `cellClass` (`frontend/src/Main.elm:313`), que não tem `_`: um construtor novo em `Cell` faz o compilador apontar a função.
- [x] `Maybe` e `Result` no lugar de null e exceções: `error` no `Model` (`frontend/src/Main.elm:52`), `queensOf` com `List.filterMap` (`frontend/src/Api.elm:133`) e `expectJson`, que transforma todas as falhas HTTP em `Err` (`frontend/src/Api.elm:171`).
- [x] Funções de ordem superior e aplicação parcial: `toRows` recebe a função que converte cada casa (`frontend/src/Rainhas.elm:142`); `attack queen` e `clueExceeded board` são aplicações parciais (`frontend/src/Rainhas.elm:255` e `:258`), assim como `viewCell board conflicts` (`frontend/src/Main.elm:279`).
- [x] Composição (`|>`, `>>`): pipelines com `|>` em `fromPuzzle` (`frontend/src/Rainhas.elm:89`), `queensAround` (`frontend/src/Rainhas.elm:227`) e `queensOf` (`frontend/src/Api.elm:133`). Não usamos `>>`.
- [x] Decoders e encoders JSON: `encodeGrid` (`frontend/src/Api.elm:107`), `puzzleDecoder` (`frontend/src/Api.elm:119`), `solutionDecoder` (`frontend/src/Api.elm:127`) e `hintDecoder` com `Decode.map2` (`frontend/src/Api.elm:156`).
- [x] Comandos e subscriptions (efeitos controlados): só comandos. `generate`, `solve` e `hint` devolvem um `Cmd msg` (`frontend/src/Api.elm:62`, `:76` e `:88`). Não há subscriptions: usamos `Sub.none` (`frontend/src/Main.elm:32`).
- [x] Imutabilidade e atualização de records: `setCell` (`frontend/src/Rainhas.elm:302`) e `clear` (`frontend/src/Rainhas.elm:371`) devolvem um tabuleiro novo; todo o `update` cria um `Model` novo com a sintaxe `{ model | ... }`.
- [x] Outro: domínio puro isolado em módulo. `Rainhas.elm` não importa HTTP nem HTML, só `Array` e `Set` (`frontend/src/Rainhas.elm:33`), e não exporta auxiliares como `setCell` e `attack`.

### 6.3 Trecho em destaque

`conflicts` e `clueExceeded` (`frontend/src/Rainhas.elm:248` e `:263`) decidem quais casas ficam vermelhas a cada clique:

```elm
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
```

- **Descreve o resultado, sem laço nem variável alterada.** As rainhas em conflito são "as rainhas que atacam alguma rainha", e o código diz isso com `List.filter` e `List.any`.
- **Aplicação parcial.** `attack` recebe duas posições; `attack queen` já é uma função que espera a segunda, e é ela que `List.any` usa. `clueExceeded board` segue a mesma ideia.
- **A rainha não ataca a si mesma**, embora seja comparada com a lista inteira: `attack` exige `p1 /= p2` (`frontend/src/Rainhas.elm:239`).
- **Pista com rainhas de menos não é conflito**, porque o jogador pode não ter terminado. Por isso a comparação é `>`; a igualdade só é exigida na vitória, por `clueSatisfied` (`frontend/src/Rainhas.elm:273`).
- **`Set`** elimina repetições e combina com a única pergunta que a view faz: "esta casa está em conflito?" (`frontend/src/Main.elm:300`).

Essa verificação repete parte das regras do Prolog de propósito: assim a resposta ao clique não depende da rede. Resolver, gerar e dar dicas continuam só no Prolog.

## 7. Integração

O Elm envia JSON para `/api`, o Vite repassa ao FastAPI (`frontend/vite.config.js:13`) e o Python chama o Prolog pela biblioteca janus (`backend/app/prolog.py`). No puzzle, `-1` é casa sem pista e `0` a `8` é pista; nas rainhas, `1` é rainha e `0` é casa sem rainha.

| Rota / chamada | Entrada | Saída | Predicado Prolog |
|----------------|---------|-------|------------------|
| `POST /api/generate` (`backend/app/main.py:66`) | `{"difficulty": "easy"}` (ou `"medium"`, `"hard"`) | `{"puzzle": [[...], ...]}` | `generate/2` (`backend/prolog/rainhas.pl:200`) |
| `POST /api/solve` (`backend/app/main.py:71`) | `{"puzzle": [[...], ...]}` | `{"queens": [[...], ...]}` | `solve/2` (`backend/prolog/rainhas.pl:159`) |
| `POST /api/hint` (`backend/app/main.py:79`) | `{"puzzle": [[...], ...], "queens": [[...], ...]}` | `{"row": 2, "col": 4}` | `hint/3` (`backend/prolog/rainhas.pl:286`) |

Se o puzzle não tem solução, se há rainha errada ou se não resta dica a dar, a resposta é 422 com `{"detail": "mensagem"}`, e o Elm mostra essa mensagem (`errorDetail`, `frontend/src/Api.elm:193`). JSON fora do formato também recebe 422, mas do Pydantic, antes de chegar ao Prolog.

## 8. Testes e validação

<!--
  Como o grupo sabe que o sistema funciona? Testes automatizados (plunit,
  pytest, elm-test), roteiros de teste manual, casos de borda verificados.
-->

- [O que foi testado e como.]
- [Casos de borda considerados.]

## 9. Limitações e problemas conhecidos

<!--
  Seja honesto. Um problema conhecido e bem descrito vale mais que um
  problema escondido que o avaliador descobre sozinho.
-->

- [Limitação ou bug conhecido, e em que situação acontece.]
- [O que o grupo faria com mais tempo.]

## 10. Contribuição de cada integrante

<!--
  O que cada pessoa fez. Deve ser coerente com o histórico de commits do
  repositório. Todos os integrantes precisam concordar com esta tabela.
-->

| Integrante | Principais contribuições |
|------------|--------------------------|
| [Nome]     | [...] |
| [Nome]     | [...] |
| [Nome]     | [...] |
| [Nome]     | [...] |
| [Nome]     | [...] |

<!--
  Além desta tabela, que é do grupo, cada integrante entrega uma avaliação
  360 graus individual no SEU repositório do GitHub Classroom, em
  avaliacao-360/<matricula>.md. Veja o modelo em avaliacao-360/TEMPLATE.md.
-->

## 11. Fontes, código de terceiros e uso de IA

<!--
  Declare tudo o que não foi escrito pelo grupo. Declarar não tira pontos;
  deixar de declarar pode anular o trabalho.
-->

**Código reaproveitado.** [Ex.: "Partimos do template do Sudoku. Mantivemos
a integração Python e a estrutura do frontend; o arquivo `x.pl` e os
módulos `Y.elm` e `Z.elm` foram escritos pelo grupo."]

**Referências.** [Livros, documentação, tutoriais, repositórios consultados.]

**Uso de ferramentas de IA.**

- **Faixa de uso no código:** [nenhum | pontual | auxiliar | intensivo]
  <!--
    nenhum: não usou. pontual: autocompletar, dúvidas, explicar erros.
    auxiliar: trechos gerados pela IA e revisados pelo grupo. intensivo: a
    IA escreveu a maior parte do código. Veja o efeito em AVALIACAO.md,
    seção 1.5. Não declarar anula o trabalho; declarar não tira pontos.
  -->

| Ferramenta | Para que foi usada | Como o grupo verificou o resultado |
|------------|--------------------|------------------------------------|
| [Nome ou "nenhuma"] | [...] | [...] |

## 12. Apresentação oral

<!--
  A apresentação tem 15 minutos e acontece no final do semestre. Uma
  divisão que costuma funcionar: 2 min de contexto, 5 min de demonstração
  do sistema funcionando, 6 min mostrando o código Prolog e Elm mais
  interessante, 2 min de limitações e aprendizados. Todos os integrantes
  devem falar.

  Preencha esta seção antes da apresentação.
-->

- **Slides:** [mesmo caminho indicado na seção 1, ou "não há"]
- **Roteiro:**

| Parte | Duração | Quem apresenta |
|-------|:-------:|----------------|
| [Contexto e objetivo] | [2 min] | [Nome] |
| [Demonstração] | [5 min] | [Nome] |
| [Código Prolog] | [3 min] | [Nome] |
| [Código Elm] | [3 min] | [Nome] |
| [Limitações e aprendizados] | [2 min] | [Nome] |

## 13. Reflexão sobre os paradigmas

<!--
  De 1 a 3 parágrafos. Perguntas que podem ajudar:
  - O que ficou mais simples em Prolog do que seria numa linguagem
    imperativa? E o que ficou mais difícil?
  - O que o compilador do Elm impediu que desse errado?
  - Como a forma de pensar mudou entre as duas linguagens?
-->

[Reflexão.]

---

<!--
  CHECKLIST ANTES DE ENTREGAR (apague esta seção depois de conferir)

  - [ ] `uv run scripts/validar_entrega.py` termina sem erros.
  - [ ] Todos os integrantes, com matrícula e turma, estão na seção 1.
  - [ ] O commit ou tag da seção 1 existe no repositório e é a versão final.
  - [ ] As instruções da seção 3 funcionam numa máquina sem nada instalado
        além dos requisitos listados.
  - [ ] Os locais indicados (arquivo:linha) conferem com o commit entregue.
  - [ ] As seções 10 e 11 foram revisadas por todo o grupo.
  - [ ] Se há slides, o arquivo está no repositório e o caminho da seção 1
        está certo.
  - [ ] Cada integrante entregou a própria avaliação 360 graus no seu
        repositório individual, em avaliacao-360/<matricula>.md.
  - [ ] Nenhum texto entre [colchetes] ou comentário de instrução sobrou.
-->

# Rainhas Minadas (Prolog + Elm)

Trabalho final da disciplina de Paradigmas de Programação. **Rainhas Minadas**
é um jogo de lógica que combina **N-Rainhas** com **Campo Minado**. O Prolog
modela as regras, gera puzzles com solução única e calcula dicas; o Elm desenha
a interface e valida conflitos em tempo real; o Python faz apenas a ponte entre
os dois.

## Regras do jogo

Num tabuleiro **N×N** (`6×6` no fácil, `7×7` no médio e `8×8` no difícil), o
objetivo é posicionar **N rainhas** de modo que:

- cada linha tenha exatamente uma rainha;
- cada coluna tenha exatamente uma rainha;
- nenhuma rainha encoste em outra, nem na diagonal;
- uma casa com número não tenha rainha, e o número indique quantas rainhas
  existem nas até 8 casas ao redor (como no Campo Minado).

Todo puzzle gerado tem **solução única**. Na tela, clicar numa casa alterna
entre vazia → `✕` (marcação) → `♛` (rainha) → vazia. Há também os botões
**Dica**, **Resolver** e **Limpar**.

```
┌──────────────────────┐   HTTP/JSON   ┌───────────────────┐  janus  ┌──────────────────┐
│ Navegador            │ ────────────▶ │ FastAPI (Python)  │ ──────▶ │ SWI-Prolog       │
│ Elm + daisyUI (Vite) │ ◀──────────── │ backend/app/      │ ◀────── │ backend/prolog/  │
└──────────────────────┘               └───────────────────┘         └──────────────────┘
    avaliado                              NÃO avaliado                  avaliado
```

## O que cada parte faz

**Prolog** (`backend/prolog/rainhas.pl`). Modela cada casa do tabuleiro como
uma variável `0` ou `1` (`1` = rainha) e expressa as regras do jogo como
restrições da biblioteca CLP(FD), deixando o resolvedor encontrar as respostas.
Tem três predicados principais:

- `solve/2` resolve um puzzle;
- `generate/2` cria um puzzle novo com solução única, no nível `easy` (6×6),
  `medium` (7×7) ou `hard` (8×8);
- `hint/3` recebe o puzzle e as rainhas colocadas pelo jogador e devolve onde
  vai a próxima rainha, ou informa que o tabuleiro já está completo
  (`complete`) ou sem solução (`unsolvable`).

**Python** (`backend/app/`). `prolog.py` carrega `rainhas.pl` com a biblioteca
[janus](https://www.swi-prolog.org/pldoc/man?section=janus), que roda o
SWI-Prolog dentro do próprio processo Python. `main.py` expõe os predicados
como rotas HTTP com o FastAPI. Não há lógica de jogo aqui.

**Elm** (`frontend/src/`). Segue a Arquitetura Elm (`Model`, `Msg`, `update`,
`view`) em três módulos com fronteiras claras:

- `Rainhas.elm` concentra o domínio puro (`Cell`, `Origin`, `Board`) e as
  verificações instantâneas, como destacar em vermelho rainhas que se atacam ou
  pistas com rainhas demais. Não faz HTTP nem HTML.
- `Api.elm` faz as requisições HTTP e converte JSON em valores Elm.
- `Main.elm` gerencia o estado da aplicação, os cliques e a renderização da
  tela.

O visual fica em `frontend/src/style.css`, usando [Tailwind](https://tailwindcss.com)
e [daisyUI](https://daisyui.com) com suporte a tema claro/escuro (salvo em
`localStorage` pelo `main.js`) e grade responsiva adaptada ao tamanho N×N do
tabuleiro. O [Vite](https://vite.dev) serve o frontend e recompila o Elm
automaticamente ao salvar os arquivos.

## Requisitos

- [SWI-Prolog](https://www.swi-prolog.org/Download.html) 9.2 ou mais novo
  (o comando `swipl` precisa estar no PATH);
- [uv](https://docs.astral.sh/uv/) para o Python (ele instala o Python certo
  sozinho);
- [Node.js](https://nodejs.org) 20 ou mais novo, com `npm`.

O compilador do Elm é instalado pelo `npm`, dentro de `frontend/node_modules`.
Não precisa instalar nada globalmente.

No Debian/Ubuntu, a versão do SWI-Prolog no `apt` pode ser antiga. O PPA
oficial resolve: `sudo add-apt-repository ppa:swi-prolog/stable`. Se o
`uv sync` falhar ao instalar o `janus-swi`, quase sempre é porque ele não
achou o `swipl`. Confira com `swipl --version`.

## Como rodar

Instale as dependências uma primeira vez:

```sh
cd backend && uv sync && cd ..
cd frontend && npm install && cd ..
```

Suba o backend e o frontend em **dois terminais** (recomendado, pois o
`make dev` nem sempre inicializa o backend corretamente em todos os sistemas):

```sh
# terminal 1 (backend)
cd backend
uv run fastapi dev app/main.py
```

```sh
# terminal 2 (frontend)
cd frontend
npm run dev
```

Abra http://localhost:5173 para jogar. A documentação interativa da API fica em
http://localhost:8000/docs, onde também é possível testar as rotas diretamente.

Os dois servidores recarregam sozinhos quando você salva um arquivo. O Vite
repassa tudo que começa com `/api` para o backend na porta 8000 (veja
`frontend/vite.config.js`).

## Testando o Prolog direto no terminal

Não precisa subir o restante do sistema para testar a parte lógica:

```sh
swipl backend/prolog/rainhas.pl
```

```prolog
?- example_puzzle(P), print_puzzle(P), solve(P, S), print_solution(S).
?- generate(hard, P), print_puzzle(P).
?- example_puzzle(P), count_solutions(P, 10, N).
```

## Problemas comuns

**`ImportError: libswipl.so.9: cannot open shared object file`** ao subir o
backend ou rodar os testes. O pacote `janus-swi` é compilado contra uma versão
específica do SWI-Prolog. Recompile o pacote a partir do código-fonte,
ignorando o cache:

```sh
cd backend
uv sync --reinstall-package janus-swi --no-binary-package janus-swi --no-cache
```

## Testes

Com `make`:

```sh
make test           # todos os testes
make test-prolog    # só os testes em Prolog (plunit)
make test-backend   # só os testes da API (pytest)
```

Sem `make` (por exemplo, no Windows):

```sh
swipl -g run_tests -t halt backend/prolog/test_rainhas.pl
cd backend && uv run pytest
```

A suíte conta com 15 verificações em `plunit` (`backend/prolog/test_rainhas.pl`)
e 7 testes de API em `pytest` (`backend/tests/test_api.py`).

## API

Todas as rotas recebem e devolvem JSON com matrizes N×N:

- em `puzzle`, `-1` indica casa sem pista e `0` a `8` indicam pistas numéricas;
- em `queens`, `1` indica rainha e `0` indica casa vazia.

| Rota                 | Corpo enviado                                    | Resposta                | Predicado Prolog |
| -------------------- | ------------------------------------------------ | ----------------------- | ---------------- |
| `POST /api/generate` | `{"difficulty": "easy"}`                         | `{"puzzle": [[...]]}`   | `generate/2`     |
| `POST /api/solve`    | `{"puzzle": [[...]]}`                            | `{"queens": [[...]]}`   | `solve/2`        |
| `POST /api/hint`     | `{"puzzle": [[...]], "queens": [[...]]}`         | `{"row": 2, "col": 4}`  | `hint/3`         |

Quando não há solução possível, `solve` e `hint` respondem com status `422` e
`{"detail": "mensagem"}`. `hint` também retorna `422` quando o tabuleiro já
está completo. O Elm exibe essa mensagem na tela.

## Entrega

A entrega acontece pelo GitHub Classroom, em duas atividades:

1. **Repositório do grupo.** Contém o código do projeto e o `RELATORIO.md`
   preenchido com a documentação completa.
2. **Repositório individual.** Um por aluno, com a avaliação 360 graus dos
   colegas em `avaliacao-360/<sua-matricula>.md`, copiada de
   `avaliacao-360/TEMPLATE.md`.

Antes de entregar, confira a forma dos documentos com o validador:

```sh
make validar                                                     # repositório do grupo
uv run scripts/validar_entrega.py avaliacao-360/<matricula>.md   # repositório individual
```

Os critérios de avaliação, com a rubrica da nota do grupo, a fórmula da nota
individual e os prazos, estão em `AVALIACAO.md`.

## Estrutura

```
backend/
  prolog/rainhas.pl         regras (CLP(FD)), resolvedor, gerador e dica
  prolog/test_rainhas.pl    testes plunit
  app/prolog.py             ponte Python → Prolog (janus)
  app/main.py               rotas HTTP (FastAPI)
  tests/test_api.py         testes da API (pytest)
frontend/
  src/Main.elm              Arquitetura Elm: estado, eventos e tela
  src/Rainhas.elm           domínio puro e detecção de conflitos
  src/Api.elm               requisições HTTP e encoders/decoders JSON
  src/main.js               inicia o Elm e persiste o tema escolhido
  src/style.css             estilos, temas claro/escuro e grade N×N
  vite.config.js            plugins e proxy para o backend
Makefile                    atalhos (install, dev, test, validar)
RELATORIO.md                relatório de entrega do grupo
AVALIACAO.md                critérios de avaliação (rubrica e nota individual)
avaliacao-360/TEMPLATE.md   template da avaliação 360 graus (individual)
scripts/validar_entrega.py  valida a forma dos documentos de entrega
scripts/                    ferramentas de correção da disciplina
```
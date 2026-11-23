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

Cada casa do tabuleiro é uma variável que vale 0 ou 1 (1 = rainha), e cada regra do jogo é uma restrição de soma do CLP(FD).

| Predicado | Local | O que faz |
|-----------|-------|-----------|
| `board_constraints(+N, ?Queens)` | `rainhas.pl:58` | As regras das rainhas: soma 1 em cada linha e coluna, e nenhuma rainha encostada em outra |
| `exactly_one(?Cells)` | `rainhas.pl:81` | A soma de uma linha ou coluna é 1 |
| `no_touching(?Rows)` | `rainhas.pl:87` | Percorre as linhas de duas em duas, por recursão |
| `squares(?Upper, ?Lower)` | `rainhas.pl:94` | Em todo quadrado 2×2 há no máximo 1 rainha; isso cobre todos os contatos, porque duas casas vizinhas sempre dividem algum 2×2 |
| `clue_constraints(+Puzzle, ?Queens)` | `rainhas.pl:103` | Aplica as restrições de cada pista |
| `clue_constraint(+Queens, +R-C-K)` | `rainhas.pl:114` | A casa da pista vale 0, e a soma das vizinhas é K |
| `neighbors(+Grid, +R-C, -Vars)` | `rainhas.pl:126` | As até 8 casas vizinhas de uma posição |
| `puzzle_constraints(+Puzzle, -Queens)` | `rainhas.pl:146` | Junta as regras das rainhas e as das pistas |
| `solve(+Puzzle, -Solution)` | `rainhas.pl:159` | Resolve o puzzle |
| `count_solutions(+Puzzle, +Limit, -Count)` | `rainhas.pl:168` | Conta as soluções até o limite; usado para garantir solução única |
| `difficulty_size(?Difficulty, ?N)` | `rainhas.pl:195` | Fatos: o tamanho do tabuleiro por nível (6, 7 e 8) |
| `generate(+Difficulty, -Puzzle)` | `rainhas.pl:200` | Gera um puzzle com solução única |
| `random_solution(+N, -Solution)` | `rainhas.pl:212` | Sorteia uma posição válida das rainhas |
| `random_labeling(+Vars)` | `rainhas.pl:220` | Como o `label/1`, mas tenta 0 e 1 em ordem aleatória |
| `reveal_until_unique/5` | `rainhas.pl:241` | Revela pistas aleatórias até a solução ficar única |
| `hide_redundant/3` | `rainhas.pl:251` | Esconde as pistas desnecessárias, deixando o puzzle enxuto |
| `hint(+Puzzle, +Board, -Result)` | `rainhas.pl:286` | Dica: a posição da próxima rainha, `complete` ou `unsolvable` |
| `keep_queen/2` | `rainhas.pl:304` | Fixa em 1 as rainhas que o jogador já colocou |

### 5.2 Conceitos do paradigma lógico utilizados

- [x] Fatos e regras como base de conhecimento: os fatos `difficulty_size/2` (`rainhas.pl:195`) dão o tamanho do tabuleiro por nível, e `no_clue/1` (`rainhas.pl:49`) define o valor de "casa sem pista". As regras do jogo são predicados como `board_constraints/2` (`rainhas.pl:58`) e `clue_constraint/2` (`rainhas.pl:114`).
- [x] Unificação e casamento de padrões: `squares/2` separa as duas primeiras casas de cada linha com `[A, B | As]` (`rainhas.pl:95`); `clue_constraint/2` desmonta a pista com `R-C-K` (`rainhas.pl:114`); `keep_queen/2` escolhe a cláusula pelo valor da casa, `1` ou `0` (`rainhas.pl:304`).
- [x] Recursão (inclusive sobre listas): `no_touching/1` (`rainhas.pl:87`) e `squares/2` (`rainhas.pl:94`) percorrem as linhas; `random_labeling/1` (`rainhas.pl:220`), `reveal_until_unique/5` (`rainhas.pl:241`) e `hide_redundant/3` (`rainhas.pl:251`) percorrem listas, cada um com seu caso base.
- [x] Backtracking e múltiplas soluções: `clue_at/4` (`rainhas.pl:108`) enumera as pistas por backtracking sobre `nth0/3`; `random_labeling/1` usa `member/2` como ponto de escolha (`rainhas.pl:225`); `count_solutions/3` (`rainhas.pl:168`) volta atrás para enumerar as soluções e contá-las.
- [x] `findall/3`, `bagof/3`, `setof/3` ou similares: `findall/3` em `clue_constraints/2` (`rainhas.pl:104`), `neighbors/3` (`rainhas.pl:129`), `count_solutions/3` (`rainhas.pl:169`), `generate/2` (`rainhas.pl:205`) e `hint/3` (`rainhas.pl:291`). Como o `findall/3` copia as variáveis, o `neighbors/3` coleta só as posições e depois busca as variáveis com `maplist/3` (`rainhas.pl:136`).
- [x] Corte (`!`) ou negação (`\+`), e por que foram necessários: o corte em `solve/2` (`rainhas.pl:163`) fica só com a primeira solução encontrada, sem procurar outras se o usuário pedir mais. Em `generate/2` (`rainhas.pl:209`) e `random_solution/2` (`rainhas.pl:216`), o corte impede que o backtracking gere outro puzzle depois do primeiro. Em `reveal_until_unique/5` (`rainhas.pl:243`), ele para de revelar pistas quando a solução fica única. Em `keep_queen/2` (`rainhas.pl:304`), evita deixar um ponto de escolha desnecessário. Não usamos negação (`\+`).
- [x] Programação por restrições (CLP(FD) ou outra): `ins 0..1` declara cada casa como 0 ou 1 (`rainhas.pl:66`); `sum/3` exige soma 1 por linha e coluna (`rainhas.pl:82`) e soma K ao redor de cada pista (`rainhas.pl:118`); `#=<` limita cada quadrado 2×2 a uma rainha (`rainhas.pl:96`); `labeling/2` com a heurística `ff` encontra os valores em `solve/2` (`rainhas.pl:162`), `count_solutions/3` e `hint/3`.
- [x] Predicados de ordem superior (`maplist`, `foldl`, `include`...): `maplist(exactly_one, Queens)` e `maplist(exactly_one, Columns)` em `board_constraints/2` (`rainhas.pl:69` e `73`); `maplist(clue_constraint(Queens), Clues)` com aplicação parcial (`rainhas.pl:105`); `maplist(maplist(keep_queen), Board, Solution)` em `hint/3` (`rainhas.pl:288`), um `maplist` dentro de outro, para percorrer a grade.
- [x] Outro: `limit/2` em `count_solutions/3` (`rainhas.pl:170`) para de contar ao chegar no limite (para saber se a solução é única, basta ver se existem 2); e o se-então-senão (`->` / `;`) em `hint/3` (`rainhas.pl:286`) e `hide_redundant/3` (`rainhas.pl:255`).

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

<!--
  Os tipos centrais do programa: o Model, o tipo Msg e os custom types do
  domínio. Explique as escolhas: por que um custom type e não um Bool, por
  que Maybe ou Result, etc.
-->

```elm
[type alias Model = ...]
[type Msg = ...]
```

[Explicação das escolhas.]

### 6.2 Conceitos do paradigma funcional utilizados

- [ ] Arquitetura Elm (Model, update, view): [onde]
- [ ] Custom types e `case` exaustivo: [onde]
- [ ] `Maybe` e `Result` no lugar de null e exceções: [onde]
- [ ] Funções de ordem superior e aplicação parcial: [onde]
- [ ] Composição (`|>`, `>>`): [onde]
- [ ] Decoders e encoders JSON: [onde]
- [ ] Comandos e subscriptions (efeitos controlados): [onde]
- [ ] Imutabilidade e atualização de records: [onde]
- [ ] Outro: [...]

### 6.3 Trecho em destaque

```elm
[trecho]
```

[Explicação.]

## 7. Integração

<!--
  Curto: a parte Python não é avaliada. Liste as rotas ou a forma de
  comunicação e o formato dos dados trocados. Se o grupo não usou Python,
  explique como Elm e Prolog se comunicam.
-->

| Rota / chamada | Entrada | Saída | Predicado Prolog |
|----------------|---------|-------|------------------|
| [`POST /api/...`] | [...] | [...] | [`...`] |

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

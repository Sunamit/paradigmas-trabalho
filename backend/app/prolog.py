"""Ponte entre Python e Prolog usando a biblioteca janus.

janus (pacote `janus-swi`) embute o SWI-Prolog dentro do processo Python.
Não há servidor Prolog separado nem troca de mensagens: chamamos predicados
diretamente e recebemos as respostas como dicionários Python.

Este é o ÚNICO arquivo do projeto que conhece o janus. O resto do backend
só chama as funções abaixo. Nenhuma regra do jogo mora aqui: tudo isso está
em prolog/rainhas.pl.
"""

from pathlib import Path

import janus_swi as janus

Grid = list[list[int]]

PROLOG_FILE = Path(__file__).parent.parent / "prolog" / "rainhas.pl"

janus.consult(str(PROLOG_FILE))


class NoSolution(Exception):
    """O puzzle (ou as rainhas do jogador) não tem solução."""


class BoardComplete(Exception):
    """Todas as rainhas já estão no lugar certo: não há dica para dar."""


def solve(puzzle: Grid) -> Grid:
    # Devolve a grade de 0/1 com as rainhas da solução.
    result = janus.query_once("rainhas:solve(Puzzle, Solution)", {"Puzzle": puzzle})
    if not result["truth"]:
        raise NoSolution
    return result["Solution"]


def generate(difficulty: str) -> Grid:
    # generate/2 espera um ÁTOMO (easy, medium, hard); a string do Python
    # vira átomo com atom_string/2, do lado Prolog.
    result = janus.query_once(
        "atom_string(D, Name), rainhas:generate(D, Puzzle)", {"Name": difficulty}
    )
    return result["Puzzle"]


def hint(puzzle: Grid, queens: Grid) -> tuple[int, int]:
    result = janus.query_once(
        "rainhas:hint(Puzzle, Board, Result)", {"Puzzle": puzzle, "Board": queens}
    )["Result"]
    # hint/3 devolve [Linha, Coluna] ou um dos átomos `complete` e
    # `unsolvable`, que chegam ao Python como strings. Quem decidiu foi o
    # Prolog; aqui só traduzimos cada caso.
    match result:
        case "complete":
            raise BoardComplete
        case "unsolvable":
            raise NoSolution
        case [row, col]:
            return row, col
    raise ValueError(f"resultado inesperado de hint/3: {result!r}")
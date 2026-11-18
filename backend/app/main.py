"""API HTTP do Rainhas Minadas.

Esta camada é só "cola": recebe JSON, valida o formato com Pydantic, chama o
Prolog (via app/prolog.py) e devolve JSON. Nenhuma regra do jogo mora aqui.

Rodar em modo de desenvolvimento (recarrega ao salvar):
    uv run fastapi dev app/main.py

Documentação interativa gerada automaticamente: http://localhost:8000/docs
"""

from typing import Annotated, Literal

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

from app import prolog

app = FastAPI(title="Rainhas Minadas (Prolog + Elm)")

# O tabuleiro tem de 4 a 8 linhas. Se não for quadrado, quem recusa é o
# Prolog (o puzzle fica sem solução).
SIZE = Field(min_length=4, max_length=8)

# Puzzle: -1 é casa sem pista; de 0 a 8 é uma pista.
ClueCell = Annotated[int, Field(ge=-1, le=8)]
PuzzleGrid = Annotated[list[Annotated[list[ClueCell], SIZE]], SIZE]

# Rainhas: 1 onde há rainha, 0 onde não há.
QueenCell = Annotated[int, Field(ge=0, le=1)]
QueenGrid = Annotated[list[Annotated[list[QueenCell], SIZE]], SIZE]


class GenerateRequest(BaseModel):
    difficulty: Literal["easy", "medium", "hard"] = "medium"


class PuzzleRequest(BaseModel):
    puzzle: PuzzleGrid


class PuzzleResponse(BaseModel):
    puzzle: PuzzleGrid


class HintRequest(BaseModel):
    puzzle: PuzzleGrid
    queens: QueenGrid


class QueensResponse(BaseModel):
    queens: QueenGrid


class HintResponse(BaseModel):
    row: int
    col: int


# Mensagens que o Elm mostra na tela quando a resposta é 422.
NO_SOLUTION = "Este puzzle não tem solução."
WRONG_QUEEN = "Alguma rainha está no lugar errado: com ela, não há solução."
BOARD_COMPLETE = "Todas as rainhas já estão no lugar certo."


@app.post("/api/generate")
def generate(request: GenerateRequest) -> PuzzleResponse:
    return PuzzleResponse(puzzle=prolog.generate(request.difficulty))


@app.post("/api/solve")
def solve(request: PuzzleRequest) -> QueensResponse:
    try:
        return QueensResponse(queens=prolog.solve(request.puzzle))
    except prolog.NoSolution:
        raise HTTPException(status_code=422, detail=NO_SOLUTION) from None


@app.post("/api/hint")
def hint(request: HintRequest) -> HintResponse:
    try:
        row, col = prolog.hint(request.puzzle, request.queens)
    except prolog.NoSolution:
        raise HTTPException(status_code=422, detail=WRONG_QUEEN) from None
    except prolog.BoardComplete:
        raise HTTPException(status_code=422, detail=BOARD_COMPLETE) from None
    return HintResponse(row=row, col=col)
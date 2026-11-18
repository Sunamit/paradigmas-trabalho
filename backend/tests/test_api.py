"""Testes da API HTTP (pytest).

Usamos o TestClient do FastAPI: ele chama a aplicação diretamente, sem subir
um servidor nem abrir porta.

Rodar: `uv run pytest` (na pasta backend) ou `make test-backend` (na raiz).

As regras do jogo são testadas em Prolog (prolog/test_rainhas.pl). Aqui
conferimos só a "cola": rotas, formato do JSON e códigos de status.
"""

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)

# O mesmo puzzle de example_puzzle/1 em rainhas.pl.
EXAMPLE = [
    [-1, -1, -1, -1, 0, -1],
    [-1, -1, -1, -1, -1, -1],
    [1, -1, -1, -1, -1, -1],
    [-1, -1, -1, -1, -1, -1],
    [-1, 1, -1, 1, -1, -1],
    [-1, -1, -1, -1, -1, -1],
]

SOLUTION = [
    [1, 0, 0, 0, 0, 0],
    [0, 0, 1, 0, 0, 0],
    [0, 0, 0, 0, 1, 0],
    [0, 1, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 1],
    [0, 0, 0, 1, 0, 0],
]

NO_QUEENS = [[0] * 6 for _ in range(6)]


def test_solve():
    response = client.post("/api/solve", json={"puzzle": EXAMPLE})
    assert response.status_code == 200
    assert response.json()["queens"] == SOLUTION


def test_solve_without_solution():
    puzzle = [row[:] for row in EXAMPLE]  # cópia, para não alterar EXAMPLE
    puzzle[0][0] = 8  # um canto tem só 3 vizinhas: 8 é impossível
    response = client.post("/api/solve", json={"puzzle": puzzle})
    assert response.status_code == 422


def test_solve_rejects_malformed_puzzle():
    # Quem rejeita aqui é o Pydantic, antes de o Prolog ser chamado.
    response = client.post("/api/solve", json={"puzzle": [[1, 2, 3]]})
    assert response.status_code == 422


def test_generate():
    response = client.post("/api/generate", json={"difficulty": "easy"})
    assert response.status_code == 200
    puzzle = response.json()["puzzle"]
    assert len(puzzle) == 6 and all(len(row) == 6 for row in puzzle)
    cells = sum(puzzle, [])  # sum(..., []) concatena as linhas
    assert -1 in cells  # há casa sem pista
    assert any(cell >= 0 for cell in cells)  # e há ao menos uma pista


def test_hint():
    response = client.post("/api/hint", json={"puzzle": EXAMPLE, "queens": NO_QUEENS})
    assert response.status_code == 200
    hint = response.json()
    assert SOLUTION[hint["row"]][hint["col"]] == 1  # a dica é uma rainha certa


def test_hint_when_complete():
    response = client.post("/api/hint", json={"puzzle": EXAMPLE, "queens": SOLUTION})
    assert response.status_code == 422
    assert response.json()["detail"] == "Todas as rainhas já estão no lugar certo."


def test_hint_with_wrong_queen():
    queens = [row[:] for row in NO_QUEENS]
    queens[0][1] = 1  # rainha fora da solução
    response = client.post("/api/hint", json={"puzzle": EXAMPLE, "queens": queens})
    assert response.status_code == 422
    assert "lugar errado" in response.json()["detail"]
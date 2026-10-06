import pytest

from app.main import app


@pytest.fixture
def client():
    app.config["TESTING"] = True
    return app.test_client()


def test_index(client):
    r = client.get("/")
    assert r.status_code == 200
    assert b"Calculator API" in r.data


def test_health(client):
    assert client.get("/health").get_json()["status"] == "ok"


def test_add_endpoint(client):
    assert client.get("/api/add?a=10&b=5").get_json()["result"] == 15


def test_divide_by_zero_endpoint(client):
    r = client.get("/api/divide?a=1&b=0")
    assert r.status_code == 400


def test_unknown_operation(client):
    assert client.get("/api/power?a=2&b=3").status_code == 404

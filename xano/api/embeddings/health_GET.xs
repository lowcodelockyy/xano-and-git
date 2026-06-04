// Lightweight health check for the Embeddings service.
// Returns service status, the current server time, and how many embeddings are
// stored. Uses no external APIs, so it is safe to run in the secret-less sandbox.
query "health" verb=GET {
  api_group = "Embeddings"
  description = "Health check: reports service status and stored embedding count."

  input {
  }

  stack {
    db.query embedding_item {
      return = {type: "count"}
      mock = {
        "reports ok with stored count": 7,
        "reports ok with empty store": 0
      }
    } as $stored_count

    var $checked_at {
      value = "now"
    }
  }

  response = {
    status      : "ok",
    service     : "embeddings",
    stored_items: $stored_count,
    checked_at  : $checked_at
  }

  // Sandbox-safe: the db.query count is mocked, so this needs no secrets and no
  // seeded data. Proves the health contract (status/service/count) holds.
  test "reports ok with stored count" {
    expect.to_equal ($response.status) { value = "ok" }
    expect.to_equal ($response.service) { value = "embeddings" }
    expect.to_equal ($response.stored_items) { value = 7 }
    expect.to_not_be_null ($response.checked_at)
  }

  test "reports ok with empty store" {
    expect.to_equal ($response.status) { value = "ok" }
    expect.to_equal ($response.stored_items) { value = 0 }
  }
}

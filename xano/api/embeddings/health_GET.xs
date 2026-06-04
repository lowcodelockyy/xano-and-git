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
}

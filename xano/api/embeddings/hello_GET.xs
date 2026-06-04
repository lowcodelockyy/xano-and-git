// Minimal hello-world endpoint.
// Takes an optional name and returns a friendly greeting plus the server time.
// Uses no external APIs or secrets, so it is safe to run in the sandbox.
query "hello" verb=GET {
  api_group = "Embeddings"
  description = "Hello world: returns a greeting and the current server time."

  input {
    text name? filters=trim
  }

  stack {
    var $who {
      value = ($input.name == null || $input.name == "") ? "world" : $input.name
    }

    var $greeted_at {
      value = "now"
    }
  }

  response = {
    message   : "Hello, "~$who~"!",
    greeted_at: $greeted_at
  }

  // Sandbox-safe: no secrets, no seeded data, no external calls.
  test "greets the provided name" {
    input = { name: "Xano" }
    expect.to_equal ($response.message) { value = "Hello, Xano!" }
    expect.to_not_be_null ($response.greeted_at)
  }

  test "defaults to world when no name given" {
    expect.to_equal ($response.message) { value = "Hello, world!" }
  }
}

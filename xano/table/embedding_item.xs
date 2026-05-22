table embedding_item {
  auth = false

  schema {
    int id
    timestamp created_at?=now

    enum kind {
      values = ["text", "image", "multimodal"]
      description = "Modality of the source content"
    }

    text? title? filters=trim
    text? content? filters=trim {
      description = "Text portion of the input (caption or raw text)"
    }

    text? image_mime_type? filters=trim|lower {
      description = "MIME type of attached image (image/png, image/jpeg)"
    }

    text? image_base64? {
      description = "Base64-encoded image bytes (kept for reference / re-embedding)"
      sensitive = true
    }

    json? metadata?

    vector embedding {
      size = 768
      description = "Gemini multimodal embedding vector (Matryoshka truncated to 768 dims)"
    }
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree", field: [{name: "created_at", op: "desc"}]}
    {type: "btree", field: [{name: "kind", op: "asc"}]}
    {type: "vector", field: [{name: "embedding", op: "vector_cosine_ops"}]}
  ]
  guid = "0E3s8JDLtrgNi8Pq7wGx7QTINqg"
}

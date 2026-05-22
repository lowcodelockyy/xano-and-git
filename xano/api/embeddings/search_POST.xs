// Similarity search across stored embeddings. Provide text and/or an image as the query.
// Returns the closest matches by cosine distance (smaller = more similar).
query "search" verb=POST {
  api_group = "Embeddings"
  description = "Vector similarity search using Gemini multimodal embeddings."

  input {
    text? content? filters=trim
    text? image_base64?
    text? image_mime_type?="image/png" filters=trim|lower
    int limit?=5 filters=min:1|max:50
    text? kind? filters=trim|lower
  }

  stack {
    precondition (($input.content != null && (($input.content|strlen) > 0)) || ($input.image_base64 != null && (($input.image_base64|strlen) > 0))) {
      error_type = "inputerror"
      error = "Provide content text and/or image_base64 to search by."
    }

    function.run "gemini_embed" {
      input = {
        text_content    : $input.content,
        image_base64    : $input.image_base64,
        image_mime_type : $input.image_mime_type
      }
    } as $query_vector

    db.query embedding_item {
      where = $db.embedding_item.kind ==? $input.kind
      sort = {distance: "asc"}
      eval = {
        distance: $db.embedding_item.embedding|cosine_distance:$query_vector
      }
      return = {
        type  : "list",
        paging: {page: 1, per_page: $input.limit, metadata: false}
      }
    } as $results
  }

  response = {
    query_dims: ($query_vector|count),
    matches   : $results|map:{
      id              : $$.id,
      kind            : $$.kind,
      title           : $$.title,
      content         : $$.content,
      image_mime_type : $$.image_mime_type,
      distance        : $$.distance,
      created_at      : $$.created_at,
      metadata        : $$.metadata
    }
  }
  guid = "VXv0aLspATrS2-k9eVPVqHuOOFI"
}

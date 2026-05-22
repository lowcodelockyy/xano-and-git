// Upload text and/or an image, embed it via Gemini, and store it in `embedding_item`.
// Provide `content` (text) and/or `image_base64` + `image_mime_type`.
query "embed" verb=POST {
  api_group = "Embeddings"
  description = "Create and store a multimodal embedding from text and/or an image."

  input {
    text? title? filters=trim
    text? content? filters=trim
    text? image_base64?
    text? image_mime_type?="image/png" filters=trim|lower
    json? metadata?
  }

  stack {
    precondition (($input.content != null && (($input.content|strlen) > 0)) || ($input.image_base64 != null && (($input.image_base64|strlen) > 0))) {
      error_type = "inputerror"
      error = "Provide content text and/or image_base64."
    }

    var $kind {
      value = "text"
    }

    conditional {
      if ($input.image_base64 != null && (($input.image_base64|strlen) > 0)) {
        conditional {
          if ($input.content != null && (($input.content|strlen) > 0)) {
            var.update $kind {
              value = "multimodal"
            }
          }
          else {
            var.update $kind {
              value = "image"
            }
          }
        }
      }
    }

    function.run "gemini_embed" {
      input = {
        text_content    : $input.content,
        image_base64    : $input.image_base64,
        image_mime_type : $input.image_mime_type
      }
    } as $vector

    db.add embedding_item {
      data = {
        created_at      : "now",
        kind            : $kind,
        title           : $input.title,
        content         : $input.content,
        image_mime_type : $input.image_mime_type,
        image_base64    : $input.image_base64,
        metadata        : $input.metadata,
        embedding       : $vector
      }
    } as $item
  }

  response = {
    id        : $item.id,
    kind      : $item.kind,
    title     : $item.title,
    created_at: $item.created_at,
    dims      : ($vector|count)
  }
  guid = "C5Dho8EfOQ2a9W2d6tzdA63ZiA8"
}

// Generate a multimodal embedding via Google's Gemini Embedding 2 model.
// Accepts optional text and/or base64-encoded image; returns the embedding values array.
//
// Docs: https://ai.google.dev/gemini-api/docs/embeddings
// Endpoint: POST https://generativelanguage.googleapis.com/v1beta/models/{model}:embedContent
// Auth: header `x-goog-api-key: $env.GEMINI_API_KEY`
function "gemini_embed" {
  description = "Call Gemini Embedding 2 with text and/or image and return the embedding vector."

  input {
    text? text_content?
    text? image_base64?
    text? image_mime_type?="image/png"
  }

  stack {
    var $parts {
      value = []
    }

    conditional {
      if ($input.text_content != null && (($input.text_content|strlen) > 0)) {
        var.update $parts {
          value = $parts|push:{text: $input.text_content}
        }
      }
    }

    conditional {
      if ($input.image_base64 != null && (($input.image_base64|strlen) > 0)) {
        var.update $parts {
          value = $parts|push:{inline_data: {mime_type: $input.image_mime_type, data: $input.image_base64}}
        }
      }
    }

    precondition (($parts|count) > 0) {
      error_type = "inputerror"
      error = "Must provide text_content or image_base64"
    }

    var $url {
      value = "https://generativelanguage.googleapis.com/v1beta/models/" ~ $env.GEMINI_EMBED_MODEL ~ ":embedContent"
    }

    var $body {
      value = {
        content: {parts: $parts},
        output_dimensionality: ($env.GEMINI_EMBED_DIMS|to_int)
      }
    }

    api.request {
      url = $url
      method = "POST"
      params = $body
      headers = ["Content-Type: application/json", "x-goog-api-key: " ~ $env.GEMINI_API_KEY]
      timeout = 30
    } as $api_result

    precondition ($api_result.response.status >= 200 && $api_result.response.status < 300) {
      error_type = "standard"
      error = "Gemini embed failed (" ~ ($api_result.response.status|to_text) ~ "): " ~ ($api_result.response.result|json_encode)
    }

    // Response shape differs between models:
    //   - gemini-embedding-001 (text):     { embedding: { values: [...] } }
    //   - gemini-embedding-2 (multimodal): { embeddings: [{ values: [...] }] }
    var $values {
      value = null
    }

    conditional {
      if (($api_result.response.result|has:"embeddings") == true) {
        var.update $values {
          value = $api_result.response.result.embeddings|first|get:"values"
        }
      }
      elseif (($api_result.response.result|has:"embedding") == true) {
        var.update $values {
          value = $api_result.response.result.embedding|get:"values"
        }
      }
    }

    precondition ($values != null && (($values|count) > 0)) {
      error_type = "standard"
      error = "Gemini response missing embedding values: " ~ ($api_result.response.result|json_encode)
    }
  }

  response = $values
  guid = "BBzK4QUBpx4p4JV4KCXokBG93Gk"
}

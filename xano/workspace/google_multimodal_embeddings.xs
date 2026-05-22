workspace "Google Multimodal Embeddings" {
  description = "Pipeline for storing and searching text + image content using Google's Gemini multimodal embeddings (gemini-embedding-2-preview)."
  acceptance = {ai_terms: false}
  preferences = {
    internal_docs    : false
    track_performance: true
    sql_names        : false
    sql_columns      : true
  }
  env = {
    GEMINI_API_KEY      : "set-in-xano-dashboard",
    GEMINI_EMBED_MODEL  : "gemini-embedding-2-preview",
    GEMINI_EMBED_DIMS   : "768"
  }
}

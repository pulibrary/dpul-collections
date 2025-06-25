use embed_anything::embeddings::embed::{EmbedderBuilder, Embedder, EmbeddingResult};
use once_cell::sync::Lazy; // Import Lazy
use rustler::{Env, Term, Error};
use std::sync::Arc;
use tokio::runtime::Runtime;

// Tokio runtime lets us block on async code.
static TOKIO_RUNTIME: Lazy<Runtime> =
    Lazy::new(|| tokio::runtime::Runtime::new().expect("Failed to create Tokio runtime"));

static MODEL: Lazy<Result<Arc<Embedder>, String>> = Lazy::new(|| {
    let result = EmbedderBuilder::new()
        .model_architecture("qwen3")
        .model_id(Some("Qwen/Qwen3-Embedding-0.6B"))
        .revision(None)
        .token(None)
        .from_pretrained_hf();

    match result {
        Ok(embedder) => {
            Ok(Arc::new(embedder))
        }
        Err(e) => {
            eprintln!("Failed to load model on startup: {}", e);
            Err(e.to_string())
        }
    }
});


// When erlang spins up, run load - download/initialize model.
fn load(_env: Env, _: Term) -> bool {
    Lazy::force(&MODEL);
    true
}

#[rustler::nif(schedule = "DirtyCpu")]
fn embed_text(texts_to_embed: Vec<String>) -> Result<Vec<Vec<f32>>, Error> {
    // Access the globally shared model.
    let model_result = &*MODEL;

    match model_result {
        Ok(model_arc) => {
            let text_slices: Vec<&str> = texts_to_embed.iter().map(|s| s.as_str()).collect();
            let result_from_async = TOKIO_RUNTIME.block_on(model_arc.embed(&text_slices,None,None));
            let embedding_results = result_from_async.map_err(|e| Error::Term(Box::new(e.to_string())))?;

            let final_vectors = embedding_results
                .into_iter()
                .filter_map(|data| match data {
                    EmbeddingResult::DenseVector(vector) => Some(vector),
                    EmbeddingResult::MultiVector(_vector) => None,
                })
                .collect();

            Ok(final_vectors)
        }
        Err(error_string) => {
            let error_message = format!("Model is not available. Load error: {}", error_string);
            Err(Error::Term(Box::new(error_message)))
        }
    }
}

rustler::init!("Elixir.EmbedAnything", load = load);

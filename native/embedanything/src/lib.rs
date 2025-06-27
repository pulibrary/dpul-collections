use once_cell::sync::Lazy; // Import Lazy
use rustler::{Env, Term, Error};
use std::sync::Arc;
use std::{fs, path::{self, Path, PathBuf},};
use futures::future::join_all;
use tokio::runtime::Runtime;
use text_embeddings_backend::{Backend, DType, ModelType, Pool};
use text_embeddings_core::{
    TextEmbeddingsError,
    infer::{Infer, PooledEmbeddingsInferResponse},
    queue::Queue,
    tokenization::{EncodingInput, Tokenization},
};
use tokenizers::{Tokenizer, TruncationDirection};
use tokenizers::utils::padding::{PaddingParams, PaddingDirection};
use anyhow::{Result};
use hf_hub::api::sync::Api;

// Tokio runtime lets us block on async code.
static TOKIO_RUNTIME: Lazy<Runtime> =
    Lazy::new(|| tokio::runtime::Runtime::new().expect("Failed to create Tokio runtime"));

static MODEL: Lazy<Arc<Infer>> = Lazy::new(|| {
    let _guard = TOKIO_RUNTIME.enter();
    let api = Api::new().unwrap();
    let repo = api.model("Qwen/Qwen3-Embedding-0.6B".to_string());
    let _config_json = repo.get("config.json").unwrap();
    let tokenizer_json = repo.get("tokenizer.json").unwrap();
    let model_file = repo.get("model.safetensors").unwrap();
    let parent_dir = model_file.parent().unwrap();
    println!("Downloaded");
    let mut padding = PaddingParams::default();
    padding.direction = PaddingDirection::Left;
    let tokenizer = Tokenizer::from(Tokenizer::from_file(tokenizer_json).unwrap().with_padding(Some(padding)).clone());
    println!("Tokenizer: {:?}", tokenizer.get_padding().unwrap());
    let token = Tokenization::new(
        1,
        tokenizer,
        1024,
        0,
        None,
        None
    );
    let model_type = ModelType::Embedding(Pool::LastToken);
    let backend = TOKIO_RUNTIME.block_on(Backend::new(
        parent_dir.into(),
        None,
        DType::Float16,
        model_type,
        String::new(),
        None,
        String::new()
    )).unwrap();
    let queue = Queue::new(
        backend.padded_model,
        16384,
        None,
        512
    );
    let infer = Infer::new(token, queue, 512, backend);

    Arc::new(infer)
});


// When erlang spins up, run load - download/initialize model.
fn load(_env: Env, _: Term) -> bool {
    Lazy::force(&MODEL);
    true
}

#[rustler::nif(schedule = "DirtyCpu")]
fn embed_text(texts_to_embed: Vec<String>) -> Result<Vec<Vec<f32>>, Error> {
    let infer = &*MODEL;
    let batch_size = texts_to_embed.len();
    let mut futures = Vec::with_capacity(batch_size);
    for input in texts_to_embed {
        let local_infer = infer.clone();
        futures.push(async move {
            let permit = local_infer.acquire_permit().await;
            local_infer
                .embed_pooled(
                    input,
                    false,
                    TruncationDirection::Right,
                    None,
                    true,
                    permit
                )
                .await
        });
    }
    let final_result: Result<Vec<Vec<f32>>, _> =
        TOKIO_RUNTIME.block_on(join_all(futures)) // Produces Vec<Result<...>>
        .into_iter() // Creates an iterator over the Results
        .collect::<Result<Vec<_>, _>>() // Transforms Vec<Result<T, E>> to Result<Vec<T>, E>
        .map(|responses| { // .map() is called on the Result
            responses
                .into_iter()
                .map(|response| response.results) // Extracts the Vec<f32> from each response
                .collect() // Collects these into the final Vec<Vec<f32>>
        })
        .map_err(|e| Error::Term(Box::new(format!("Errored embedding: {}", e))));
    final_result
}
rustler::init!("Elixir.EmbedAnything", load = load);

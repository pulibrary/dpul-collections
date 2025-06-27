use once_cell::sync::Lazy; // Import Lazy
use rustler::{Env, Term, Error};
use std::sync::Arc;
use futures::future::join_all;
use tokio::runtime::Runtime;
use text_embeddings_backend::{Backend, DType, ModelType, Pool};
use text_embeddings_core::{
    infer::{Infer},
    queue::Queue,
    tokenization::{Tokenization},
};
use tokenizers::{Tokenizer, TruncationDirection};
use tokenizers::utils::padding::{PaddingParams, PaddingDirection};
use anyhow::{Result};
use hf_hub::api::sync::Api;
use std::path::PathBuf;

// Tokio runtime lets us block on async code.
static TOKIO_RUNTIME: Lazy<Runtime> =
    Lazy::new(|| tokio::runtime::Runtime::new().expect("Failed to create Tokio runtime"));

static MODEL: Lazy<Arc<Infer>> = Lazy::new(|| {
    let _guard = TOKIO_RUNTIME.enter();
    let api = Api::new().unwrap();
    let repo = api.model("janni-t/qwen3-embedding-0.6b-int8-tei-onnx".to_string());
    let _config_json = repo.get("config.json").unwrap();
    let tokenizer_json = repo.get("tokenizer.json").unwrap();
    let model_file = repo.get("model.onnx").unwrap();
    let parent_dir = model_file.parent().unwrap();
    let mut padding = PaddingParams::default();
    padding.direction = PaddingDirection::Left;
    let tokenizer = Tokenizer::from(Tokenizer::from_file(tokenizer_json).unwrap().with_padding(Some(padding)).clone());
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
        DType::Float32,
        model_type,
        String::new(),
        None,
        String::new()
    )).unwrap();
    let queue = Queue::new(
        backend.padded_model,
        16384,
        None,
        2
    );
    let infer = Infer::new(token, queue, 2, backend);

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
                    false,
                    permit
                )
                .await
        });
    }
    let final_result: Result<Vec<Vec<f32>>, _> =
        TOKIO_RUNTIME.block_on(join_all(futures))
        .into_iter()
        .collect::<Result<Vec<_>, _>>()
        .map(|responses| {
            let response = responses
                .into_iter()
                .map(|response| response.results)
                .collect();
            response
        })
        .map_err(|e| Error::Term(Box::new(format!("Errored embedding: {:?}", e))));
    final_result
}
rustler::init!("Elixir.EmbedAnything", load = load);

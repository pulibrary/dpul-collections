use std::ffi::CString;
use std::num::NonZeroU32;
use std::sync::{Mutex, OnceLock};

use encoding_rs::UTF_8;
use rustler::{Binary, Resource, ResourceArc};

use llama_cpp_2::context::params::LlamaContextParams;
use llama_cpp_2::llama_backend::LlamaBackend;
use llama_cpp_2::llama_batch::LlamaBatch;
use llama_cpp_2::model::params::LlamaModelParams;
use llama_cpp_2::model::{LlamaChatMessage, LlamaModel};
use llama_cpp_2::mtmd::{
    mtmd_default_marker, MtmdBitmap, MtmdContext, MtmdContextParams, MtmdInputText,
};
use llama_cpp_2::sampling::LlamaSampler;
use llama_cpp_2::{send_logs_to_tracing, LogOptions};

pub struct Model {
    mtmd_ctx: Mutex<MtmdContext>,
    model: LlamaModel,
}

#[rustler::resource_impl]
impl Resource for Model {}

static BACKEND: OnceLock<LlamaBackend> = OnceLock::new();

fn backend() -> &'static LlamaBackend {
    BACKEND.get_or_init(|| LlamaBackend::init().expect("failed to init llama backend"))
}

// Similar to https://github.com/utilityai/llama-cpp-rs/blob/main/examples/mtmd/src/mtmd.rs#L101
#[rustler::nif(schedule = "DirtyCpu")]
fn load(model_path: String, mmproj_path: String) -> ResourceArc<Model> {
    let _ = tracing_subscriber::fmt()
        .with_writer(std::io::stderr)
        .with_max_level(tracing::Level::TRACE)
        .try_init();
    send_logs_to_tracing(LogOptions::default().with_logs_enabled(false));
    let backend = backend();
    // Set 0 to 1_000_000 to use GPU
    let model_params = LlamaModelParams::default().with_n_gpu_layers(1_000_000);
    let model = LlamaModel::load_from_file(backend, &model_path, &model_params).unwrap();

    let mtmd_params = MtmdContextParams {
        // Set to true to use Metal
        use_gpu: true,
        print_timings: false,
        n_threads: 4,
        media_marker: CString::new(mtmd_default_marker().to_string()).unwrap(),
        image_min_tokens: -1,
        image_max_tokens: -1,
    };
    let mtmd_ctx = MtmdContext::init_from_file(&mmproj_path, &model, &mtmd_params).unwrap();

    ResourceArc::new(Model {
        mtmd_ctx: Mutex::new(mtmd_ctx),
        model,
    })
}

#[rustler::nif(schedule = "DirtyCpu")]
fn ocr(resource: ResourceArc<Model>, image: Binary, prompt: String, n_ctx: u32) -> String {
    let model = &resource.model;
    let guard = resource.mtmd_ctx.lock().unwrap();
    let mtmd_ctx = &*guard;

    let ctx_params = LlamaContextParams::default()
        .with_n_ctx(Some(NonZeroU32::new(n_ctx).unwrap()))
        .with_n_batch(512);
    let mut context = model.new_context(backend(), ctx_params).unwrap();

    let bitmap = MtmdBitmap::from_buffer(mtmd_ctx, image.as_slice(), false).unwrap();

    let full_prompt = format!("{}{prompt}", mtmd_default_marker());
    let chat_template = model.chat_template(None).unwrap();
    let messages = vec![LlamaChatMessage::new("user".to_string(), full_prompt).unwrap()];
    let formatted = model
        .apply_chat_template(&chat_template, &messages, true)
        .unwrap();

    // like example `eval_message`
    let input_text = MtmdInputText {
        text: formatted,
        add_special: true,
        parse_special: true,
    };
    let chunks = mtmd_ctx.tokenize(input_text, &[&bitmap]).unwrap();
    let mut n_past = chunks.eval_chunks(mtmd_ctx, &context, 0, 0, 512, true).unwrap();

    // like example `generate_response`
    let mut sampler = LlamaSampler::chain_simple([LlamaSampler::greedy()]);
    let mut batch = LlamaBatch::new(512, 1);
    let mut decoder = UTF_8.new_decoder();
    let mut output = String::new();

    for _ in 0..8192 {
        let token = sampler.sample(&context, -1);
        sampler.accept(token);
        if model.is_eog_token(token) {
            break;
        }
        if n_past >= n_ctx as i32 {
            break;
        }
        let piece = model
            .token_to_piece(token, &mut decoder, false, None)
            .unwrap_or_default();
        output.push_str(&piece);
        batch.clear();
        batch.add(token, n_past, &[0], true).unwrap();
        n_past += 1;
        if context.decode(&mut batch).is_err() {
            break;
        }
    }

    output
}

rustler::init!("Elixir.DpulCollections.Mocr.Native");

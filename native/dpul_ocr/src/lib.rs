use std::path::Path;
use std::sync::Mutex;

use rustler::{Error, NifMap, NifResult, Resource, ResourceArc};

use oar_ocr_vl::utils::image::load_image;
use oar_ocr_vl::utils::parse_device;
use oar_ocr_vl::{DocParser, OvisOcr2, PpDocLayout};

struct ModelResource {
    model: Mutex<OvisOcr2>,
}

struct LayoutResource {
    model: Mutex<PpDocLayout>,
}

#[rustler::resource_impl]
impl Resource for ModelResource {}

#[rustler::resource_impl]
impl Resource for LayoutResource {}

/// Struct to hold the text + region detected to convert to a map.
#[derive(NifMap)]
struct LayoutElem {
    kind: String,
    label: Option<String>,
    text: Option<String>,
    confidence: f64,
    order_index: Option<i64>,
    bbox: (f64, f64, f64, f64),
}

fn err(message: impl std::fmt::Display) -> Error {
    Error::Term(Box::new(message.to_string()))
}

#[rustler::nif(schedule = "DirtyCpu")]
fn load_model(model_dir: String, device: String) -> NifResult<ResourceArc<ModelResource>> {
    let device = parse_device(&device).map_err(err)?;
    let model = OvisOcr2::from_dir(Path::new(&model_dir), device).map_err(err)?;

    Ok(ResourceArc::new(ModelResource {
        model: Mutex::new(model),
    }))
}

#[rustler::nif(schedule = "DirtyCpu")]
fn load_layout(model_dir: String, device: String) -> NifResult<ResourceArc<LayoutResource>> {
    let device = parse_device(&device).map_err(err)?;
    let model = PpDocLayout::from_dir(Path::new(&model_dir), device).map_err(err)?;

    Ok(ResourceArc::new(LayoutResource {
        model: Mutex::new(model),
    }))
}

#[rustler::nif(schedule = "DirtyCpu")]
fn ocr_path(
    resource: ResourceArc<ModelResource>,
    image_path: String,
    max_new_tokens: usize,
) -> NifResult<String> {
    let image = load_image(Path::new(&image_path)).map_err(err)?;
    let model = resource.model.lock().map_err(|_| err("model lock poisoned"))?;

    model
        .parse(&[image], max_new_tokens)
        .map_err(err)?
        .into_iter()
        .next()
        .ok_or_else(|| err("OvisOCR2 returned no result"))?
        .map_err(err)
}

// See https://github.com/GreatV/oar-ocr/blob/main/oar-ocr-vl/examples/ovisocr2.rs and
// https://github.com/GreatV/oar-ocr/blob/main/oar-ocr-vl/examples/paddleocr_vl.rs and https://github.com/GreatV/oar-ocr/blob/main/oar-ocr-vl/examples/doc_parser.rs for some
// examples.
#[rustler::nif(schedule = "DirtyCpu")]
fn layout_ocr_path(
    ocr: ResourceArc<ModelResource>,
    layout: ResourceArc<LayoutResource>,
    image_path: String,
) -> NifResult<Vec<LayoutElem>> {
    let image = load_image(Path::new(&image_path)).map_err(err)?;
    let ocr = ocr.model.lock().map_err(|_| err("model lock poisoned"))?;
    let layout = layout.model.lock().map_err(|_| err("layout lock poisoned"))?;

    let result = DocParser::new(&*ocr).parse(&*layout, image).map_err(err)?;

    Ok(result
        .layout_elements
        .into_iter()
        .map(|e| LayoutElem {
            kind: e.element_type.as_str().to_string(),
            label: e.label,
            text: e.text,
            confidence: e.confidence as f64,
            order_index: e.order_index.map(|i| i as i64),
            bbox: (
                e.bbox.x_min() as f64,
                e.bbox.y_min() as f64,
                e.bbox.x_max() as f64,
                e.bbox.y_max() as f64,
            ),
        })
        .collect())
}

rustler::init!("Elixir.DpulCollections.Ocr.Native");

#include "llama.h"
#include <android/log.h>
#include <cstring>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

#define LOG_TAG "RamaAI"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

// ─────────────────────────────────────────────────────────────────────────────
// TUNING KNOBS  (edit these without touching inference logic)
// ─────────────────────────────────────────────────────────────────────────────
static constexpr int K_CTX = 2048;  // KV-cache rows (was 512 — too small)
static constexpr int K_BATCH = 512; // prompt-decode chunk (was 128)
static constexpr int K_MAX_GEN =
    512; // max output tokens (was 128 — caused cutoff)
static constexpr int K_GPU_LAYERS =
    0; // 0 = CPU-only (safe); raise if Vulkan works
static constexpr float K_TEMPERATURE =
    0.7f;                          // 0 = greedy/deterministic, 0.7 = natural
static constexpr int K_TOP_K = 40; // top-k sampling pool
static constexpr float K_TOP_P = 0.9f; // nucleus sampling threshold
static constexpr float K_REPEAT_PEN =
    1.1f; // penalise repeated tokens (reduces loops)
// ─────────────────────────────────────────────────────────────────────────────

// ─── Model Cache ─────────────────────────────────────────────────────────────
// The #1 performance fix: load the model ONCE, reuse it across every call.
// Previously the model was loaded & freed on every single message → 2-18s lag.
// ─────────────────────────────────────────────────────────────────────────────
static std::mutex g_model_mutex;
static llama_model *g_model = nullptr;
static std::string g_model_path = "";

// Returns the cached model, loading it first if the path changed.
// Thread-safe via g_model_mutex.
static llama_model *get_or_load_model(const char *model_path) {
  std::lock_guard<std::mutex> lock(g_model_mutex);

  // Already loaded with the same path — return immediately
  if (g_model && g_model_path == model_path) {
    LOGI("Model cache HIT: %s", model_path);
    return g_model;
  }

  // Different model requested — free old one first
  if (g_model) {
    LOGI("Model path changed, freeing old model");
    llama_model_free(g_model);
    g_model = nullptr;
    g_model_path.clear();
  }

  LOGI("Loading model (first time or path changed): %s", model_path);

  llama_model_params mp = llama_model_default_params();
  mp.n_gpu_layers = K_GPU_LAYERS;

  g_model = llama_model_load_from_file(model_path, mp);
  if (!g_model) {
    LOGE("Model load FAILED: %s", model_path);
    return nullptr;
  }

  g_model_path = model_path;
  LOGI("Model loaded and cached OK");
  return g_model;
}

// Call this when the user switches models in the UI so the cache is cleared.
extern "C" void release_model_cache() {
  std::lock_guard<std::mutex> lock(g_model_mutex);
  if (g_model) {
    LOGI("Releasing cached model");
    llama_model_free(g_model);
    g_model = nullptr;
    g_model_path.clear();
  }
}

extern "C" {

// ─── run_model_path
// ─────────────────────────────────────────────────────────── model_path :
// absolute path to the .gguf file prompt     : full formatted prompt string
// (history + current turn) Returns a malloc'd C-string; Dart side calls
// toDartString() then discard.
// ─────────────────────────────────────────────────────────────────────────────
const char *run_model_path(const char *model_path, const char *prompt) {

  // ── 1. Model (cached) ────────────────────────────────────────────────────
  llama_model *model = get_or_load_model(model_path);
  if (!model) {
    return strdup("Error: Could not load model. Check the file path and make "
                  "sure the GGUF is not corrupted.");
  }

  // ── 2. Context (created fresh per call — lightweight, ~few MB) ───────────
  // Context holds the KV-cache for this inference pass only.
  // Creating it per-call is cheap; it's the model weights that are expensive.
  llama_context_params cp = llama_context_default_params();
  cp.n_ctx = K_CTX;
  cp.n_batch = K_BATCH;

  // Use all available CPU threads for parallel token processing.
  // This alone can give 2-4x speed improvement on multi-core phones.
  int hw_threads = (int)std::thread::hardware_concurrency();
  cp.n_threads = (hw_threads > 0) ? hw_threads : 4;
  cp.n_threads_batch = cp.n_threads; // also parallelise prompt batching

  LOGI("Using %d CPU threads (hw=%d)", cp.n_threads, hw_threads);

  llama_context *ctx = llama_init_from_model(model, cp);
  if (!ctx) {
    LOGE("Context creation FAILED (OOM?)");
    return strdup("Error: Not enough memory to run the model. Try a smaller "
                  "GGUF (Q4_K_M or Q2_K).");
  }
  LOGI("Context created (n_ctx=%d, threads=%d)", K_CTX, cp.n_threads);

  const llama_vocab *vocab = llama_model_get_vocab(model);

  // ── 3. Tokenise ──────────────────────────────────────────────────────────
  int n_prompt_bytes = (int)strlen(prompt);

  int n_tokens =
      llama_tokenize(vocab, prompt, n_prompt_bytes, nullptr, 0, true, false);
  if (n_tokens < 0)
    n_tokens = -n_tokens;
  if (n_tokens == 0) {
    llama_free(ctx);
    return strdup("Error: Could not tokenise the prompt.");
  }

  std::vector<llama_token> tokens((size_t)n_tokens);
  int rc = llama_tokenize(vocab, prompt, n_prompt_bytes, tokens.data(),
                          n_tokens, true, false);
  if (rc < 0) {
    llama_free(ctx);
    return strdup("Error: Tokenisation failed.");
  }
  tokens.resize((size_t)rc);
  n_tokens = rc;
  LOGI("Prompt tokenised: %d tokens", n_tokens);

  // Guard: leave room for output tokens
  if (n_tokens >= K_CTX - 4) {
    llama_free(ctx);
    return strdup(
        "Error: Prompt too long. The conversation history is being trimmed "
        "automatically — please send a shorter message or start a new chat.");
  }

  // ── 4. Prefill (prompt decode batch) ─────────────────────────────────────
  llama_batch batch = llama_batch_init(n_tokens, 0, 1);
  batch.n_tokens = n_tokens;
  for (int i = 0; i < n_tokens; i++) {
    batch.token[i] = tokens[i];
    batch.pos[i] = i;
    batch.n_seq_id[i] = 1;
    batch.seq_id[i][0] = 0;
    batch.logits[i] = (i == n_tokens - 1);
  }

  if (llama_decode(ctx, batch) != 0) {
    LOGE("Prompt prefill decode FAILED");
    llama_batch_free(batch);
    llama_free(ctx);
    return strdup(
        "Error: Failed to process the prompt. The model may be incompatible.");
  }
  llama_batch_free(batch);
  LOGI("Prompt prefill OK");

  // ── 5. Sampler chain ─────────────────────────────────────────────────────
  // Chain: temperature → top-k → top-p (nucleus) → repetition penalty → greedy
  // pick Much better output quality than pure greedy, with minimal speed cost.
  llama_sampler *sampler =
      llama_sampler_chain_init(llama_sampler_chain_default_params());
  llama_sampler_chain_add(sampler, llama_sampler_init_temp(K_TEMPERATURE));
  llama_sampler_chain_add(sampler, llama_sampler_init_top_k(K_TOP_K));
  llama_sampler_chain_add(sampler, llama_sampler_init_top_p(K_TOP_P, 1));
  llama_sampler_chain_add(
      sampler, llama_sampler_init_penalties(K_CTX, // penalty context window
                                            K_REPEAT_PEN, // repeat penalty
                                            0.0f,         // frequency penalty
                                            0.0f          // presence penalty
                                            ));
  llama_sampler_chain_add(sampler, llama_sampler_init_greedy()); // final pick

  // ── 6. Generation loop ───────────────────────────────────────────────────
  std::string output;
  output.reserve(2048);

  int cur_pos = n_tokens;
  bool gen_ok = true;

  for (int i = 0; i < K_MAX_GEN; i++) {
    llama_token tok = llama_sampler_sample(sampler, ctx, -1);

    // EOS or invalid token → done
    if (tok == llama_vocab_eos(vocab) || tok < 0) {
      LOGI("EOS reached at generation step %d", i);
      break;
    }

    // Token → text piece
    char buf[256] = {0};
    int nc =
        llama_token_to_piece(vocab, tok, buf, (int)sizeof(buf) - 1, 0, true);
    if (nc > 0)
      output.append(buf, (size_t)nc);

    // Feed generated token back for next step
    llama_batch nb = llama_batch_init(1, 0, 1);
    nb.n_tokens = 1;
    nb.token[0] = tok;
    nb.pos[0] = cur_pos++;
    nb.n_seq_id[0] = 1;
    nb.seq_id[0][0] = 0;
    nb.logits[0] = true;

    bool step_ok = (llama_decode(ctx, nb) == 0);
    llama_batch_free(nb);

    if (!step_ok) {
      LOGE("Generation decode failed at step %d", i);
      gen_ok = false;
      break;
    }
  }

  // ── 7. Cleanup context (NOT the model — it stays cached) ─────────────────
  llama_sampler_free(sampler);
  llama_free(ctx); // <-- only context freed; model stays in g_model cache

  LOGI("Generation done. output_len=%zu gen_ok=%d", output.size(), (int)gen_ok);

  if (output.empty()) {
    return strdup("(The model produced no output. Try rephrasing your question "
                  "or switching to a different model.)");
  }

  return strdup(output.c_str());
}

// ─── Legacy single-arg entry (kept for backward compatibility)
// ────────────────
const char *run_model(const char *prompt) {
  return run_model_path("/storage/emulated/0/RAMA_AI/models/model.gguf",
                        prompt);
}

} // extern "C"
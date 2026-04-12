#include <string>
#include <vector>
#include <cstring>
#include <stdexcept>
#include <android/log.h>
#include "llama.h"

#define LOG_TAG "RamaAI"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO,  LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

extern "C" {

// ─── run_model(model_path, prompt) ──────────────────────────────────────────
// model_path: absolute path to the .gguf file
// prompt:     user text
// Returns a malloc'd C-string; caller must free().
const char* run_model_path(const char* model_path, const char* prompt) {

    LOGI("Loading model: %s", model_path);

    llama_model_params mp = llama_model_default_params();
    mp.n_gpu_layers = 0;   // CPU-only (safe on all devices)

    llama_model* model = llama_model_load_from_file(model_path, mp);
    if (!model) {
        LOGE("Model load FAILED: %s", model_path);
        return strdup("Error: Could not load model. Check the file path and make sure the GGUF is not corrupted.");
    }
    LOGI("Model loaded OK");

    // Minimal context = minimum RAM. On phones with <4GB free, even 512 can OOM
    // with a large model. Use the smallest Q2_K or Q4_K_M model you can find.
    llama_context_params cp = llama_context_default_params();
    cp.n_ctx   = 512;   // KV-cache rows – each costs RAM
    cp.n_batch = 128;   // prompt-decode chunk size

    llama_context* ctx = llama_init_from_model(model, cp);
    if (!ctx) {
        LOGE("Context creation FAILED");
        llama_model_free(model);
        return strdup("Error: Not enough memory to run the model. Try a smaller GGUF (e.g. Q4_K_M or Q2_K).");
    }
    LOGI("Context created (n_ctx=1024)");

    const llama_vocab* vocab = llama_model_get_vocab(model);

    // ── Tokenise ─────────────────────────────────────────────────────────────
    int n_prompt = (int)strlen(prompt);

    // First pass: get token count
    int n_tokens = llama_tokenize(vocab, prompt, n_prompt, nullptr, 0, true, false);
    if (n_tokens < 0) n_tokens = -n_tokens;
    if (n_tokens == 0) {
        llama_free(ctx); llama_model_free(model);
        return strdup("Error: Could not tokenise the prompt.");
    }

    std::vector<llama_token> tokens((size_t)n_tokens);
    int rc = llama_tokenize(vocab, prompt, n_prompt, tokens.data(), n_tokens, true, false);
    if (rc < 0) {
        llama_free(ctx); llama_model_free(model);
        return strdup("Error: Tokenisation failed.");
    }
    tokens.resize((size_t)rc);
    n_tokens = rc;
    LOGI("Tokenised prompt: %d tokens", n_tokens);

    // Guard: don't exceed context
    if (n_tokens >= (int)cp.n_ctx - 4) {
        llama_free(ctx); llama_model_free(model);
        return strdup("Error: Prompt too long for the current context window.");
    }

    // ── Decode prompt batch ───────────────────────────────────────────────────
    llama_batch batch = llama_batch_init(n_tokens, 0, 1);
    batch.n_tokens = n_tokens;
    for (int i = 0; i < n_tokens; i++) {
        batch.token[i]     = tokens[i];
        batch.pos[i]       = i;
        batch.n_seq_id[i]  = 1;
        batch.seq_id[i][0] = 0;
        batch.logits[i]    = (i == n_tokens - 1); // only last needs logits
    }

    if (llama_decode(ctx, batch) != 0) {
        LOGE("llama_decode failed on prompt");
        llama_batch_free(batch);
        llama_free(ctx); llama_model_free(model);
        return strdup("Error: Failed to process prompt. The model may be incompatible or too large.");
    }
    llama_batch_free(batch);
    LOGI("Prompt decoded OK");

    // ── Generate tokens ───────────────────────────────────────────────────────
    std::string output;
    output.reserve(512);

    llama_sampler* sampler = llama_sampler_init_greedy();
    const int max_gen = 128;   // keep output short to avoid OOM during generation
    int cur_pos = n_tokens;
    bool generation_ok = true;

    for (int i = 0; i < max_gen; i++) {
        llama_token tok = llama_sampler_sample(sampler, ctx, -1);

        if (tok == llama_vocab_eos(vocab) || tok < 0) {
            LOGI("EOS at step %d", i);
            break;
        }

        // Token → text
        char buf[256] = {0};
        int nc = llama_token_to_piece(vocab, tok, buf, (int)sizeof(buf) - 1, 0, true);
        if (nc > 0) output.append(buf, (size_t)nc);

        // Feed token back
        llama_batch nb = llama_batch_init(1, 0, 1);
        nb.n_tokens     = 1;
        nb.token[0]     = tok;
        nb.pos[0]       = cur_pos++;
        nb.n_seq_id[0]  = 1;
        nb.seq_id[0][0] = 0;
        nb.logits[0]    = true;

        bool step_ok = (llama_decode(ctx, nb) == 0);
        llama_batch_free(nb);

        if (!step_ok) {
            LOGE("Generation decode failed at step %d", i);
            generation_ok = false;
            break;
        }
    }

    // ── Cleanup ───────────────────────────────────────────────────────────────
    llama_sampler_free(sampler);
    llama_free(ctx);
    llama_model_free(model);

    LOGI("Done. Output length=%zu generation_ok=%d", output.size(), (int)generation_ok);

    if (output.empty()) {
        return strdup("(The model produced no output. Try a different model or prompt.)");
    }
    return strdup(output.c_str());
}

// Legacy single-arg version (kept for compatibility, uses default path)
const char* run_model(const char* prompt) {
    return run_model_path(
        "/storage/emulated/0/RAMA_AI/models/model.gguf",
        prompt
    );
}

} // extern "C"
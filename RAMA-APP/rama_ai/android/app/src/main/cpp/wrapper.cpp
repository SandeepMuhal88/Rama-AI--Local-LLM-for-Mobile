#include <string>
#include <vector>
#include <cstring>
#include "llama.h"

extern "C" {

const char* run_model(const char* prompt) {

    const char* model_path = "/storage/emulated/0/RAMA_AI/models/model.gguf";

    // Load model
    llama_model_params model_params = llama_model_default_params();
    llama_model* model = llama_model_load_from_file(model_path, model_params);

    if (!model) {
        return strdup("Failed to load model");
    }

    // Create context
    llama_context_params ctx_params = llama_context_default_params();
    llama_context* ctx = llama_init_from_model(model, ctx_params);

    if (!ctx) {
        return strdup("Failed to create context");
    }

    const llama_vocab* vocab = llama_model_get_vocab(model);

    // Tokenize input
    std::vector<llama_token> tokens(512);
    int n_tokens = llama_tokenize(
        vocab,
        prompt,
        strlen(prompt),
        tokens.data(),
        tokens.size(),
        true,
        false
    );

    tokens.resize(n_tokens);

    // Prepare batch
    llama_batch batch = llama_batch_init(tokens.size(), 0, 1);

    for (int i = 0; i < tokens.size(); i++) {
        batch.token[i] = tokens[i];
        batch.pos[i] = i;
        batch.n_seq_id[i] = 1;
        batch.seq_id[i][0] = 0;
        batch.logits[i] = false;
    }

    batch.logits[tokens.size() - 1] = true;

    // Decode input
    if (llama_decode(ctx, batch) != 0) {
        return strdup("Decode failed");
    }

    std::string output = "";

    // 🔥 NEW SAMPLER (IMPORTANT FIX)
    llama_sampler* sampler = llama_sampler_init_greedy();

    for (int i = 0; i < 50; i++) {

        llama_token new_token = llama_sampler_sample(sampler, ctx, -1);

        if (new_token == llama_vocab_eos(vocab)) break;

        // Convert token → text
        char buffer[256];
        int n = llama_token_to_piece(
            vocab,
            new_token,
            buffer,
            sizeof(buffer),
            0,
            true
        );

        output.append(buffer, n);

        // Next token batch
        llama_batch next_batch = llama_batch_init(1, 0, 1);

        next_batch.token[0] = new_token;
        next_batch.pos[0] = tokens.size() + i;
        next_batch.n_seq_id[0] = 1;
        next_batch.seq_id[0][0] = 0;
        next_batch.logits[0] = true;

        if (llama_decode(ctx, next_batch) != 0) {
            break;
        }
    }

    // Cleanup
    llama_sampler_free(sampler);
    llama_free(ctx);
    llama_model_free(model);

    return strdup(output.c_str());
}

}
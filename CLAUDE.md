## System Role: VM-3 (LLM Adapter Service)  
VM-3 is a new component introduced to handle natural language intent processing using an LLM (Claude). It will host a lightweight **LLM Adapter** service that converts human-written requests into structured JSON intents compliant with TMF921/3GPP standards. This service exposes an API for VM-1 to call, and a minimal web UI for demonstration/testing.  

**Development Objectives:**  
1. **Service Implementation:** Develop a backend service (preferably in Python for quick development) that listens for HTTP requests. Key aspects:  
   - Use a Python web framework like Flask or FastAPI to define an endpoint (e.g., `POST /generate_intent`) which accepts input text (the user’s natural language request) and returns a JSON response (the intent).  
   - The service should also serve a simple frontend page (e.g., at `/` or `/ui`) with a form to input a request and display the resulting JSON. This can be very minimal (HTML + maybe some JS to show the JSON or simply plain text output).  

2. **LLM Integration (Claude API):** Inside the adapter, take the incoming text and send it to Claude for interpretation. Since we are using Claude via the subscription (no direct API key), use one of two approaches:  
   - **Anthropic Python SDK (if available)**: If an official AnthropIc API client is available (requires API key, which we might not have). *This likely won't work without a key.*  
   - **Claude CLI via subprocess**: Utilize the installed Claude Code CLI to make an API call. For example, call `claude -p "<prompt>" --output-format json` from within Python (`subprocess.run`) and capture the output:contentReference[oaicite:13]{index=13}:contentReference[oaicite:14]{index=14}. This leverages the CLI's logged-in session to use Claude.  
   - **Cline or other open-source integration (optional)**: Alternatively, consider the Cline framework which can interface with Claude using your subscription:contentReference[oaicite:15]{index=15}. However, given time constraints, the simpler approach is to call the CLI directly or a minimal wrapper.  
   - **Prompt Design:** Craft a clear prompt for Claude to ensure it returns exactly the desired JSON format. For example:  
   ```
   You are an expert in 3GPP Intent interpretation. Convert the following user request into a TMF921-compliant Intent in JSON format. Include all necessary fields (like intentId, intentName, intentParameters, etc.) as per the standard, and ensure the JSON is properly structured. Output only the JSON object, with no extra explanation.
   
   User request: "<user_input_text>"
   ```
  
  The model’s response should be just a JSON structure. We might need to add a system instruction to **only output JSON** (e.g., "Assistant should output only valid JSON, no prose"). This prompt will be embedded in the code.  

3. **JSON Schema & Validation:** Define the expected JSON structure (if we have a schema or example from TMF921). For instance, an Intent JSON might contain fields such as `intentId`, `intentName`, `intentType`, `scope`, `priority`, `constraints`, etc. If a formal schema is available, include it for reference or at least validate the output keys. We can implement a quick schema check in the code or via a unit test to ensure Claude’s output meets the format (for example, using Python’s `jsonschema` library or simple checks).  

4. **Minimal Web UI:** Implement an HTML endpoint (e.g., `/`) that provides a simple form where a user can input a natural language request and see the returned JSON. This can be done by serving a static HTML that uses the adapter’s API via JavaScript fetch, or by doing form POST to the same service endpoint and then displaying JSON in the response page. Keep it simple (no need for fancy styling given time). This UI is mainly for demo purposes to manually verify the adapter’s functionality in a browser.  

5. **Testing:**  
- Write a few unit tests for the core logic (if time permits): e.g., a function that given a sample input, returns a dict (parsed JSON) and assert required keys exist.  
- Perform integration test calls: Using `curl` to POST a known input and check if output matches an expected golden JSON. Possibly store some example inputs and expected outputs in a `tests/` directory for regression testing.  
- Test error handling: e.g., if Claude returns an error or times out, ensure the service catches it and returns an HTTP 500 with an informative message, rather than crashing.  

6. **Deployment Considerations:** The adapter can be run as a simple Python process (e.g., via `flask run` or `uvicorn` if using FastAPI). Ensure it is configured to listen on VM-3’s IP and a known port (e.g., 8000). For security, it could be restricted to internal network access if needed. Document how to start the service (maybe provide a systemd service file or a Dockerfile if time allows, but not mandatory for the Summit demo).  

**Key Tools/Libraries:**  
- **Flask or FastAPI**: for building the web service.  
- **Anthropic Claude CLI**: to make LLM requests using your Claude subscription:contentReference[oaicite:16]{index=16}. Ensure the CLI is logged in on VM-3. We might use `subprocess` with commands like: `claude -p "...prompt..." -f input.txt --print` (if large prompts, we can pass via a file).  
- **Python Requests/HTTPX** (if needed): for any HTTP calls (though for Claude we use CLI, and for receiving requests Flask covers it).  
- **json / jsonschema**: to parse and validate LLM output.  
- **Git**: to commit the adapter code to the repository for version control.  

**Assumptions:**  
- The adapter’s environment has internet access to reach Claude’s API endpoints (the CLI will handle the networking). If the VM has restricted internet, Claude may not function – ensure VM-3 can reach AnthropIc’s servers.  
- The expected output format (Intent JSON) is well-understood by the development team – if unclear, we will define a reasonable structure to use consistently. We assume Claude model has been trained on similar patterns or we will enforce structure via prompt.  

**Next Steps in Implementation:**  
After implementing, run the service locally on VM-3 and do a quick manual test (with curl or the web UI) to verify it returns JSON as expected. Once confirmed, proceed to integrate with VM-1’s script (so that VM-1 can call this service). Document usage: e.g., in a README, note the endpoint and provide a sample curl command for others to test.  

_Note to Claude:_ Focus on correctness of JSON output. If the first LLM attempt returns e.g. extra text, wrap the call in logic to extract JSON substring or re-prompt. Aim for deterministic outputs for the same input (for testing consistency).  
